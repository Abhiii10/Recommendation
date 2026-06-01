from __future__ import annotations

import logging
from typing import List

import httpx
from fastapi import HTTPException

from backend.application.dto.requests import ChatRequestDto
from backend.application.dto.responses import ChatResponseDto
from backend.application.services.chat_fallback import build_rule_based_chat_response
from backend.core.config import settings
from backend.domain.entities.destination import Destination
from backend.infrastructure.ml.candidate_retriever import CandidateRetriever
from backend.infrastructure.repositories.json_destination_repository import (
    JsonDestinationRepository,
)

logger = logging.getLogger(__name__)


SYSTEM_PROMPT = """
You are a Nepal Rural Tourism assistant for a Flutter tourism app.

Your job:
- Answer questions about rural tourism in Nepal.
- Help with destinations, trekking, homestays, food, culture, transport, safety, budget, and recommendations.
- Use the provided destination context whenever it is relevant.
- Do not invent exact prices, road times, permit rules, or safety guarantees if the context does not provide them.
- If information is uncertain, clearly say that the user should confirm locally.
- Keep answers practical, friendly, and useful for tourists.
- Use short paragraphs and bullets when helpful.
- Mention emergency numbers only for safety or emergency questions:
  Police 100, Ambulance 102, Tourist Police 01-4247041.
"""


class GroqChatService:
    def __init__(self) -> None:
        self._destination_repo = JsonDestinationRepository()
        self._destinations = self._destination_repo.get_all()
        self._retriever: CandidateRetriever | None = None
        if settings.offline_mode:
            return
        try:
            self._retriever = CandidateRetriever(self._destinations)
        except Exception as exc:
            logger.warning(
                "SBERT retriever unavailable; using keyword chat fallback: %s",
                exc,
            )

    async def answer(self, request: ChatRequestDto) -> ChatResponseDto:
        question = request.question.strip()

        if not question:
            raise HTTPException(
                status_code=400,
                detail="Question cannot be empty.",
            )

        context_destinations = self._retrieve_destinations(
            question=question,
            top_k=request.top_k,
        )

        if settings.offline_mode:
            return build_rule_based_chat_response(
                question,
                context_destinations,
                reason="OFFLINE_MODE=true",
            )

        if not settings.groq_api_key:
            return build_rule_based_chat_response(
                question,
                context_destinations,
                reason="GROQ_API_KEY is not configured",
            )

        context = self._build_context(context_destinations)

        prompt = f"""
User question:
{question}

Relevant destination context:
{context}

Answer the user using the context above when possible.
If the context is not enough, give general rural tourism guidance and clearly say what should be confirmed locally.
""".strip()

        messages = [{"role": "system", "content": SYSTEM_PROMPT.strip()}]

        for turn in request.history:
            messages.append(
                {
                    "role": self._groq_role(turn.role),
                    "content": turn.text,
                }
            )

        messages.append({"role": "user", "content": prompt})

        payload = {
            "model": settings.groq_model,
            "messages": messages,
            "temperature": settings.groq_temperature,
            "max_tokens": settings.groq_max_output_tokens,
        }

        url = f"{settings.groq_base_url.rstrip('/')}/chat/completions"

        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                response = await client.post(
                    url,
                    headers={
                        "Authorization": f"Bearer {settings.groq_api_key}",
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
        except httpx.ConnectError as exc:
            logger.warning("Groq connection failed; using fallback: %s", exc)
            return build_rule_based_chat_response(
                question,
                context_destinations,
                reason="the Groq service could not be reached",
            )
        except httpx.TimeoutException as exc:
            logger.warning("Groq request timed out; using fallback: %s", exc)
            return build_rule_based_chat_response(
                question,
                context_destinations,
                reason="the Groq request timed out",
            )
        except httpx.HTTPError as exc:
            logger.warning("Groq HTTP error; using fallback: %s", exc)
            return build_rule_based_chat_response(
                question,
                context_destinations,
                reason="the Groq request failed",
            )
        except Exception as exc:
            logger.exception("Unexpected Groq chat failure; using fallback")
            return build_rule_based_chat_response(
                question,
                context_destinations,
                reason=f"the Groq request failed unexpectedly: {type(exc).__name__}",
            )

        if response.status_code < 200 or response.status_code >= 300:
            logger.warning(
                "Groq API returned %s; using fallback: %s",
                response.status_code,
                response.text[:300],
            )
            return build_rule_based_chat_response(
                question,
                context_destinations,
                reason=f"Groq returned HTTP {response.status_code}",
            )

        try:
            data = response.json()
        except ValueError as exc:
            logger.warning("Groq returned invalid JSON; using fallback: %s", exc)
            return build_rule_based_chat_response(
                question,
                context_destinations,
                reason="Groq returned an invalid response",
            )

        answer = self._extract_answer(data)

        if not answer:
            return build_rule_based_chat_response(
                question,
                context_destinations,
                reason="Groq returned an empty answer",
            )

        return ChatResponseDto(
            answer=answer,
            source="groq",
            used_context=[destination.name for destination in context_destinations],
        )

    def _retrieve_destinations(
        self,
        question: str,
        top_k: int,
    ) -> List[Destination]:
        try:
            if self._retriever is None:
                return self._keyword_retrieve(question, top_k)
            candidates = self._retriever.retrieve(
                query_text=question,
                top_k=top_k,
            )
            return [candidate["destination"] for candidate in candidates]
        except Exception:
            return self._keyword_retrieve(question, top_k)

    def _keyword_retrieve(
        self,
        question: str,
        top_k: int,
    ) -> List[Destination]:
        question_lower = question.lower()
        question_tokens = self._tokens(question)

        scored: List[tuple[float, Destination]] = []

        for destination in self._destinations:
            destination_text = self._destination_search_text(destination)
            destination_tokens = self._tokens(destination_text)

            overlap_score = float(len(question_tokens.intersection(destination_tokens)))

            name_bonus = 0.0
            if destination.name.lower() in question_lower:
                name_bonus = 8.0

            activity_bonus = 0.0
            for activity in destination.activities:
                if activity.lower() in question_lower:
                    activity_bonus += 2.5

            category_bonus = 0.0
            for category in destination.category:
                if category.lower() in question_lower:
                    category_bonus += 2.0

            tag_bonus = 0.0
            for tag in destination.tags:
                if tag.lower() in question_lower:
                    tag_bonus += 1.5

            location_bonus = 0.0
            for value in [
                destination.district,
                destination.province,
                destination.municipality,
            ]:
                if value and value.lower() in question_lower:
                    location_bonus += 1.5

            score = (
                overlap_score
                + name_bonus
                + activity_bonus
                + category_bonus
                + tag_bonus
                + location_bonus
            )

            if score > 0:
                scored.append((score, destination))

        scored.sort(key=lambda item: item[0], reverse=True)

        if scored:
            return [destination for _, destination in scored[:top_k]]

        return self._destinations[:top_k]

    def _build_context(self, destinations: List[Destination]) -> str:
        if not destinations:
            return "No matching destination context found."

        blocks: List[str] = []

        for destination in destinations:
            blocks.append(
                "\n".join(
                    [
                        f"Name: {destination.name}",
                        f"Location: {self._join_non_empty([destination.municipality, destination.district, destination.province])}",
                        f"Category: {', '.join(destination.category)}",
                        f"Activities: {', '.join(destination.activities)}",
                        f"Best season: {', '.join(destination.best_season)}",
                        f"Budget level: {destination.budget_level}",
                        f"Accessibility: {destination.accessibility}",
                        f"Family friendly: {'yes' if destination.family_friendly else 'limited or unknown'}",
                        f"Adventure level: {destination.adventure_level or 'unknown'}",
                        f"Culture level: {destination.culture_level or 'unknown'}",
                        f"Nature level: {destination.nature_level or 'unknown'}",
                        f"Short description: {destination.short_description}",
                        f"Full description: {destination.full_description}",
                        f"Tags: {', '.join(destination.tags)}",
                    ]
                )
            )

        return "\n\n---\n\n".join(blocks)

    def _destination_search_text(self, destination: Destination) -> str:
        return " ".join(
            [
                destination.name,
                destination.province or "",
                destination.district or "",
                destination.municipality or "",
                " ".join(destination.category),
                " ".join(destination.activities),
                " ".join(destination.best_season),
                destination.budget_level or "",
                destination.accessibility or "",
                destination.short_description or "",
                destination.full_description or "",
                " ".join(destination.tags),
            ]
        )

    def _tokens(self, value: str) -> set[str]:
        cleaned = "".join(
            character.lower() if character.isalnum() or character.isspace() else " "
            for character in value
        )

        stopwords = {
            "the",
            "a",
            "an",
            "is",
            "are",
            "to",
            "in",
            "of",
            "for",
            "and",
            "or",
            "with",
            "me",
            "my",
            "i",
            "can",
            "you",
            "tell",
            "about",
            "what",
            "where",
            "how",
            "when",
            "should",
            "visit",
            "go",
            "there",
            "please",
            "need",
            "want",
            "place",
            "places",
            "destination",
            "destinations",
        }

        return {
            token
            for token in cleaned.split()
            if len(token) >= 3 and token not in stopwords
        }

    def _join_non_empty(self, values: List[str | None]) -> str:
        result = [value for value in values if value and value.strip()]
        return ", ".join(result) if result else "Unknown"

    def _groq_role(self, role: str) -> str:
        normalized = role.strip().lower()
        if normalized in {"assistant", "model"}:
            return "assistant"
        if normalized == "system":
            return "system"
        return "user"

    def _extract_answer(self, data: dict) -> str:
        choices = data.get("choices")
        if not isinstance(choices, list) or not choices:
            return ""

        first = choices[0]
        if not isinstance(first, dict):
            return ""

        message = first.get("message")
        if not isinstance(message, dict):
            return ""

        content = message.get("content")
        if not isinstance(content, str):
            return ""

        return content.strip()
