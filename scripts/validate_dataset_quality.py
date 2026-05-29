from __future__ import annotations

import json
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]

DESTINATION_FILES = [
    ROOT / "app" / "assets" / "data" / "backend_destinations.json",
    ROOT / "app" / "assets" / "data" / "destinations.json",
    ROOT / "data" / "destinations.json",
]

ACCOMMODATION_FILES = [
    ROOT / "app" / "assets" / "data" / "accommodations.json",
    ROOT / "data" / "accommodations.json",
]

EXPECTED_DISTRICTS = {
    "Baglung",
    "Gorkha",
    "Kaski",
    "Lamjung",
    "Manang",
    "Mustang",
    "Myagdi",
    "Nawalpur",
    "Parbat",
    "Syangja",
    "Tanahun",
}

SUPPORTED_PRIMARY_CATEGORIES = {
    "adventure",
    "boating",
    "cultural",
    "culture",
    "nature",
    "photography",
    "pilgrimage",
    "relaxation",
    "scenic",
    "spiritual",
    "trekking",
    "village",
    "wildlife",
}

GENERIC_DESCRIPTION_MARKERS = {
    "included in the offline Gandaki travel catalogue",
    "Gandaki Province destination suited for",
}


def load_json(path: Path) -> list[dict[str, Any]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise AssertionError(f"{path} must contain a JSON list")
    return data


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def validate_destinations(path: Path) -> list[dict[str, Any]]:
    destinations = load_json(path)

    require(len(destinations) == 300, f"{path}: expected 300 destinations")
    require(
        all(item.get("province") == "Gandaki" for item in destinations),
        f"{path}: all destinations must be in Gandaki",
    )

    ids = [item.get("id") for item in destinations]
    names = [str(item.get("name", "")).strip().lower() for item in destinations]
    require(len(ids) == len(set(ids)), f"{path}: duplicate destination IDs")
    require(len(names) == len(set(names)), f"{path}: duplicate destination names")

    districts = {item.get("district") for item in destinations}
    require(
        districts == EXPECTED_DISTRICTS,
        f"{path}: expected districts {sorted(EXPECTED_DISTRICTS)}, got {sorted(districts)}",
    )

    for item in destinations:
        prefix = f"{path}:{item.get('id')}"
        require(item.get("name"), f"{prefix}: missing name")
        require(item.get("district"), f"{prefix}: missing district")
        require(item.get("municipality"), f"{prefix}: missing municipality")
        require(item.get("category"), f"{prefix}: missing category")
        require(item["category"][0] in SUPPORTED_PRIMARY_CATEGORIES, f"{prefix}: unsupported primary category")
        require(len(item.get("activities", [])) >= 2, f"{prefix}: need at least 2 activities")
        require(len(item.get("best_season", [])) >= 2, f"{prefix}: need at least 2 seasons")
        require(item.get("budget_level") in {"budget", "medium", "premium"}, f"{prefix}: bad budget level")
        require(
            item.get("accessibility") in {"easy", "moderate", "difficult", "very difficult"},
            f"{prefix}: bad accessibility",
        )
        require(isinstance(item.get("family_friendly"), bool), f"{prefix}: family_friendly must be bool")
        require(1 <= int(item.get("adventure_level", 0)) <= 5, f"{prefix}: bad adventure_level")
        require(1 <= int(item.get("culture_level", 0)) <= 5, f"{prefix}: bad culture_level")
        require(1 <= int(item.get("nature_level", 0)) <= 5, f"{prefix}: bad nature_level")
        require(len(str(item.get("short_description", ""))) >= 40, f"{prefix}: short description too thin")
        require(len(str(item.get("full_description", ""))) >= 120, f"{prefix}: full description too thin")
        require(
            not any(marker in str(item.get("full_description", "")) for marker in GENERIC_DESCRIPTION_MARKERS),
            f"{prefix}: generic description marker present",
        )
        require(len(item.get("tags", [])) >= 8, f"{prefix}: need richer tags")

    return destinations


def validate_accommodations(path: Path, destination_ids: set[str]) -> None:
    accommodations = load_json(path)

    ids = [item.get("id") for item in accommodations]
    require(len(ids) == len(set(ids)), f"{path}: duplicate accommodation IDs")

    counts = Counter(item.get("destination_id") for item in accommodations)
    require(set(counts) == destination_ids, f"{path}: accommodation destinations do not match destination IDs")
    require(min(counts.values()) >= 2, f"{path}: every destination needs at least 2 accommodations")
    require(max(counts.values()) <= 3, f"{path}: every destination needs at most 3 accommodations")

    for item in accommodations:
        prefix = f"{path}:{item.get('id')}"
        require(item.get("destination_id") in destination_ids, f"{prefix}: unknown destination_id")
        require(item.get("destination_name"), f"{prefix}: missing destination_name")
        require(item.get("name"), f"{prefix}: missing accommodation name")
        require(item.get("type"), f"{prefix}: missing accommodation type")
        require(item.get("price_range") in {"budget", "medium", "premium"}, f"{prefix}: bad price_range")
        require(len(item.get("amenities", [])) >= 3, f"{prefix}: need at least 3 amenities")
        require(item.get("location_note"), f"{prefix}: missing location_note")


def main() -> None:
    baseline = validate_destinations(DESTINATION_FILES[0])
    baseline_ids = {item["id"] for item in baseline}
    baseline_names = [item["name"] for item in baseline]

    for path in DESTINATION_FILES[1:]:
        destinations = validate_destinations(path)
        require(
            [item["id"] for item in destinations] == [item["id"] for item in baseline],
            f"{path}: destination ordering or IDs differ from backend_destinations.json",
        )
        require(
            [item["name"] for item in destinations] == baseline_names,
            f"{path}: destination names differ from backend_destinations.json",
        )

    for path in ACCOMMODATION_FILES:
        validate_accommodations(path, baseline_ids)

    district_counts = Counter(item["district"] for item in baseline)
    print("Dataset quality validation passed.")
    print(f"Destinations: {len(baseline)}")
    print(f"Districts: {dict(sorted(district_counts.items()))}")
    print(f"Accommodation files validated: {len(ACCOMMODATION_FILES)}")


if __name__ == "__main__":
    main()
