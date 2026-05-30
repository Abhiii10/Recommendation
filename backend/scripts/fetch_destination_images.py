from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

import httpx

ROOT_DIR = Path(__file__).resolve().parents[2]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from backend.application.services.destination_image_service import (
    HTTP_HEADERS,
    category_fallback_url,
    fetch_wikipedia_image,
)

DESTINATIONS_FILE = ROOT_DIR / "data" / "destinations.json"
OUTPUT_FILE = ROOT_DIR / "data" / "destination_images.json"
REQUEST_DELAY_SECONDS = 0.5


async def main() -> None:
    _configure_stdout()
    destinations = _load_destinations()
    results: dict[str, str] = {}

    async with httpx.AsyncClient(
        timeout=6.0,
        headers=HTTP_HEADERS,
        follow_redirects=True,
    ) as client:
        total = len(destinations)
        for index, destination in enumerate(destinations, start=1):
            name = str(destination.get("name") or "").strip()
            if not name:
                continue

            image_url = await _resolve_image(client, destination)
            results[name] = image_url

            if _is_unsplash(image_url):
                print(f"⚠️ {index}/{total} {name} → using fallback")
            else:
                print(f"✅ {index}/{total} {name} → found")

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_FILE.open("w", encoding="utf-8") as file:
        json.dump(results, file, ensure_ascii=False, indent=2)
        file.write("\n")

    print(f"Saved {len(results)} image URLs to {OUTPUT_FILE}")


async def _resolve_image(
    client: httpx.AsyncClient,
    destination: dict[str, object],
) -> str:
    for candidate in _candidate_titles(destination):
        image_url = await fetch_wikipedia_image(client, candidate)
        await asyncio.sleep(REQUEST_DELAY_SECONDS)
        if image_url:
            return image_url

    return category_fallback_url(_first(destination.get("category")))


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
        normalized = " ".join(candidate.lower().split())
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


def _first(value: object) -> str | None:
    if isinstance(value, list) and value:
        return str(value[0])
    if value is None:
        return None
    return str(value)


def _is_unsplash(url: str) -> bool:
    return "images.unsplash.com" in url


def _configure_stdout() -> None:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


if __name__ == "__main__":
    asyncio.run(main())
