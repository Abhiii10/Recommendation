"""
Recommendation pipeline (v3 — baseline-aware).

Pipeline:
  1. Build natural-language query from preferences  (PreferenceQueryBuilder)
  2. Retrieve top-K candidates via SBERT + structured boosts (CandidateRetriever)
  3. Score candidates with item-item collaborative filtering  (CollaborativeFilter)
  4. Cold-start blend:
       Cold  → 15% popularity + 0% collab  (was 100% popularity — fixed)
       Warm  → 85% collab   + 15% popularity
  5. Contextual reranking with 7 signals + diversity  (ContextualReranker)
  6. Build explainable reasons, cold-start-aware         (RecommendationExplainer)

  semantic_only=True (evaluation baseline):
       Skip steps 3-6, return candidates sorted purely by SBERT semantic score.
       This gives a clean apples-to-apples A/B comparison in benchmark.py.
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

# ── Cold-start weights (FIXED) ────────────────────────────────────────────────
# Old values: _COLD_START_POPULARITY_WEIGHT = 1.0 caused Bandipur (the most
# interacted-with destination) to rank #1 in every query regardless of intent.
# Dropping to 0.15 makes popularity a soft tiebreaker, not a dominant signal.
_COLD_START_POPULARITY_WEIGHT    = 0.15   # was 1.0
_COLD_START_COLLABORATIVE_WEIGHT = 0.0

_WARM_POPULARITY_WEIGHT          = 0.15   # was 0.25
_WARM_COLLABORATIVE_WEIGHT       = 0.85   # was 0.75


class RecommendationService:
    """Four-step recommendation pipeline: retrieve → score → rerank → explain."""

    def __init__(self) -> None:
        destination_repo     = JsonDestinationRepository()
        accommodation_repo   = JsonAccommodationRepository()
        self._interaction_repo = JsonInteractionRepository()

        self._destinations       = destination_repo.get_all()
        self._accommodations     = accommodation_repo.get_all()
        self._destination_by_id  = {d.id: d for d in self._destinations}

        self._query_builder = PreferenceQueryBuilder()
        self._retriever     = CandidateRetriever(self._destinations)
        self._reranker      = ContextualReranker()
        self._explainer     = RecommendationExplainer()

    # ── Public ────────────────────────────────────────────────────────────────

    def recommend(self, request: RecommendationRequestDto) -> RecommendationResponseDto:

        # ── Stage 1: build query text ─────────────────────────────────────────
        query_text = self._query_builder.build(
            activity=request.activity,
            budget=request.budget,
            season=request.season,
            vibe=request.vibe,
            family_friendly=request.family_friendly,
            adventure_level=request.adventure_level,
        )

        # ── Stage 2: SBERT retrieval ──────────────────────────────────────────
        candidates = self._retriever.retrieve(
            query_text,
            top_k=settings.retrieve_top_k,
            activity=request.activity,
            vibe=request.vibe,
            season=request.season,
            budget=request.budget,
        )

        # ── Semantic-only baseline (evaluation mode) ──────────────────────────
        # Returns here — no collaborative or contextual signals applied.
        # Gives a clean SBERT-only baseline for A/B comparison in benchmark.py.
        if request.semantic_only:
            return self._build_semantic_only_response(candidates, request)

        # ── Stage 3: collaborative scoring ────────────────────────────────────
        candidate_ids  = [c["destination"].id for c in candidates]
        interactions   = self._interaction_repo.get_all()
        collab_filter  = CollaborativeFilter(interactions)

        raw_collab  = collab_filter.score_candidates(
            user_id=request.user_id or "",
            candidate_ids=candidate_ids,
        )
        popularity    = collab_filter.popular_destinations(candidate_ids)
        is_cold_start = self._is_cold_start(raw_collab)

        # ── Stage 4: cold-start blend ─────────────────────────────────────────
        if is_cold_start:
            blended_scores = {
                cid: (
                    _COLD_START_COLLABORATIVE_WEIGHT * raw_collab.get(cid, 0.0)
                    + _COLD_START_POPULARITY_WEIGHT  * popularity.get(cid, 0.0)
                )
                for cid in candidate_ids
            }
        else:
            blended_scores = {
                cid: (
                    _WARM_COLLABORATIVE_WEIGHT * raw_collab.get(cid, 0.0)
                    + _WARM_POPULARITY_WEIGHT  * popularity.get(cid, 0.0)
                )
                for cid in candidate_ids
            }

        # ── Stage 5: contextual reranking ─────────────────────────────────────
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
            top_k=request.top_k,
        )

        # ── Stage 6: explainable reasons ─────────────────────────────────────
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
            recommendation.metadata["is_cold_start"]    = str(is_cold_start).lower()
            recommendation.metadata["popularity_score"] = (
                f"{popularity.get(recommendation.id, 0.0):.4f}"
            )
            items.append(self._to_dto(recommendation))

        return RecommendationResponseDto(results=items, total=len(items))

    # ── Private helpers ───────────────────────────────────────────────────────

    def _build_semantic_only_response(
        self,
        candidates: list,
        request: RecommendationRequestDto,
    ) -> RecommendationResponseDto:
        """
        Baseline path: rank purely by SBERT semantic score, no collaborative
        or contextual signals. Used only by evaluation/benchmark.py.
        """
        sorted_candidates = sorted(
            candidates,
            key=lambda c: c.get("semantic_score", 0.0),
            reverse=True,
        )[: request.top_k]

        items = []
        for c in sorted_candidates:
            dest  = c["destination"]
            score = round(float(c.get("semantic_score", 0.0)), 4)
            items.append(
                RecommendationResponseItemDto(
                    id=dest.id,
                    name=dest.name,
                    district=dest.district,
                    province=dest.province,
                    score=score,
                    components={"semantic": score},
                    reasons=["Semantic baseline — no reranking applied"],
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