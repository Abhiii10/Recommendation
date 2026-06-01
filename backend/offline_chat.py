from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path
from typing import Any, Iterable


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DESTINATIONS_FILE = PROJECT_ROOT / "data" / "destinations.json"


class OfflineChatHandler:
    def __init__(self, destinations_file: Path = DESTINATIONS_FILE) -> None:
        self._destinations = self._load_destinations(destinations_file)

    def reply(
        self,
        question: str,
        *,
        top_k: int = 3,
        context_destinations: Iterable[Any] = (),
        reason: str = "",
    ) -> dict[str, Any]:
        clean_question = question.strip()
        intent = self._detect_intent(clean_question)

        if intent == "destination_query":
            destinations = self._rank_destinations(
                clean_question,
                top_k=top_k,
                context_destinations=context_destinations,
            )
            text = self._destination_response(destinations, reason=reason)
            used_context = [destination["name"] for destination in destinations]
        elif intent == "greeting":
            text = (
                "Namaste! I am using local tourism guidance right now. You can ask "
                "about Gandaki destinations, budget, best season, activities, or "
                "travel safety."
            )
            used_context = []
        elif intent == "budget_query":
            text = (
                "Budget tip for rural Gandaki: carry cash, confirm homestay prices "
                "before check-in, and plan extra money for local transport. Village "
                "homestays and basic lodges are usually the best low-cost options."
            )
            used_context = []
        elif intent == "season_query":
            text = (
                "For most Gandaki rural trips, spring and autumn are the safest "
                "general choices because skies are clearer and trails are easier. "
                "Monsoon can be beautiful but roads and trails may be slippery."
            )
            used_context = []
        elif intent == "activity_query":
            text = (
                "Popular rural tourism activities in Gandaki include trekking, "
                "village homestays, cultural walks, lake visits, wildlife watching, "
                "photography, and pilgrimage. Ask for a specific activity and I can "
                "suggest matching places from the local dataset."
            )
            used_context = []
        else:
            text = (
                "I am using local responses right now. I can still help with rural "
                "Nepal travel basics: destinations, budget, season, trekking, "
                "homestays, safety, and offline map use."
            )
            used_context = []

        return {
            "reply": text,
            "answer": text,
            "offline": True,
            "fallback": "rule_based",
            "intent": intent,
            "source": "offline_rule_based",
            "used_context": used_context,
        }

    def _detect_intent(self, question: str) -> str:
        normalized = question.lower()
        tokens = set(_tokens(normalized))

        if tokens.intersection({"hi", "hello", "hey", "namaste", "namaskar"}):
            return "greeting"

        if _contains_any(
            normalized,
            {
                "budget",
                "cost",
                "price",
                "cheap",
                "expensive",
                "money",
                "rs",
                "rupee",
                "hotel price",
                "homestay price",
            },
        ):
            return "budget_query"

        if _contains_any(
            normalized,
            {
                "season",
                "weather",
                "best time",
                "month",
                "spring",
                "autumn",
                "winter",
                "summer",
                "monsoon",
            },
        ):
            return "season_query"

        if _contains_any(
            normalized,
            {
                "trek",
                "trekking",
                "hiking",
                "boating",
                "culture",
                "cultural",
                "wildlife",
                "photography",
                "pilgrimage",
                "temple",
                "adventure",
                "homestay",
            },
        ):
            if _contains_any(normalized, {"where", "place", "destination", "recommend"}):
                return "destination_query"
            return "activity_query"

        if _contains_any(
            normalized,
            {
                "destination",
                "destinations",
                "place",
                "places",
                "visit",
                "recommend",
                "where",
                "near",
                "village",
                "pokhara",
                "gandaki",
                "kaski",
                "mustang",
                "manang",
                "lamjung",
                "tanahun",
                "syangja",
                "myagdi",
                "baglung",
                "parbat",
                "gorkha",
                "nawalpur",
            },
        ):
            return "destination_query"

        if _contains_any(normalized, {"help", "guide", "how", "offline"}):
            return "help"

        if self._has_destination_match(question):
            return "destination_query"

        return "help"

    def _has_destination_match(self, question: str) -> bool:
        query = question.lower()
        query_tokens = set(_tokens(query))
        if not query_tokens:
            return False

        for destination in self._destinations:
            name = str(destination.get("name", "")).lower()
            if name and name in query:
                return True

            direct_values = [
                destination.get("district"),
                destination.get("municipality"),
                *_string_list(destination.get("category")),
                *_string_list(destination.get("activities")),
                *_string_list(destination.get("tags")),
            ]
            if any(str(value).lower() in query for value in direct_values if value):
                return True

            destination_tokens = set(_tokens(_search_text(destination)))
            if len(query_tokens.intersection(destination_tokens)) >= 2:
                return True

        return False

    def _rank_destinations(
        self,
        question: str,
        *,
        top_k: int,
        context_destinations: Iterable[Any] = (),
    ) -> list[dict[str, Any]]:
        context = [_destination_to_dict(item) for item in context_destinations]
        if context:
            return context[:top_k]

        query = question.lower()
        query_tokens = set(_tokens(query))
        scored: list[tuple[float, dict[str, Any]]] = []

        for destination in self._destinations:
            score = 0.0
            name = str(destination.get("name", "")).lower()
            district = str(destination.get("district", "")).lower()
            municipality = str(destination.get("municipality", "")).lower()
            categories = _string_list(destination.get("category"))
            activities = _string_list(destination.get("activities"))
            tags = _string_list(destination.get("tags"))

            if name and name in query:
                score += 8.0
            if district and district in query:
                score += 2.5
            if municipality and municipality in query:
                score += 2.0

            for value in categories:
                if value.lower() in query:
                    score += 3.0
            for value in activities:
                if value.lower() in query:
                    score += 3.0
            for value in tags:
                if value.lower() in query:
                    score += 1.5

            destination_tokens = set(_tokens(_search_text(destination)))
            score += len(query_tokens.intersection(destination_tokens)) * 0.8

            if score > 0:
                scored.append((score, destination))

        scored.sort(key=lambda item: item[0], reverse=True)
        if scored:
            return [destination for _, destination in scored[:top_k]]

        return self._destinations[:top_k]

    def _destination_response(
        self,
        destinations: list[dict[str, Any]],
        *,
        reason: str,
    ) -> str:
        if not destinations:
            return (
                "I am using local responses right now, but I could not find a "
                "matching destination in the offline dataset. Try asking for "
                "trekking, culture, village, nature, boating, or a district name."
            )

        heading = "AI offline - using local destination matches."
        if reason:
            heading = f"{heading} Reason: {reason}."

        lines = [heading, "", "Top local suggestions:"]
        for destination in destinations[:3]:
            name = destination.get("name", "Unknown destination")
            location = _location(destination)
            category = ", ".join(_string_list(destination.get("category"))[:3])
            season = ", ".join(_string_list(destination.get("best_season"))[:3])
            description = (
                destination.get("short_description")
                or destination.get("full_description")
                or "A rural tourism destination in Gandaki Province."
            )
            lines.append(
                f"- {name} ({location}): {description} "
                f"Category: {category or 'rural tourism'}. "
                f"Best season: {season or 'confirm locally'}."
            )

        return "\n".join(lines).strip()

    def _load_destinations(self, path: Path) -> list[dict[str, Any]]:
        try:
            with path.open("r", encoding="utf-8") as handle:
                data = json.load(handle)
            if isinstance(data, list):
                return [
                    item
                    for item in data
                    if isinstance(item, dict) and item.get("name")
                ]
        except Exception:
            return []
        return []


@lru_cache(maxsize=1)
def get_offline_chat_handler() -> OfflineChatHandler:
    return OfflineChatHandler()


def build_offline_chat_reply(
    question: str,
    *,
    top_k: int = 3,
    context_destinations: Iterable[Any] = (),
    reason: str = "",
) -> dict[str, Any]:
    return get_offline_chat_handler().reply(
        question,
        top_k=top_k,
        context_destinations=context_destinations,
        reason=reason,
    )


def _destination_to_dict(item: Any) -> dict[str, Any]:
    if isinstance(item, dict):
        return item
    if hasattr(item, "model_dump"):
        return item.model_dump()
    return {
        "name": getattr(item, "name", ""),
        "district": getattr(item, "district", ""),
        "municipality": getattr(item, "municipality", ""),
        "province": getattr(item, "province", ""),
        "category": getattr(item, "category", []),
        "activities": getattr(item, "activities", []),
        "best_season": getattr(item, "best_season", []),
        "short_description": getattr(item, "short_description", ""),
        "full_description": getattr(item, "full_description", ""),
        "tags": getattr(item, "tags", []),
    }


def _search_text(destination: dict[str, Any]) -> str:
    values = [
        destination.get("name", ""),
        destination.get("province", ""),
        destination.get("district", ""),
        destination.get("municipality", ""),
        " ".join(_string_list(destination.get("category"))),
        " ".join(_string_list(destination.get("activities"))),
        " ".join(_string_list(destination.get("best_season"))),
        destination.get("budget_level", ""),
        destination.get("accessibility", ""),
        destination.get("short_description", ""),
        destination.get("full_description", ""),
        " ".join(_string_list(destination.get("tags"))),
    ]
    return " ".join(str(value) for value in values)


def _tokens(value: str) -> list[str]:
    return [
        token
        for token in re.sub(r"[^a-z0-9\s]", " ", value.lower()).split()
        if len(token) >= 3 and token not in _STOPWORDS
    ]


def _string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item) for item in value if str(item).strip()]


def _contains_any(value: str, terms: set[str]) -> bool:
    return any(term in value for term in terms)


def _location(destination: dict[str, Any]) -> str:
    parts = [
        destination.get("municipality"),
        destination.get("district"),
        destination.get("province"),
    ]
    clean = [str(part).strip() for part in parts if str(part or "").strip()]
    return ", ".join(clean) if clean else "Gandaki Province"


_STOPWORDS = {
    "the",
    "and",
    "for",
    "with",
    "about",
    "tell",
    "what",
    "where",
    "which",
    "please",
    "need",
    "want",
    "visit",
    "place",
    "places",
    "destination",
    "destinations",
}
