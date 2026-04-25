from __future__ import annotations

from typing import List

import httpx
from fastapi import HTTPException

from backend.application.dto.requests import ChatRequestDto
from backend.application.dto.responses import ChatResponseDto
from backend.core.config import settings
from backend.domain.entities.destination import Destination
from backend.infrastructure.repositories.json_destination_repository import (
    JsonDestinationRepository,
)


SYSTEM_PROMPT = """
You are a Nepal Rural Tourism assistant for a Flutter tourism app.

Your job:
- Answer questions about rural tourism in Nepal.
- Help with destinations, trekking, homestays, food, culture, transport, safety, budget, and recommendations.
- Use the provided destination context whenever it is relevant.
- Do not invent exact prices, road times, permit rules, or safety guarantees if the context does not provide them.
- If information is uncertain, say it clearly and suggest confirming with local hosts, guides, transport counters, or local authorities.
- Keep answers practical and useful for tourists.
- Use short paragraphs and bullet points when helpful.
- Mention emergency numbers only for safety or emergency questions:
  Police 100, Ambulance 102, Tourist Police 01-4247041.
"""


class LlmChatService:
    def __init__(self) -> None:
        self._destination_repo = JsonDestinationRepository()
        self._destinations = self._destination_repo.get_all()

    async def answer(self, request: ChatRequestDto) -> ChatResponseDto:
        question = request.question.strip()

        if not question:
            raise HTTPException(
                status_code=400,
                detail="Question cannot be empty.",
            )

        if not settings.openai_api_key:
            raise HTTPException(
                status_code=503,
                detail=(
                    "OPENAI_API_KEY is not configured. Add it to backend .env."
                ),
            )

        context_destinations = self._retrieve_destinations(
            question=question,
            top_k=request.top_k,
        )

        context = self._build_context(context_destinations)

        user_input = f"""
User question:
{question}

Relevant destination context:
{context}

Answer the user using the context above when possible.
If the context is not enough, give general rural tourism guidance and clearly say what should be confirmed locally.
""".strip()

        payload = {
            "model": settings.llm_model,
            "instructions": SYSTEM_PROMPT,
            "input": user_input,
            "max_output_tokens": settings.llm_max_output_tokens,
        }

        try:
            async with httpx.AsyncClient(timeout=45.0) as client:
                response = await client.post(
                    "https://api.openai.com/v1/responses",
                    headers={
                        "Authorization": f"Bearer {settings.openai_api_key}",
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
        except httpx.TimeoutException as exc:
            raise HTTPException(
                status_code=504,
                detail="LLM request timed out.",
            ) from exc
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=502,
                detail=f"LLM connection error: {exc}",
            ) from exc

        if response.status_code < 200 or response.status_code >= 300:
            raise HTTPException(
                status_code=502,
                detail=f"LLM provider error: {response.text[:800]}",
            )

        data = response.json()
        answer = self._extract_answer(data)

        if not answer:
            raise HTTPException(
                status_code=502,
                detail="LLM returned an empty answer.",
            )

        return ChatResponseDto(
            answer=answer,
            source="llm",
            used_context=[destination.name for destination in context_destinations],
        )

    def _retrieve_destinations(
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
        }

        return {
            token
            for token in cleaned.split()
            if len(token) >= 3 and token not in stopwords
        }

    def _join_non_empty(self, values: List[str | None]) -> str:
        result = [value for value in values if value and value.strip()]
        return ", ".join(result) if result else "Unknown"

    def _extract_answer(self, data: dict) -> str:
        direct_output = data.get("output_text")
        if isinstance(direct_output, str) and direct_output.strip():
            return direct_output.strip()

        output = data.get("output")
        if not isinstance(output, list):
            return ""

        parts: List[str] = []

        for item in output:
            if not isinstance(item, dict):
                continue

            content = item.get("content")
            if not isinstance(content, list):
                continue

            for block in content:
                if not isinstance(block, dict):
                    continue

                block_type = block.get("type")
                text = block.get("text")

                if block_type == "output_text" and isinstance(text, str):
                    if text.strip():
                        parts.append(text.strip())

        return "\n".join(parts).strip()