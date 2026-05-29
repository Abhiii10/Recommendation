from __future__ import annotations

import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


ROOT_DIR = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT_DIR / "backend" / ".env"
DESTINATIONS_FILE = ROOT_DIR / "data" / "destinations.json"
PEXELS_SEARCH_URL = "https://api.pexels.com/v1/search"
MAX_IMAGES = 5
REQUEST_DELAY_SECONDS = 0.5


def _read_env_key(path: Path, key: str) -> str:
    if not path.exists():
        raise FileNotFoundError(f"Missing env file: {path}")

    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        name, value = line.split("=", 1)
        if name.strip() == key:
            return value.strip().strip('"').strip("'")

    return ""


def _load_destinations(path: Path) -> list[dict[str, Any]]:
    with path.open("r", encoding="utf-8-sig") as file:
        decoded = json.load(file)

    if not isinstance(decoded, list):
        raise ValueError("data/destinations.json must contain a JSON list")

    return [dict(item) for item in decoded]


def _search_pexels(api_key: str, query: str, page: int = 1) -> list[str]:
    params = urllib.parse.urlencode(
        {
            "query": query,
            "per_page": MAX_IMAGES,
            "page": page,
        }
    )
    request = urllib.request.Request(
        f"{PEXELS_SEARCH_URL}?{params}",
        headers={"Authorization": api_key},
        method="GET",
    )

    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Pexels API returned {error.code}: {body}") from error

    photos = payload.get("photos", [])
    if not isinstance(photos, list):
        return []

    urls: list[str] = []
    for photo in photos:
        if not isinstance(photo, dict):
            continue
        src = photo.get("src")
        if not isinstance(src, dict):
            continue
        url = str(src.get("large2x") or "").strip()
        if url:
            urls.append(url)

    return urls


def _add_unique(target: list[str], urls: list[str]) -> None:
    seen = set(target)
    for url in urls:
        if url in seen:
            continue
        target.append(url)
        seen.add(url)
        if len(target) >= MAX_IMAGES:
            break


def _fetch_images_for_destination(
    api_key: str,
    destination: dict[str, Any],
) -> tuple[list[str], int]:
    name = str(destination.get("name") or "").strip()
    district = str(destination.get("district") or "").strip()
    if not name:
        raise ValueError("Destination is missing a name")

    urls: list[str] = []

    primary_urls = _search_pexels(api_key, f"{name} Nepal")
    _add_unique(urls, primary_urls)
    primary_count = len(urls)

    if len(urls) < MAX_IMAGES and district:
        district_urls = _search_pexels(api_key, f"{district} Nepal")
        _add_unique(urls, district_urls)

    if len(urls) < MAX_IMAGES:
        fallback_urls = _search_pexels(api_key, "Nepal tourism")
        _add_unique(urls, fallback_urls)

    fallback_page = 2
    while len(urls) < MAX_IMAGES and fallback_page <= 5:
        fallback_urls = _search_pexels(
            api_key,
            "Nepal tourism",
            page=fallback_page,
        )
        if not fallback_urls:
            break
        _add_unique(urls, fallback_urls)
        fallback_page += 1

    return urls[:MAX_IMAGES], primary_count


def _write_destinations(path: Path, destinations: list[dict[str, Any]]) -> None:
    path.write_text(
        json.dumps(destinations, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    api_key = _read_env_key(ENV_FILE, "PEXELS_API_KEY")
    if not api_key:
        print("PEXELS_API_KEY is missing in backend/.env")
        return 1

    destinations = _load_destinations(DESTINATIONS_FILE)

    for destination in destinations:
        name = str(destination.get("name") or "Unknown destination").strip()
        try:
            urls, primary_count = _fetch_images_for_destination(
                api_key,
                destination,
            )
            destination["images"] = urls

            if len(urls) == MAX_IMAGES and primary_count >= MAX_IMAGES:
                print(f"\u2705 {name} \u2192 5 images fetched")
            else:
                print(
                    f"\u26A0\uFE0F  {name} \u2192 only {primary_count} found, "
                    "padded with fallback"
                )
        except Exception as error:
            print(f"\u274C ERROR: {name} \u2192 {error}")
        finally:
            time.sleep(REQUEST_DELAY_SECONDS)

    _write_destinations(DESTINATIONS_FILE, destinations)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
