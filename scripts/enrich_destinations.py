from __future__ import annotations

import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT_DIR = Path(__file__).resolve().parents[1]
DATA_FILE = ROOT_DIR / "data" / "destinations.json"
BACKUP_FILE = ROOT_DIR / "data" / "destinations_backup.json"
APP_DATA_FILE = ROOT_DIR / "app" / "assets" / "data" / "destinations.json"

ACCOMMODATION_TYPES = {
    "homestay",
    "guesthouse",
    "lodge",
    "hotel",
    "camping",
    "teahouse",
}

KNOWN_ELEVATIONS = {
    "ghandruk": 2012,
    "dhampus": 1650,
    "poon hill": 3210,
    "ghorepani": 2874,
    "mardi himal": 4500,
    "mardi himal base camp": 4500,
    "australian camp": 2060,
    "sarangkot": 1600,
    "kaskikot": 1788,
    "begnas lake": 650,
    "rupa lake": 600,
    "panchase": 2500,
    "sikles": 1980,
    "tangting": 1650,
    "jomsom": 2743,
    "muktinath": 3710,
    "kagbeni": 2804,
    "marpha": 2670,
    "tukuche": 2590,
    "lo manthang": 3840,
    "lupra": 2790,
    "dumba lake": 2830,
    "tilicho lake": 4919,
    "manang": 3519,
    "pisang": 3200,
    "braga": 3470,
    "bhraka": 3470,
    "nawal": 3660,
    "ngawal": 3660,
    "nar": 4110,
    "phu": 4080,
    "chame": 2670,
    "tal": 1700,
    "ghale gaun": 2100,
    "ghalegaon": 2100,
    "bhujung": 1696,
    "bandipur": 1030,
    "damauli": 360,
    "gorkha durbar": 1000,
    "barpak": 1900,
    "laprak": 2100,
    "siddha cave": 600,
    "kusma": 1294,
    "baglung kalika": 1020,
    "birethanti": 1025,
    "tatopani": 1190,
    "beni": 830,
    "galeshwor": 1170,
    "mohare danda": 3300,
    "khopra danda": 3660,
}

DISTRICT_ELEVATION_BASE = {
    "Kaski": 1100,
    "Tanahun": 650,
    "Syangja": 1000,
    "Gorkha": 1200,
    "Lamjung": 1400,
    "Manang": 3300,
    "Mustang": 2850,
    "Myagdi": 1400,
    "Baglung": 1100,
    "Parbat": 1000,
    "Nawalpur": 450,
}

DISTRICT_CONTEXT = {
    "Kaski": "Annapurna foothills, Pokhara valley culture, lakes, Gurung villages, and mountain viewpoints",
    "Tanahun": "Bandipur-side ridges, Seti-Madi valleys, caves, temples, and highway market towns",
    "Syangja": "mid-hill farming settlements, Kaligandaki valley culture, orange orchards, and rural viewpoints",
    "Gorkha": "historic hill settlements, Manaslu foothills, temples, ridges, and Gurung village landscapes",
    "Lamjung": "Marshyangdi valley villages, Gurung culture, waterfalls, and Annapurna-Manaslu trekking gateways",
    "Manang": "trans-Himalayan villages, high altitude trails, monasteries, cliffs, and Annapurna circuit landscapes",
    "Mustang": "Kali Gandaki corridor, Thakali settlements, arid cliffs, caves, monasteries, and apple villages",
    "Myagdi": "Dhaulagiri foothills, hot springs, Magar villages, rhododendron forests, and high ridge viewpoints",
    "Baglung": "Kaligandaki valley settlements, bridges, temples, Magar culture, and mid-hill farming landscapes",
    "Parbat": "suspension bridges, Kaligandaki gorge scenery, hill villages, and rural road-trip stops",
    "Nawalpur": "Chitwan buffer-zone culture, river plains, wetlands, Tharu settlements, and gentle nature walks",
}

DISTRICT_REACH = {
    "Kaski": "Travel from Pokhara by local bus, taxi, or jeep toward the nearest trailhead, then continue by short walk or village road depending on season.",
    "Tanahun": "Drive 2-4 hours from Pokhara along the Prithvi Highway toward Damauli or Bandipur, then use local jeep links or short walks to the site.",
    "Syangja": "Drive 2-4 hours from Pokhara through the Siddhartha Highway and rural feeder roads, with local buses and jeeps available from district towns.",
    "Gorkha": "Drive 4-6 hours from Pokhara via Abu Khaireni and Gorkha Bazaar, then continue by local jeep or village trail depending on the destination.",
    "Lamjung": "Drive 4-6 hours from Pokhara toward Besisahar and the Marshyangdi corridor, then use jeep roads or trekking trails to reach the village.",
    "Manang": "Drive from Pokhara via Besisahar and Chame on the Annapurna Circuit road, allowing extra time for rough roads and altitude acclimatization.",
    "Mustang": "Travel from Pokhara by flight or road to Jomsom and the Kali Gandaki corridor, then continue by local jeep, bus, or short trek.",
    "Myagdi": "Drive 4-6 hours from Pokhara through Baglung or Beni, then continue by jeep road or trekking trail into Dhaulagiri foothill villages.",
    "Baglung": "Drive 3-5 hours from Pokhara via Kushma and Baglung Bazaar, then continue by local jeep, bus, or short rural walk.",
    "Parbat": "Drive 2.5-4 hours from Pokhara through the Baglung Highway toward Kushma, then use local roads and suspension bridge links.",
    "Nawalpur": "Drive 4-6 hours from Pokhara toward the Narayanghat-Kawasoti corridor, then continue by local road to river, village, or buffer-zone sites.",
}

DISTRICT_CULTURE = {
    "Kaski": "Gurung hospitality, stone houses, millet fields, and Annapurna mountain identity",
    "Tanahun": "Newar, Magar, and hill farming traditions around Bandipur and Damauli",
    "Syangja": "Magar, Gurung, Brahmin-Chhetri farming culture and Kaligandaki valley life",
    "Gorkha": "Shah-era heritage, Gurung villages, Manaslu foothill culture, and temple traditions",
    "Lamjung": "Gurung village hospitality, Marshyangdi valley farming, and Annapurna-Manaslu gateway culture",
    "Manang": "Tibetan-influenced Buddhist culture, stone villages, monasteries, and high-altitude trade history",
    "Mustang": "Thakali and Tibetan-influenced culture, apple orchards, monasteries, caves, and salt-trade heritage",
    "Myagdi": "Magar settlements, Dhaulagiri trekking culture, hot-spring stops, and rhododendron forest life",
    "Baglung": "Kaligandaki valley trade, temples, bridges, and Magar-Newar hill town culture",
    "Parbat": "Kaligandaki gorge villages, bridge culture, farming terraces, and hill-town markets",
    "Nawalpur": "Tharu communities, river plains, wetland livelihoods, and Chitwan buffer-zone culture",
}

KNOWN_HIGHLIGHTS = {
    "ghandruk": [
        "Traditional Gurung stone architecture",
        "Annapurna II panoramic views",
        "Gurung Cultural Museum",
        "Gateway to Annapurna Base Camp trek",
        "Authentic homestay experience",
    ],
    "dhampus": [
        "Annapurna and Machhapuchhre sunrise views",
        "Easy ridge walk from Phedi",
        "Gurung village hospitality",
        "Pokhara valley panorama",
        "Short family-friendly trekking route",
    ],
    "jomsom": [
        "Kali Gandaki valley gateway",
        "Thakali food and culture",
        "Nilgiri and Dhaulagiri views",
        "Mustang road and flight hub",
        "Apple orchard country nearby",
    ],
    "muktinath": [
        "Sacred Hindu-Buddhist pilgrimage site",
        "108 water spouts and eternal flame",
        "High Mustang mountain landscape",
        "Gateway between Jomsom and Thorong La",
        "Tibetan-influenced village culture",
    ],
    "bandipur": [
        "Preserved Newar bazaar architecture",
        "Himalayan ridge views",
        "Siddha Cave access",
        "Traffic-free hill town atmosphere",
        "Heritage homestay and guesthouse stays",
    ],
}


def main() -> None:
    destinations = _read_json(DATA_FILE)
    original_texts = [_legacy_sbert_text(item) for item in destinations]

    if not BACKUP_FILE.exists():
        shutil.copy2(DATA_FILE, BACKUP_FILE)

    enriched = []
    for index, item in enumerate(destinations):
        enriched.append(_enrich_item(item, destinations, index))

    DATA_FILE.write_text(
        json.dumps(enriched, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    APP_DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    APP_DATA_FILE.write_text(
        json.dumps(enriched, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    new_texts = [item["sbert_text"] for item in enriched]
    print(f"Enriched destinations: {len(enriched)}")
    print(f"Backup: {BACKUP_FILE.relative_to(ROOT_DIR)}")
    print(f"Updated app asset: {APP_DATA_FILE.relative_to(ROOT_DIR)}")
    print(
        "Average SBERT text length before/after: "
        f"{_avg_len(original_texts):.1f} -> {_avg_len(new_texts):.1f} chars"
    )
    print(
        "Generated at: "
        f"{datetime.now(timezone.utc).replace(microsecond=0).isoformat()}"
    )


def _read_json(path: Path) -> list[dict[str, Any]]:
    return json.loads(path.read_text(encoding="utf-8"))


def _enrich_item(
    item: dict[str, Any],
    all_destinations: list[dict[str, Any]],
    index: int,
) -> dict[str, Any]:
    enriched = dict(item)
    name = str(enriched.get("name", "")).strip()
    district = str(enriched.get("district", "")).strip()
    category = _string_list(enriched.get("category"))
    activities = _string_list(enriched.get("activities"))
    tags = _string_list(enriched.get("tags"))
    best_season = _string_list(enriched.get("best_season"))

    highlights = _build_highlights(name, district, category, activities, tags)
    how_to_reach = _build_how_to_reach(name, district, category, activities)
    accommodation_types = _infer_accommodation_types(
        category,
        activities,
        tags,
        str(enriched.get("budget_level", "")),
    )
    elevation_m = _infer_elevation(name, district, category, tags, index)
    typical_duration = _infer_duration(
        category,
        activities,
        int(enriched.get("adventure_level") or 2),
        district,
    )
    nearby_destinations = _nearby_destinations(enriched, all_destinations)

    full_description = str(enriched.get("full_description", "")).strip()
    if len(full_description) < 300:
        full_description = _extend_description(
            item=enriched,
            highlights=highlights,
            how_to_reach=how_to_reach,
            accommodation_types=accommodation_types,
            elevation_m=elevation_m,
            typical_duration=typical_duration,
        )

    enriched["highlights"] = highlights
    enriched["how_to_reach"] = how_to_reach
    enriched["accommodation_types"] = accommodation_types
    enriched["elevation_m"] = elevation_m
    enriched["typical_duration"] = typical_duration
    enriched["nearby_destinations"] = nearby_destinations
    enriched["full_description"] = full_description
    enriched["sbert_text"] = _build_sbert_text(
        name=name,
        full_description=full_description,
        activities=activities,
        best_season=best_season,
        category=category,
        highlights=highlights,
        how_to_reach=how_to_reach,
    )
    return enriched


def _build_highlights(
    name: str,
    district: str,
    category: list[str],
    activities: list[str],
    tags: list[str],
) -> list[str]:
    key = name.lower()
    for known_name, highlights in KNOWN_HIGHLIGHTS.items():
        if known_name in key:
            return highlights[:5]

    lowered = {value.lower() for value in category + activities + tags}
    highlights: list[str] = []

    if {"trekking", "hiking", "adventure"} & lowered:
        highlights.append(f"Rural trail access around {name}")
    if {"viewpoint", "scenic", "photography"} & lowered:
        highlights.append(_mountain_view_highlight(district))
    if {"village", "cultural", "culture", "heritage"} & lowered:
        highlights.append(_culture_highlight(district))
    if {"spiritual", "pilgrimage", "religious", "worship"} & lowered:
        highlights.append("Local temple, monastery, or pilgrimage atmosphere")
    if {"lake", "boating"} & lowered:
        highlights.append("Calm lake scenery and boating-friendly shoreline")
    if {"river"} & lowered:
        highlights.append("River corridor walks and valley landscapes")
    if {"wildlife"} & lowered:
        highlights.append("Wetland, forest, or buffer-zone wildlife viewing")
    if {"relaxation", "nature", "nature walk"} & lowered:
        highlights.append("Quiet nature walks through rural scenery")
    if "homestay" in lowered:
        highlights.append("Community homestay hospitality")

    highlights.extend(
        [
            f"Authentic {district or 'Gandaki'} rural tourism stop",
            f"Photography points around {name}",
            "Seasonal farming terraces and village life",
        ]
    )

    return _unique(highlights)[:5]


def _build_how_to_reach(
    name: str,
    district: str,
    category: list[str],
    activities: list[str],
) -> str:
    key = name.lower()
    if "ghandruk" in key:
        return "Drive about 2 hours from Pokhara to Nayapul or Kimche, then trek 1.5-4 hours uphill depending on road access."
    if "dhampus" in key:
        return "Drive 45-60 minutes from Pokhara to Phedi or Kande, then walk 1-2 hours along the ridge trail."
    if "jomsom" in key:
        return "Travel from Pokhara by morning flight or by road through Beni and Tatopani to Jomsom in the Kali Gandaki valley."
    if "muktinath" in key:
        return "Travel from Pokhara to Jomsom by flight or road, then continue by jeep toward Ranipauwa and walk to the temple complex."
    if "bandipur" in key:
        return "Drive 2.5-3 hours from Pokhara along the Prithvi Highway to Dumre, then climb by local road to Bandipur Bazaar."

    base = DISTRICT_REACH.get(
        district,
        "Travel from Pokhara by local bus or private jeep to the nearest district town, then continue by rural road or short walking trail.",
    )
    if "trekking" in category or "trekking" in activities:
        return f"{base} Carry basic trekking gear because the final approach to {name} may include uphill village trails."
    return f"{base} Ask locally for the final road condition before heading to {name}, especially during monsoon."


def _infer_accommodation_types(
    category: list[str],
    activities: list[str],
    tags: list[str],
    budget_level: str,
) -> list[str]:
    lowered = {value.lower() for value in category + activities + tags}
    result: list[str] = []

    for value in ACCOMMODATION_TYPES:
        if value in lowered:
            result.append(value)

    if {"trekking", "hiking", "adventure"} & lowered:
        result.extend(["teahouse", "lodge"])
    if {"village", "cultural", "culture"} & lowered:
        result.extend(["homestay", "guesthouse"])
    if {"lake", "boating", "market town", "gateway"} & lowered:
        result.extend(["guesthouse", "hotel"])
    if {"wildlife", "nature"} & lowered and "premium" not in budget_level.lower():
        result.append("homestay")
    if "camping" in lowered:
        result.append("camping")

    if budget_level.lower() == "premium":
        result.extend(["hotel", "lodge"])
    elif budget_level.lower() == "budget":
        result.extend(["homestay", "guesthouse"])
    else:
        result.extend(["guesthouse", "lodge"])

    return [value for value in _unique(result) if value in ACCOMMODATION_TYPES][:4]


def _infer_elevation(
    name: str,
    district: str,
    category: list[str],
    tags: list[str],
    index: int,
) -> int:
    key = name.lower()
    for known_name, elevation in KNOWN_ELEVATIONS.items():
        if known_name in key:
            return elevation

    base = DISTRICT_ELEVATION_BASE.get(district, 1000)
    lowered = {value.lower() for value in category + tags}

    if {"lake", "river", "boating", "wildlife"} & lowered:
        base -= 250
    if {"viewpoint", "trekking", "adventure"} & lowered:
        base += 450
    if {"village", "cultural", "heritage"} & lowered:
        base += 150
    if district in {"Manang", "Mustang"} and {"trekking", "viewpoint"} & lowered:
        base += 500

    variation = ((_stable_hash(name) + index * 37) % 360) - 180
    return int(max(250, min(5200, base + variation)))


def _infer_duration(
    category: list[str],
    activities: list[str],
    adventure_level: int,
    district: str,
) -> str:
    lowered = {value.lower() for value in category + activities}

    if district in {"Manang", "Mustang"} and adventure_level >= 3:
        return "3-5 days"
    if {"trekking", "adventure"} & lowered:
        if adventure_level >= 4:
            return "3-5 days"
        if adventure_level >= 3:
            return "1-2 days"
        return "full day"
    if {"lake", "boating", "cave", "landmark", "market town"} & lowered:
        return "half day"
    if {"spiritual", "pilgrimage", "religious"} & lowered:
        return "half day to 1 day"
    if {"village", "cultural", "nature"} & lowered:
        return "1-2 days"
    return "half day"


def _nearby_destinations(
    item: dict[str, Any],
    all_destinations: list[dict[str, Any]],
) -> list[str]:
    lat = _to_float(item.get("latitude"))
    lon = _to_float(item.get("longitude"))
    name = str(item.get("name", ""))
    district = str(item.get("district", ""))

    candidates: list[tuple[float, str]] = []
    for other in all_destinations:
        other_name = str(other.get("name", ""))
        if other_name == name:
            continue

        other_lat = _to_float(other.get("latitude"))
        other_lon = _to_float(other.get("longitude"))
        if lat is not None and lon is not None and other_lat is not None and other_lon is not None:
            distance = (lat - other_lat) ** 2 + (lon - other_lon) ** 2
        elif str(other.get("district", "")) == district:
            distance = 1.0 + (_stable_hash(other_name) % 1000) / 10000
        else:
            continue
        candidates.append((distance, other_name))

    candidates.sort(key=lambda value: value[0])
    nearby = [candidate_name for _, candidate_name in candidates[:4]]

    if len(nearby) >= 2:
        return nearby

    district_matches = [
        str(other.get("name", ""))
        for other in all_destinations
        if str(other.get("name", "")) != name
        and str(other.get("district", "")) == district
    ]
    return _unique(nearby + district_matches)[:4]


def _extend_description(
    *,
    item: dict[str, Any],
    highlights: list[str],
    how_to_reach: str,
    accommodation_types: list[str],
    elevation_m: int,
    typical_duration: str,
) -> str:
    name = str(item.get("name", "")).strip()
    district = str(item.get("district", "")).strip()
    category = ", ".join(_string_list(item.get("category"))[:4])
    activities = ", ".join(_string_list(item.get("activities"))[:4])
    best_season = ", ".join(_string_list(item.get("best_season"))[:3]) or "most clear-weather months"
    current = str(item.get("full_description") or item.get("short_description") or "").strip()
    context = DISTRICT_CONTEXT.get(district, "Gandaki's rural hill and valley landscape")
    culture = DISTRICT_CULTURE.get(district, "local farming culture and village hospitality")

    additions = (
        f"{name} is a {category or 'rural tourism'} destination in {district or 'Gandaki'} "
        f"at about {elevation_m} metres, shaped by {context}. "
        f"Travelers usually come for {activities or 'photography, village walks, and cultural encounters'}, "
        f"with the strongest experience in {best_season}. "
        f"Key highlights include {', '.join(highlights[:4])}. "
        f"The place suits a {typical_duration} visit and commonly works with "
        f"{', '.join(accommodation_types)} options where available. "
        f"It offers {culture}, making it useful for visitors who want an authentic rural Nepal stop rather than only a city-based itinerary. "
        f"{how_to_reach}"
    )

    if current:
        combined = f"{current} {additions}"
    else:
        combined = additions

    return combined.strip()


def _build_sbert_text(
    *,
    name: str,
    full_description: str,
    activities: list[str],
    best_season: list[str],
    category: list[str],
    highlights: list[str],
    how_to_reach: str,
) -> str:
    return (
        f"{name}. {full_description} "
        f"Activities: {', '.join(activities)}. "
        f"Best season: {', '.join(best_season)}. "
        f"Vibe: {', '.join(category)}. "
        f"Highlights: {', '.join(highlights)}. "
        f"{how_to_reach}"
    ).strip()


def _legacy_sbert_text(item: dict[str, Any]) -> str:
    parts = [
        str(item.get("name", "")),
        str(item.get("district", "")),
        str(item.get("province", "")),
        ", ".join(_string_list(item.get("category"))),
        ", ".join(_string_list(item.get("activities"))),
        ", ".join(_string_list(item.get("tags"))),
        str(item.get("short_description", "")),
        str(item.get("full_description", "")),
        str(item.get("budget_level", "")),
        str(item.get("accessibility", "")),
        ", ".join(_string_list(item.get("best_season"))),
    ]
    return " ".join(part for part in parts if part).strip()


def _mountain_view_highlight(district: str) -> str:
    if district in {"Kaski", "Myagdi", "Parbat"}:
        return "Annapurna and Dhaulagiri mountain views"
    if district in {"Gorkha", "Lamjung"}:
        return "Manaslu and Annapurna foothill views"
    if district == "Mustang":
        return "Nilgiri, Dhaulagiri, and Kali Gandaki valley views"
    if district == "Manang":
        return "Annapurna, Gangapurna, and high Himalayan views"
    return "Open hill, valley, and mountain viewpoints"


def _culture_highlight(district: str) -> str:
    context = DISTRICT_CULTURE.get(district, "local village culture")
    return context[0].upper() + context[1:]


def _string_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    return [part.strip() for part in str(value).split("|") if part.strip()]


def _unique(values: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        normalized = value.strip().lower()
        if normalized and normalized not in seen:
            result.append(value.strip())
            seen.add(normalized)
    return result


def _stable_hash(value: str) -> int:
    total = 0
    for char in value:
        total = (total * 33 + ord(char)) % 1000003
    return total


def _to_float(value: Any) -> float | None:
    try:
        if value is None:
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def _avg_len(values: list[str]) -> float:
    if not values:
        return 0.0
    return sum(len(value) for value in values) / len(values)


if __name__ == "__main__":
    main()
