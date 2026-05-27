from __future__ import annotations

from typing import List

import numpy as np
from fastapi import HTTPException

from backend.application.dto.requests import ChatRequestDto
from backend.application.dto.responses import ChatResponseDto
from backend.domain.entities.destination import Destination
from backend.infrastructure.ml.sbert_encoder import DestinationTextBuilder, SbertEncoder
from backend.infrastructure.repositories.json_destination_repository import (
    JsonDestinationRepository,
)


class OfflineChatService:
    def __init__(self) -> None:
        self._destination_repo = JsonDestinationRepository()
        self._destinations = self._destination_repo.get_all()
        self._encoder = SbertEncoder()
        self._text_builder = DestinationTextBuilder()

        if self._destinations:
            texts = [
                self._text_builder.build(destination)
                for destination in self._destinations
            ]
            self._matrix: np.ndarray = self._encoder.encode_texts(texts)
        else:
            self._matrix = np.empty((0, 0), dtype=np.float32)

    async def answer(self, request: ChatRequestDto) -> ChatResponseDto:
        question = request.question.strip()

        if not question:
            raise HTTPException(
                status_code=400,
                detail="Question cannot be empty.",
            )

        if not self._destinations:
            return ChatResponseDto(
                answer=(
                    "Namaste! I could not find any destination data to search right "
                    "now. Please add destinations and try again."
                ),
                source="offline_fallback",
                used_context=[],
            )

        query_vector = self._encoder.encode_text(question)
        scores = self._matrix @ query_vector
        ranked_indices = np.argsort(scores)[::-1][:3]
        top_destinations = [self._destinations[index] for index in ranked_indices]

        answer = self._build_answer(top_destinations)

        return ChatResponseDto(
            answer=answer,
            source="offline_rag",
            used_context=[destination.name for destination in top_destinations],
        )

    def _build_answer(self, destinations: List[Destination]) -> str:
        blocks: List[str] = [
            "Namaste! Here are a few rural tourism destinations that may fit your question:"
        ]

        for destination in destinations:
            blocks.append(
                "\n".join(
                    [
                        f"{destination.name}",
                        f"Location: {self._join_non_empty([destination.municipality, destination.district, destination.province])}",
                        f"About: {destination.short_description or 'Details are limited for this destination.'}",
                        f"Budget level: {destination.budget_level or 'Unknown'}",
                        f"Best season: {self._join_values(destination.best_season)}",
                        f"Activities: {self._join_values(destination.activities[:3])}",
                    ]
                )
            )

        blocks.append("For personalised ranking, use the Recommend tab.")
        return "\n\n".join(blocks)

    def _join_non_empty(self, values: List[str | None]) -> str:
        result = [value for value in values if value and value.strip()]
        return ", ".join(result) if result else "Unknown"

    def _join_values(self, values: List[str]) -> str:
        result = [value for value in values if value and value.strip()]
        return ", ".join(result) if result else "Unknown"
