from __future__ import annotations
from backend.infrastructure.repositories.json_destination_repository import JsonDestinationRepository
from backend.infrastructure.ml.candidate_retriever import CandidateRetriever
from backend.application.dto.responses import SimilarResponseDto, RecommendationResponseItemDto


class SimilarDestinationService:
    def __init__(self):
        repo = JsonDestinationRepository()
        destinations = repo.get_all()
        self._retriever = CandidateRetriever(destinations)

    def get_similar(self, destination_id: str, top_k: int) -> SimilarResponseDto:
        raw = self._retriever.similar_to_destination(destination_id, top_k)
        items = [
            RecommendationResponseItemDto(
                id=r["destination"].id,
                name=r["destination"].name,
                district=r["destination"].district,
                province=r["destination"].province,
                score=round(r["semantic_score"], 4),
                components={},
                reasons=["Semantically similar destination"],
            )
            for r in raw
        ]
        return SimilarResponseDto(results=items)
