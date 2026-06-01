from __future__ import annotations

from typing import Iterable

from backend.application.dto.responses import ChatResponseDto
from backend.offline_chat import build_offline_chat_reply
from backend.domain.entities.destination import Destination


def build_rule_based_chat_response(
    question: str,
    context_destinations: Iterable[Destination],
    *,
    reason: str,
) -> ChatResponseDto:
    payload = build_offline_chat_reply(
        question,
        top_k=3,
        context_destinations=context_destinations,
        reason=reason,
    )
    answer = str(payload["reply"])
    return ChatResponseDto(
        answer=answer,
        reply=answer,
        source="offline_rule_based",
        used_context=[
            str(name)
            for name in payload.get("used_context", [])
            if str(name).strip()
        ],
        offline=True,
        fallback="rule_based",
    )


def _answer_text(
    question: str,
    destinations: list[Destination],
    reason: str,
) -> str:
    normalized = question.lower()

    if _contains_any(
        normalized,
        {
            "emergency",
            "police",
            "ambulance",
            "injured",
            "accident",
            "lost",
            "rescue",
            "help",
        },
    ):
        return (
            "Offline safety response: if this is an emergency, call Police 100, "
            "Ambulance 102, or Tourist Police 01-4247041. Share your location "
            "with a trusted person, move to a safe visible place, and ask a "
            "nearby hotel, homestay, or local authority for help."
        )

    if destinations:
        lines = [
            f"AI chat is using local fallback because {reason}.",
            "",
            "Relevant destination suggestions:",
        ]
        for destination in destinations[:3]:
            location = _location_text(destination)
            description = (
                destination.short_description
                or destination.full_description
                or "A rural tourism destination in Nepal."
            )
            lines.append(f"- {destination.name} ({location}): {description}")
        lines.append("")
        lines.append(
            "For full AI responses, connect the backend to the internet and "
            "configure GROQ_API_KEY or GEMINI_API_KEY."
        )
        return "\n".join(lines)

    return (
        f"AI chat is using local fallback because {reason}. I can still help "
        "with rural Nepal travel basics: check weather before leaving, carry "
        "cash and water, confirm transport locally, save important places, and "
        "use offline maps in remote areas. For full AI responses, configure "
        "GROQ_API_KEY or GEMINI_API_KEY and restart the backend."
    )


def _contains_any(value: str, terms: set[str]) -> bool:
    return any(term in value for term in terms)


def _location_text(destination: Destination) -> str:
    parts = [
        destination.municipality,
        destination.district,
        destination.province,
    ]
    result = [part for part in parts if part and part.strip()]
    return ", ".join(result) if result else "Gandaki Province"
