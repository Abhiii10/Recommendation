from __future__ import annotations

import json
import logging
import re
from pathlib import Path
from urllib.parse import quote

import httpx

from backend.core.config import settings

logger = logging.getLogger(__name__)

IMAGE_CACHE_FILE = settings.data_dir / "destination_images.json"
WIKIPEDIA_SUMMARY_URL = "https://en.wikipedia.org/api/rest_v1/page/summary/{title}"
WIKIPEDIA_PAGEIMAGE_URL = "https://en.wikipedia.org/w/api.php"
WIKIMEDIA_COMMONS_URL = "https://commons.wikimedia.org/w/api.php"
HTTP_HEADERS = {
    "User-Agent": (
        "rural_tourism_app/1.0 "
        "(https://example.com; educational Nepal tourism project)"
    ),
}


def category_fallback_url(category: str | None) -> str:
    c = (category or "").lower()
    if "trek" in c or "adventure" in c:
        return "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800"
    if "cultur" in c or "histor" in c:
        return "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800"
    if "village" in c:
        return "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800"
    if "wild" in c:
        return "https://images.unsplash.com/photo-1474511320723-9a56873867b5?w=800"
    if "nature" in c:
        return "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800"
    if "spirit" in c or "pilgrim" in c:
        return "https://images.unsplash.com/photo-1609710228159-0fa9bd7c0827?w=800"
    if "boat" in c:
        return "https://images.unsplash.com/photo-1506953823976-52e1fdc0149a?w=800"
    return "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800"


class DestinationImageService:
    def __init__(self) -> None:
        self._image_cache = self._load_image_cache(IMAGE_CACHE_FILE)
        self._live_cache = dict(self._image_cache)
        self._destinations = self._load_destinations(settings.destinations_file)
        self._destinations_by_name = {
            _normalize(item.get("name", "")): item
            for item in self._destinations
            if item.get("name")
        }

    async def get_image(self, name: str) -> dict[str, str]:
        clean_name = name.strip()
        normalized = _normalize(clean_name)
        if not normalized:
            fallback = category_fallback_url(None)
            return {"name": clean_name, "image_url": fallback}

        cached = self._live_cache.get(normalized)
        if cached:
            return {"name": clean_name, "image_url": cached}

        destination = self._destinations_by_name.get(normalized, {})
        category = _first(destination.get("category"))
        candidates = _candidate_titles(clean_name, destination)

        try:
            async with httpx.AsyncClient(
                timeout=4.0,
                headers=HTTP_HEADERS,
                follow_redirects=True,
            ) as client:
                for candidate in candidates:
                    image_url = await fetch_wikipedia_image(client, candidate)
                    if image_url:
                        self._live_cache[normalized] = image_url
                        return {"name": clean_name, "image_url": image_url}
        except Exception as exc:
            logger.warning("Destination image lookup failed for %s: %s", name, exc)

        fallback = category_fallback_url(category)
        self._live_cache[normalized] = fallback
        return {"name": clean_name, "image_url": fallback}

    def _load_image_cache(self, path: Path) -> dict[str, str]:
        try:
            if not path.exists():
                return {}
            with path.open("r", encoding="utf-8") as file:
                raw = json.load(file)
            if not isinstance(raw, dict):
                return {}
            return {
                _normalize(str(name)): str(url)
                for name, url in raw.items()
                if str(name).strip() and str(url).strip()
            }
        except Exception as exc:
            logger.warning("Could not load destination image cache: %s", exc)
            return {}

    def _load_destinations(self, path: Path) -> list[dict[str, object]]:
        try:
            with path.open("r", encoding="utf-8") as file:
                raw = json.load(file)
            if not isinstance(raw, list):
                return []
            return [
                dict(item)
                for item in raw
                if isinstance(item, dict) and str(item.get("name", "")).strip()
            ]
        except Exception as exc:
            logger.warning("Could not load destinations for image lookup: %s", exc)
            return []


async def fetch_wikipedia_image(
    client: httpx.AsyncClient,
    title: str,
) -> str | None:
    summary_url = WIKIPEDIA_SUMMARY_URL.format(title=quote(title.strip(), safe=""))
    summary = await client.get(summary_url)
    if summary.status_code == 200:
        data = summary.json()
        image_url = _thumbnail_url(data)
        if image_url:
            return image_url

    pageimage = await client.get(
        WIKIPEDIA_PAGEIMAGE_URL,
        params={
            "action": "query",
            "titles": title,
            "prop": "pageimages",
            "format": "json",
            "pithumbsize": "800",
        },
    )
    if pageimage.status_code == 200:
        image_url = _pageimage_url(pageimage.json())
        if image_url:
            return image_url

    return await fetch_commons_image(client, title)


async def fetch_commons_image(
    client: httpx.AsyncClient,
    title: str,
) -> str | None:
    response = await client.get(
        WIKIMEDIA_COMMONS_URL,
        params={
            "action": "query",
            "generator": "search",
            "gsrsearch": f"{title} Nepal",
            "gsrnamespace": "6",
            "gsrlimit": "8",
            "prop": "imageinfo",
            "iiprop": "url",
            "iiurlwidth": "900",
            "format": "json",
            "formatversion": "2",
        },
    )
    if response.status_code != 200:
        return None

    data = response.json()
    query = data.get("query")
    if not isinstance(query, dict):
        return None
    pages = query.get("pages")
    if not isinstance(pages, list):
        return None

    for page in pages:
        if not isinstance(page, dict):
            continue
        imageinfo = page.get("imageinfo")
        if not isinstance(imageinfo, list) or not imageinfo:
            continue
        first = imageinfo[0]
        if not isinstance(first, dict):
            continue
        image_url = str(first.get("thumburl") or first.get("url") or "").strip()
        if _is_supported_image_url(image_url):
            return image_url
    return None


def _candidate_titles(name: str, destination: dict[str, object]) -> list[str]:
    name_variants = _name_variants(name)
    raw_candidates = [
        *name_variants,
        *[f"{candidate}, Nepal" for candidate in name_variants],
        str(destination.get("district") or "").strip(),
        str(destination.get("municipality") or "").strip(),
    ]
    candidates: list[str] = []
    seen: set[str] = set()
    for candidate in raw_candidates:
        normalized = _normalize(candidate)
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        candidates.append(candidate)
    return candidates


def _name_variants(name: str) -> list[str]:
    cleaned = re.sub(r"\([^)]*\)", "", name).strip()
    cleaned = cleaned.replace("&", "and")
    suffixes = [
        " village",
        " bazaar",
        " dham",
        " temple",
        " cave",
        " gompa",
        " danda",
        " hill",
        " trail",
        " area",
        " valley",
        " riverside",
    ]
    variants = [name, cleaned]
    lower = cleaned.lower()
    for suffix in suffixes:
        if lower.endswith(suffix):
            variants.append(cleaned[: -len(suffix)].strip())
    variants.append(f"{cleaned} Nepal")

    result: list[str] = []
    seen: set[str] = set()
    for variant in variants:
        normalized = _normalize(variant)
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        result.append(variant)
    return result


def _thumbnail_url(data: object) -> str | None:
    if not isinstance(data, dict):
        return None
    thumbnail = data.get("thumbnail")
    if not isinstance(thumbnail, dict):
        return None
    source = str(thumbnail.get("source") or "").strip()
    return source or None


def _pageimage_url(data: object) -> str | None:
    if not isinstance(data, dict):
        return None
    query = data.get("query")
    if not isinstance(query, dict):
        return None
    pages = query.get("pages")
    if not isinstance(pages, dict):
        return None
    for page in pages.values():
        if not isinstance(page, dict):
            continue
        thumbnail = page.get("thumbnail")
        if not isinstance(thumbnail, dict):
            continue
        source = str(thumbnail.get("source") or "").strip()
        if _is_supported_image_url(source):
            return source
    return None


def _is_supported_image_url(url: str) -> bool:
    lower = url.lower()
    if not lower.startswith("http"):
        return False
    if ".pdf" in lower:
        return False
    return not lower.endswith((".svg", ".gif", ".ogg", ".webm"))


def _first(value: object) -> str | None:
    if isinstance(value, list) and value:
        return str(value[0])
    if value is None:
        return None
    return str(value)


def _normalize(value: str) -> str:
    return " ".join(value.strip().lower().split())
