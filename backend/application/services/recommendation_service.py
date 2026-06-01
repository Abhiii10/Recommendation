"""
Recommendation pipeline with ML ranker integration.

Pipeline:
  1. Build preference query
  2. Retrieve candidates using SBERT
  3. Add collaborative/popularity scores
  4. Contextual reranking
  5. ML ranker rescoring
  6. Explainable recommendation output
"""

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
from backend.infrastructure.ml.ranker import build_ranker_features, get_ranking_model
from backend.infrastructure.ml.sbert_encoder import PreferenceQueryBuilder
from backend.infrastructure.repositories.json_accommodation_repository import (
    JsonAccommodationRepository,
)
from backend.infrastructure.repositories.json_destination_repository import (
    JsonDestinationRepository,
)
from backend.infrastructure.repositories.interaction_repository_factory import (
    build_interaction_repository,
)


_COLD_START_POPULARITY_WEIGHT = 0.15
_COLD_START_COLLABORATIVE_WEIGHT = 0.0

_WARM_POPULARITY_WEIGHT = 0.15
_WARM_COLLABORATIVE_WEIGHT = 0.85


class RecommendationService:
    """
    Recommendation pipeline:
    SBERT retrieval -> collaborative/contextual reranking -> ML ranker -> explanation.
    """

    def __init__(self) -> None:
        destination_repo = JsonDestinationRepository()
        accommodation_repo = JsonAccommodationRepository()

        self._interaction_repo = build_interaction_repository()

        self._destinations = destination_repo.get_all()
        self._accommodations = accommodation_repo.get_all()
        self._destination_by_id = {d.id: d for d in self._destinations}

        self._query_builder = PreferenceQueryBuilder()
        self._retriever = CandidateRetriever(self._destinations)
        self._reranker = ContextualReranker()
        self._explainer = RecommendationExplainer()

        self._ranker = get_ranking_model()
        self._ranker.ensure_loaded()

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

        if request.semantic_only:
            return self._build_semantic_only_response(candidates, request)

        candidate_ids = [c["destination"].id for c in candidates]

        interactions = self._interaction_repo.get_all()
        collab_filter = CollaborativeFilter(interactions)

        raw_collab = collab_filter.score_candidates(
            user_id=request.user_id or "",
            candidate_ids=candidate_ids,
        )

        popularity = collab_filter.popular_destinations(candidate_ids)
        is_cold_start = self._is_cold_start(raw_collab)

        if is_cold_start:
            blended_scores = {
                cid: (
                    _COLD_START_COLLABORATIVE_WEIGHT * raw_collab.get(cid, 0.0)
                    + _COLD_START_POPULARITY_WEIGHT * popularity.get(cid, 0.0)
                )
                for cid in candidate_ids
            }
        else:
            blended_scores = {
                cid: (
                    _WARM_COLLABORATIVE_WEIGHT * raw_collab.get(cid, 0.0)
                    + _WARM_POPULARITY_WEIGHT * popularity.get(cid, 0.0)
                )
                for cid in candidate_ids
            }

        contextual_pool_k = min(
            len(candidates),
            max(request.top_k * 3, request.top_k),
        )

        ranked = self._reranker.rerank(
            candidates=candidates,
            accommodations=self._accommodations,
            collaborative_scores=blended_scores,
            activity=request.activity,
            budget=request.budget,
            season=request.season,
            vibe=request.vibe,
            family_friendly=request.family_friendly,
            adventure_level=request.adventure_level,
            top_k=contextual_pool_k,
        )

        ranked = self._apply_ml_ranking(
            ranked=ranked,
            request=request,
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
                is_cold_start=is_cold_start,
            )

            recommendation.metadata["is_cold_start"] = str(is_cold_start).lower()
            recommendation.metadata["popularity_score"] = (
                f"{popularity.get(recommendation.id, 0.0):.4f}"
            )

            items.append(self._to_dto(recommendation))

        return RecommendationResponseDto(results=items, total=len(items))

    def _apply_ml_ranking(
        self,
        ranked: list,
        request: RecommendationRequestDto,
        top_k: int,
    ) -> list:
        """
        Applies LightGBM LambdaRank when trained, otherwise uses the fixed
        semantic/collaborative/contextual fallback formula.
        """

        rescored = []

        for recommendation in ranked:
            destination = self._destination_by_id[recommendation.id]

            semantic_score = float(
                getattr(recommendation.components, "semantic", 0.0) or 0.0
            )

            user_history_score = float(
                getattr(recommendation.components, "collaborative", 0.0) or 0.0
            )

            contextual_score = self._metadata_float(
                recommendation.metadata.get("contextual_score"),
            )

            features = build_ranker_features(
                semantic_score=semantic_score,
                collaborative_score=user_history_score,
                contextual_score=contextual_score,
                popularity_score=float(destination.popularity_score or 0.0),
                activity_match=float(
                    getattr(recommendation.components, "activity_match", 0.0) or 0.0
                ),
                season_match=float(
                    getattr(recommendation.components, "season_match", 0.0) or 0.0
                ),
                budget_match=float(
                    getattr(recommendation.components, "budget_match", 0.0) or 0.0
                ),
                vibe_match=float(
                    getattr(recommendation.components, "vibe_match", 0.0) or 0.0
                ),
            )

            ml_rank_score = self._ranker.predict_score(features)

            recommendation.score = round(ml_rank_score, 4)
            recommendation.metadata["ml_rank_score"] = f"{ml_rank_score:.4f}"
            recommendation.metadata["ml_ranker_trained"] = str(
                self._ranker.is_trained
            ).lower()
            recommendation.metadata["ranker_mode"] = self._ranker.mode
            recommendation.metadata["ranker_model"] = (
                "lightgbm_lambdarank"
                if self._ranker.is_trained
                else "fixed_weight_fallback"
            )

            rescored.append(recommendation)

        rescored.sort(key=lambda item: item.score, reverse=True)
        return rescored[:top_k]

    def _build_semantic_only_response(
        self,
        candidates: list,
        request: RecommendationRequestDto,
    ) -> RecommendationResponseDto:
        sorted_candidates = sorted(
            candidates,
            key=lambda c: c.get("semantic_score", 0.0),
            reverse=True,
        )[: request.top_k]

        items = []

        for candidate in sorted_candidates:
            destination = candidate["destination"]
            score = round(float(candidate.get("semantic_score", 0.0)), 4)

            items.append(
                RecommendationResponseItemDto(
                    id=destination.id,
                    name=destination.name,
                    district=destination.district,
                    province=destination.province,
                    score=score,
                    components={"semantic": score},
                    reasons=["Semantic baseline - no reranking applied"],
                    metadata={"mode": "semantic_only"},
                )
            )

        return RecommendationResponseDto(results=items, total=len(items))

    @staticmethod
    def _to_dto(recommendation) -> RecommendationResponseItemDto:
        return RecommendationResponseItemDto(
            id=recommendation.id,
            name=recommendation.name,
            district=recommendation.district,
            province=recommendation.province,
            score=recommendation.score,
            components=recommendation.components.model_dump(),
            reasons=recommendation.reasons,
            metadata=recommendation.metadata,
        )

    @staticmethod
    def _is_cold_start(collab_scores: dict[str, float]) -> bool:
        return all(score == 0.0 for score in collab_scores.values())

    @staticmethod
    def _metadata_float(value: str | None) -> float:
        try:
            return float(value or 0.0)
        except (TypeError, ValueError):
            return 0.0
