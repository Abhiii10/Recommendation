from __future__ import annotations

import argparse
import csv
import json
import math
import os
import shutil
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DATA_FILE = ROOT / "data" / "destinations.json"
APP_DATA_FILES = [
    ROOT / "app" / "assets" / "data" / "destinations.json",
    ROOT / "app" / "assets" / "data" / "backend_destinations.json",
]
CACHE_FILE = ROOT / "data" / "coordinate_verification_cache.json"
REPORT_FILE = ROOT / "data" / "coordinate_verification_report.json"
MANUAL_REVIEW_FILE = ROOT / "data" / "coordinate_manual_review.csv"

NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
WIKIDATA_SEARCH_URL = "https://www.wikidata.org/w/api.php"
WIKIDATA_ENTITY_URL = "https://www.wikidata.org/wiki/Special:EntityData/{entity_id}.json"

NOMINATIM_DELAY_SECONDS = 1.1
WIKIDATA_DELAY_SECONDS = 0.25
DEFAULT_APPLY_THRESHOLD = 0.82
LOW_PRECISION_DECIMALS = 2
REVIEWED_COORDINATE_ACCURACIES = {"verified", "verified_area", "reviewed_proxy"}


class ApiClient:
    def __init__(self, cache: dict[str, Any], user_agent: str) -> None:
        self._cache = cache
        self._user_agent = user_agent
        self._last_request_at: dict[str, float] = {}

    def get_json(
        self,
        source: str,
        url: str,
        *,
        delay_seconds: float,
        timeout_seconds: int = 15,
    ) -> Any:
        cache_key = f"{source}:{url}"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        self._respect_rate_limit(source, delay_seconds)

        request = urllib.request.Request(
            url,
            headers={
                "User-Agent": self._user_agent,
                "Accept": "application/json",
            },
            method="GET",
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as error:
            payload = {"error": str(error)}

        self._cache[cache_key] = payload
        _write_json(CACHE_FILE, self._cache)
        return payload

    def _respect_rate_limit(self, source: str, delay_seconds: float) -> None:
        last = self._last_request_at.get(source)
        if last is not None:
            elapsed = time.monotonic() - last
            if elapsed < delay_seconds:
                time.sleep(delay_seconds - elapsed)
        self._last_request_at[source] = time.monotonic()


def load_destinations(path: Path) -> list[dict[str, Any]]:
    decoded = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(decoded, list):
        raise ValueError(f"{path} must contain a JSON list")
    return [dict(item) for item in decoded]


def verify_destination(
    destination: dict[str, Any],
    client: ApiClient,
) -> dict[str, Any]:
    current_lat = _as_float(destination.get("latitude"))
    current_lng = _as_float(destination.get("longitude"))
    candidates = []
    candidates.extend(_nominatim_candidates(destination, client))
    candidates.extend(_wikidata_candidates(destination, client))

    scored = [
        _score_candidate(destination, candidate, current_lat, current_lng)
        for candidate in candidates
        if candidate.get("latitude") is not None and candidate.get("longitude") is not None
    ]
    scored.sort(key=lambda item: item["score"], reverse=True)

    best = scored[0] if scored else None
    needs_manual_review = best is None or best["score"] < DEFAULT_APPLY_THRESHOLD

    return {
        "id": destination.get("id"),
        "name": destination.get("name"),
        "district": destination.get("district"),
        "municipality": destination.get("municipality"),
        "current": {
            "latitude": current_lat,
            "longitude": current_lng,
            "precision": min(_decimal_places(current_lat), _decimal_places(current_lng)),
        },
        "best_candidate": best,
        "candidate_count": len(scored),
        "needs_manual_review": needs_manual_review,
        "verified_at": datetime.now(timezone.utc).isoformat(),
    }


def _nominatim_candidates(
    destination: dict[str, Any],
    client: ApiClient,
) -> list[dict[str, Any]]:
    queries = _search_queries(destination)
    results: list[dict[str, Any]] = []
    seen = set()

    for query_index, query in enumerate(queries):
        params = urllib.parse.urlencode(
            {
                "q": query,
                "format": "jsonv2",
                "addressdetails": 1,
                "namedetails": 1,
                "extratags": 1,
                "limit": 5,
                "countrycodes": "np",
            }
        )
        payload = client.get_json(
            "nominatim",
            f"{NOMINATIM_URL}?{params}",
            delay_seconds=NOMINATIM_DELAY_SECONDS,
        )
        if not isinstance(payload, list):
            continue

        for item in payload:
            if not isinstance(item, dict):
                continue
            key = (item.get("osm_type"), item.get("osm_id"))
            if key in seen:
                continue
            seen.add(key)
            results.append(
                {
                    "source": "openstreetmap",
                    "source_id": f"{item.get('osm_type')}:{item.get('osm_id')}",
                    "label": item.get("name") or item.get("display_name") or "",
                    "display_name": item.get("display_name") or "",
                    "latitude": _as_float(item.get("lat")),
                    "longitude": _as_float(item.get("lon")),
                    "class": item.get("category") or item.get("class") or "",
                    "type": item.get("type") or "",
                    "importance": _as_float(item.get("importance")) or 0.0,
                    "query": query,
                    "query_specificity": max(0.06, 0.18 - (query_index * 0.06)),
                    "country_match": True,
                }
            )

        if results:
            break

    return results


def _wikidata_candidates(
    destination: dict[str, Any],
    client: ApiClient,
) -> list[dict[str, Any]]:
    name = str(destination.get("name") or "").strip()
    if not name:
        return []

    params = urllib.parse.urlencode(
        {
            "action": "wbsearchentities",
            "search": f"{name} Nepal",
            "language": "en",
            "format": "json",
            "limit": 5,
        }
    )
    payload = client.get_json(
        "wikidata",
        f"{WIKIDATA_SEARCH_URL}?{params}",
        delay_seconds=WIKIDATA_DELAY_SECONDS,
    )
    if not isinstance(payload, dict):
        return []

    results = []
    for item in payload.get("search", []):
        if not isinstance(item, dict):
            continue
        entity_id = str(item.get("id") or "").strip()
        if not entity_id:
            continue
        coordinate = _wikidata_coordinate(entity_id, client)
        if coordinate is None:
            continue
        results.append(
            {
                "source": "wikidata",
                "source_id": entity_id,
                "label": item.get("label") or "",
                "display_name": item.get("description") or "",
                "latitude": coordinate["latitude"],
                "longitude": coordinate["longitude"],
                "class": "wikidata",
                "type": "P625",
                "importance": 0.75,
            }
        )

    return results


def _wikidata_coordinate(
    entity_id: str,
    client: ApiClient,
) -> dict[str, float] | None:
    payload = client.get_json(
        "wikidata",
        WIKIDATA_ENTITY_URL.format(entity_id=entity_id),
        delay_seconds=WIKIDATA_DELAY_SECONDS,
    )
    if not isinstance(payload, dict):
        return None

    entity = payload.get("entities", {}).get(entity_id, {})
    claims = entity.get("claims", {}).get("P625", [])
    if not claims:
        return None

    mainsnak = claims[0].get("mainsnak", {})
    value = mainsnak.get("datavalue", {}).get("value", {})
    latitude = _as_float(value.get("latitude"))
    longitude = _as_float(value.get("longitude"))
    if latitude is None or longitude is None:
        return None

    return {"latitude": latitude, "longitude": longitude}


def _score_candidate(
    destination: dict[str, Any],
    candidate: dict[str, Any],
    current_lat: float | None,
    current_lng: float | None,
) -> dict[str, Any]:
    name = str(destination.get("name") or "")
    district = str(destination.get("district") or "")
    municipality = str(destination.get("municipality") or "")
    haystack = " ".join(
        [
            str(candidate.get("label") or ""),
            str(candidate.get("display_name") or ""),
        ]
    )

    name_score = _token_coverage(name, haystack)
    district_match = _contains_token_text(haystack, district)
    municipality_match = _contains_token_text(haystack, municipality)
    nepal_match = "nepal" in _normalise_text(haystack)
    gandaki_match = "gandaki" in _normalise_text(haystack)
    country_match = bool(candidate.get("country_match")) or nepal_match

    distance_m = None
    distance_score = 0.0
    candidate_lat = _as_float(candidate.get("latitude"))
    candidate_lng = _as_float(candidate.get("longitude"))
    if current_lat is not None and current_lng is not None and candidate_lat is not None and candidate_lng is not None:
        distance_m = _haversine_m(current_lat, current_lng, candidate_lat, candidate_lng)
        if distance_m <= 1000:
            distance_score = 0.20
        elif distance_m <= 5000:
            distance_score = 0.16
        elif distance_m <= 15000:
            distance_score = 0.10
        elif distance_m <= 30000:
            distance_score = 0.05

    score = (
        0.42 * name_score
        + (0.16 if district_match else 0.0)
        + (0.10 if municipality_match else 0.0)
        + (0.12 if country_match else 0.0)
        + (0.06 if gandaki_match else 0.0)
        + distance_score
        + min(float(candidate.get("query_specificity") or 0.0), 0.18)
        + min(float(candidate.get("importance") or 0.0), 1.0) * 0.08
    )

    scored = dict(candidate)
    scored["score"] = round(min(score, 1.0), 4)
    scored["distance_from_current_m"] = None if distance_m is None else round(distance_m, 1)
    scored["evidence"] = {
        "name_token_coverage": round(name_score, 4),
        "district_match": district_match,
        "municipality_match": municipality_match,
        "nepal_match": nepal_match,
        "country_match": country_match,
        "gandaki_match": gandaki_match,
        "query_specificity": candidate.get("query_specificity", 0.0),
    }
    return scored


def apply_verified_coordinates(
    destinations: list[dict[str, Any]],
    report_items: list[dict[str, Any]],
    *,
    threshold: float,
) -> int:
    report_by_id = {item["id"]: item for item in report_items}
    updated = 0

    for destination in destinations:
        report = report_by_id.get(destination.get("id"))
        if not report:
            continue
        best = report.get("best_candidate")
        if not isinstance(best, dict) or best.get("score", 0.0) < threshold:
            destination["coordinate_accuracy"] = "needs_review"
            destination["coordinate_review_note"] = "No high-confidence OSM/Wikidata match found."
            continue

        destination["original_latitude"] = destination.get("latitude")
        destination["original_longitude"] = destination.get("longitude")
        destination["latitude"] = best["latitude"]
        destination["longitude"] = best["longitude"]
        destination["coordinate_source"] = best["source"]
        destination["coordinate_source_id"] = best["source_id"]
        destination["coordinate_confidence_score"] = best["score"]
        destination["coordinate_accuracy"] = "verified"
        destination["coordinate_verified_at"] = report["verified_at"]
        destination["coordinate_review_note"] = (
            f"Matched by {best['source']} with score {best['score']}; "
            f"moved {best.get('distance_from_current_m')}m from previous coordinate."
        )
        updated += 1

    return updated


def write_manual_review(report_items: list[dict[str, Any]], path: Path) -> None:
    fieldnames = [
        "id",
        "name",
        "district",
        "municipality",
        "current_latitude",
        "current_longitude",
        "best_source",
        "best_label",
        "best_latitude",
        "best_longitude",
        "score",
        "distance_from_current_m",
        "reason",
    ]
    with path.open("w", encoding="utf-8-sig", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        for item in report_items:
            best = item.get("best_candidate") or {}
            if not item.get("needs_manual_review"):
                continue
            writer.writerow(
                {
                    "id": item.get("id"),
                    "name": item.get("name"),
                    "district": item.get("district"),
                    "municipality": item.get("municipality"),
                    "current_latitude": item.get("current", {}).get("latitude"),
                    "current_longitude": item.get("current", {}).get("longitude"),
                    "best_source": best.get("source"),
                    "best_label": best.get("label") or best.get("display_name"),
                    "best_latitude": best.get("latitude"),
                    "best_longitude": best.get("longitude"),
                    "score": best.get("score"),
                    "distance_from_current_m": best.get("distance_from_current_m"),
                    "reason": "No candidate" if not best else "Low confidence",
                }
            )


def sync_app_data(destinations: list[dict[str, Any]]) -> None:
    for path in APP_DATA_FILES:
        _write_json(path, destinations)


def _search_queries(destination: dict[str, Any]) -> list[str]:
    name = str(destination.get("name") or "").strip()
    district = str(destination.get("district") or "").strip()
    municipality = str(destination.get("municipality") or "").strip()
    queries = [
        ", ".join(part for part in [name, municipality, district, "Gandaki", "Nepal"] if part),
        ", ".join(part for part in [name, district, "Nepal"] if part),
        ", ".join(part for part in [name, "Nepal"] if part),
    ]
    return list(dict.fromkeys(query for query in queries if query.strip()))


def _token_coverage(needle: str, haystack: str) -> float:
    needle_tokens = _tokens(needle)
    if not needle_tokens:
        return 0.0
    haystack_tokens = set(_tokens(haystack))
    matched = sum(1 for token in needle_tokens if token in haystack_tokens)
    return matched / len(needle_tokens)


def _contains_token_text(haystack: str, needle: str) -> bool:
    needle_tokens = _tokens(needle)
    if not needle_tokens:
        return False
    haystack_tokens = set(_tokens(haystack))
    return any(token in haystack_tokens for token in needle_tokens)


def _tokens(text: str) -> list[str]:
    ignored = {"nepal", "gandaki", "province", "rural", "municipality"}
    return [
        token
        for token in _normalise_text(text).split()
        if len(token) > 1 and token not in ignored
    ]


def _normalise_text(text: str) -> str:
    return "".join(ch.lower() if ch.isalnum() else " " for ch in text)


def _as_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _decimal_places(value: Any) -> int:
    text = str(value)
    if "." not in text:
        return 0
    return len(text.split(".", 1)[1])


def _is_low_precision(destination: dict[str, Any]) -> bool:
    return min(
        _decimal_places(destination.get("latitude")),
        _decimal_places(destination.get("longitude")),
    ) <= LOW_PRECISION_DECIMALS


def _haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius_m = 6371000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = (
        math.sin(delta_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    )
    return radius_m * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _load_cache() -> dict[str, Any]:
    if not CACHE_FILE.exists():
        return {}
    try:
        decoded = json.loads(CACHE_FILE.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return decoded if isinstance(decoded, dict) else {}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify destination coordinates using OSM Nominatim and Wikidata.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Update destination JSON files for high-confidence matches.",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=DEFAULT_APPLY_THRESHOLD,
        help="Minimum score required when --apply is used.",
    )
    parser.add_argument(
        "--only-low-precision",
        action="store_true",
        help="Verify only destinations with <= 2 decimal places in lat/lng.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit number of destinations checked; useful for smoke tests.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    destinations = load_destinations(DATA_FILE)
    selected = [
        destination
        for destination in destinations
        if (
            not args.only_low_precision
            or (
                _is_low_precision(destination)
                and destination.get("coordinate_accuracy") not in REVIEWED_COORDINATE_ACCURACIES
            )
        )
    ]
    if args.limit > 0:
        selected = selected[: args.limit]

    cache = _load_cache()
    user_agent = os.environ.get(
        "GEOCODER_USER_AGENT",
        "PailaNepalFYP/1.0 coordinate verification (local academic project)",
    )
    client = ApiClient(cache, user_agent)

    report_items: list[dict[str, Any]] = []
    for index, destination in enumerate(selected, start=1):
        name = str(destination.get("name") or "Unknown").strip()
        report = verify_destination(destination, client)
        report_items.append(report)
        best = report.get("best_candidate") or {}
        score = best.get("score", 0.0)
        source = best.get("source", "none")
        print(f"[{index:03d}/{len(selected):03d}] {name}: {source} score={score}")

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_destinations": len(destinations),
        "checked_destinations": len(selected),
        "apply": args.apply,
        "threshold": args.threshold,
        "verified_count": sum(
            1
            for item in report_items
            if isinstance(item.get("best_candidate"), dict)
            and item["best_candidate"].get("score", 0.0) >= args.threshold
        ),
        "manual_review_count": sum(1 for item in report_items if item.get("needs_manual_review")),
        "items": report_items,
    }
    _write_json(REPORT_FILE, report)
    write_manual_review(report_items, MANUAL_REVIEW_FILE)

    if args.apply:
        backup_path = DATA_FILE.with_name(
            f"destinations_before_coordinate_verify_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        )
        shutil.copy2(DATA_FILE, backup_path)
        updated = apply_verified_coordinates(
            destinations,
            report_items,
            threshold=args.threshold,
        )
        _write_json(DATA_FILE, destinations)
        sync_app_data(destinations)
        print(f"Applied {updated} coordinate updates.")
        print(f"Backup written: {backup_path}")

    print(f"Report written: {REPORT_FILE}")
    print(f"Manual review CSV written: {MANUAL_REVIEW_FILE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
