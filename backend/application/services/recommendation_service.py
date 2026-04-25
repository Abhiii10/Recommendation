from __future__ import annotations

from backend.application.dto.requests import RecommendationRequestDto
from backend.application.dto.responses import (
    RecommendationResponseDto,
    RecommendationResponseItemDto,
)
from backend.core.config import settings
from backend.infrastructure.explain.recommendation_explainer import RecommendationExplainer
from backend.infrastructure.ml.candidate_retriever import CandidateRetriever
from backend.infrastructure.ml.collaborative_filter import CollaborativeFilter
from backend.infrastructure.ml.contextual_reranker import ContextualReranker
from backend.infrastructure.ml.sbert_encoder import PreferenceQueryBuilder
from backend.infrastructure.repositories.json_accommodation_repository import (
    JsonAccommodationRepository,
)
from backend.infrastructure.repositories.json_destination_repository import (
    JsonDestinationRepository,
)
from backend.infrastructure.repositories.json_interaction_repository import (
    JsonInteractionRepository,
)


class RecommendationService:
    """
    Existing recommendation service upgraded to a consistent four-step pipeline:
    retrieve -> score -> rerank -> explain.
    """

    def __init__(self):
        destination_repo = JsonDestinationRepository()
        accommodation_repo = JsonAccommodationRepository()
        self._interaction_repo = JsonInteractionRepository()

        self._destinations = destination_repo.get_all()
        self._accommodations = accommodation_repo.get_all()
        self._destination_by_id = {destination.id: destination for destination in self._destinations}

        self._query_builder = PreferenceQueryBuilder()
        self._retriever = CandidateRetriever(self._destinations)
        self._reranker = ContextualReranker()
        self._explainer = RecommendationExplainer()

    def recommend(self, request: RecommendationRequestDto) -> RecommendationResponseDto:
        query_text = self._query_builder.build(
            activity=request.activity,
            budget=request.budget,
            season=request.season,
            vibe=request.vibe,
            family_friendly=request.family_friendly,
            adventure_level=request.adventure_level,
        )

        candidates = self._retriever.retrieve(
            query_text,
            top_k=settings.retrieve_top_k,
            activity=request.activity,
            vibe=request.vibe,
            season=request.season,
            budget=request.budget,
        )

        interactions = self._interaction_repo.get_all()
        collaborative_filter = CollaborativeFilter(interactions)
        collaborative_scores = collaborative_filter.score_candidates(
            user_id=request.user_id or "",
            candidate_ids=[candidate["destination"].id for candidate in candidates],
        )

        ranked = self._reranker.rerank(
            candidates=candidates,
            accommodations=self._accommodations,
            collaborative_scores=collaborative_scores,
            activity=request.activity,
            budget=request.budget,
            season=request.season,
            vibe=request.vibe,
            family_friendly=request.family_friendly,
            adventure_level=request.adventure_level,
            top_k=request.top_k,
        )

        items = []
        for recommendation in ranked:
            destination = self._destination_by_id[recommendation.id]
            recommendation.reasons = self._explainer.build(
                recommendation=recommendation,
                destination=destination,
                activity=request.activity,
                budget=request.budget,
                season=request.season,
                vibe=request.vibe,
                family_friendly=request.family_friendly,
            )
            items.append(
                RecommendationResponseItemDto(
                    id=recommendation.id,
                    name=recommendation.name,
                    district=recommendation.district,
                    province=recommendation.province,
                    score=recommendation.score,
                    components=recommendation.components.model_dump(),
                    reasons=recommendation.reasons,
                    metadata=recommendation.metadata,
                )
            )

        return RecommendationResponseDto(results=items, total=len(items))
