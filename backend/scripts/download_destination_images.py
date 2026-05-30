from __future__ import annotations

import asyncio
import json
import re
import sys
from io import BytesIO
from pathlib import Path

import httpx
from PIL import Image

ROOT_DIR = Path(__file__).resolve().parents[2]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from backend.application.services.destination_image_service import (  # noqa: E402
    HTTP_HEADERS,
    category_fallback_url,
    fetch_wikipedia_image,
)

DESTINATIONS_FILE = ROOT_DIR / "data" / "destinations.json"
URL_CACHE_FILE = ROOT_DIR / "data" / "destination_images.json"
APP_IMAGES_DIR = ROOT_DIR / "app" / "assets" / "destination_images"
APP_MANIFEST_FILE = ROOT_DIR / "app" / "assets" / "data" / "destination_image_assets.json"
REQUEST_DELAY_SECONDS = 0.5
IMAGE_SIZE = (900, 620)
WEBP_QUALITY = 78


async def main() -> None:
    _configure_stdout()
    destinations = _load_destinations()
    url_cache = _load_url_cache()
    manifest = _load_manifest()

    APP_IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    APP_MANIFEST_FILE.parent.mkdir(parents=True, exist_ok=True)

    async with httpx.AsyncClient(
        timeout=12.0,
        headers=HTTP_HEADERS,
        follow_redirects=True,
    ) as client:
        total = len(destinations)
        for index, destination in enumerate(destinations, start=1):
            name = str(destination.get("name") or "").strip()
            if not name:
                continue

            output_path = APP_IMAGES_DIR / f"{_slugify(name)}.webp"
            asset_path = f"assets/destination_images/{output_path.name}"

            cached_url = url_cache.get(name, "")
            if (
                output_path.exists()
                and output_path.stat().st_size > 1024
                and not _is_unsplash(cached_url)
            ):
                manifest[name] = asset_path
                _save_json(APP_MANIFEST_FILE, manifest)
                print(f"✅ {index}/{total} {name} → already local")
                continue

            image_url = await _image_url_for(client, destination, url_cache)
            ok = await _download_and_save(client, image_url, output_path)
            await asyncio.sleep(REQUEST_DELAY_SECONDS)

            if ok:
                manifest[name] = asset_path
                _save_json(URL_CACHE_FILE, url_cache)
                _save_json(APP_MANIFEST_FILE, manifest)
                source = "fallback" if _is_unsplash(image_url) else "real photo"
                print(f"✅ {index}/{total} {name} → saved {source}")
            else:
                print(f"⚠️ {index}/{total} {name} → image download failed")

    _save_json(URL_CACHE_FILE, url_cache)
    _save_json(APP_MANIFEST_FILE, manifest)
    print(f"Saved {len(manifest)} local image assets to {APP_IMAGES_DIR}")
    print(f"Saved Flutter manifest to {APP_MANIFEST_FILE}")


async def _image_url_for(
    client: httpx.AsyncClient,
    destination: dict[str, object],
    url_cache: dict[str, str],
) -> str:
    name = str(destination.get("name") or "").strip()
    cached = url_cache.get(name)
    if cached and not _is_unsplash(cached):
        return cached

    for candidate in _candidate_titles(destination):
        image_url = await fetch_wikipedia_image(client, candidate)
        await asyncio.sleep(REQUEST_DELAY_SECONDS)
        if image_url:
            url_cache[name] = image_url
            return image_url

    fallback = category_fallback_url(_first(destination.get("category")))
    url_cache[name] = fallback
    return fallback


async def _download_and_save(
    client: httpx.AsyncClient,
    image_url: str,
    output_path: Path,
) -> bool:
    try:
        response = await client.get(image_url)
        response.raise_for_status()
        image = Image.open(BytesIO(response.content)).convert("RGB")
        image.thumbnail(IMAGE_SIZE, Image.Resampling.LANCZOS)
        image.save(output_path, "WEBP", quality=WEBP_QUALITY, method=6)
        return output_path.exists() and output_path.stat().st_size > 1024
    except Exception:
        return False


def _candidate_titles(destination: dict[str, object]) -> list[str]:
    name = str(destination.get("name") or "").strip()
    raw_candidates = [
        name,
        f"{name}, Nepal",
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


def _load_destinations() -> list[dict[str, object]]:
    with DESTINATIONS_FILE.open("r", encoding="utf-8") as file:
        raw = json.load(file)
    if not isinstance(raw, list):
        raise ValueError("data/destinations.json must contain a list")
    return [
        dict(item)
        for item in raw
        if isinstance(item, dict) and str(item.get("name") or "").strip()
    ]


def _load_url_cache() -> dict[str, str]:
    if not URL_CACHE_FILE.exists():
        return {}
    with URL_CACHE_FILE.open("r", encoding="utf-8") as file:
        raw = json.load(file)
    if not isinstance(raw, dict):
        return {}
    return {
        str(name): str(url)
        for name, url in raw.items()
        if str(name).strip() and str(url).strip()
    }


def _load_manifest() -> dict[str, str]:
    if not APP_MANIFEST_FILE.exists():
        return {}
    with APP_MANIFEST_FILE.open("r", encoding="utf-8") as file:
        raw = json.load(file)
    if not isinstance(raw, dict):
        return {}
    return {
        str(name): str(path)
        for name, path in raw.items()
        if str(name).strip() and str(path).strip()
    }


def _save_json(path: Path, data: dict[str, str]) -> None:
    with path.open("w", encoding="utf-8") as file:
        json.dump(dict(sorted(data.items())), file, ensure_ascii=False, indent=2)
        file.write("\n")


def _first(value: object) -> str | None:
    if isinstance(value, list) and value:
        return str(value[0])
    if value is None:
        return None
    return str(value)


def _is_unsplash(url: str) -> bool:
    return "images.unsplash.com" in url


def _normalize(value: str) -> str:
    return " ".join(value.strip().lower().split())


def _slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    return slug or "destination"


def _configure_stdout() -> None:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


if __name__ == "__main__":
    asyncio.run(main())
