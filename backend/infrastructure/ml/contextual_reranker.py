from __future__ import annotations

from typing import Dict, List, Optional, Set

from backend.core.config import settings
from backend.core.constants import AccessibilityScores, BudgetOrder
from backend.domain.entities.accommodation import Accommodation
from backend.domain.entities.destination import Destination
from backend.domain.entities.recommendation import Recommendation, RecommendationComponents


class TextNormalizer:
    def normalize(self, value: Optional[str]) -> str:
        return value.strip().lower() if value else ""


class ContextualReranker:
    """
    Combines normalized semantic, collaborative, and contextual signals into a
    final score and then applies simple diversity constraints.
    """

    def __init__(self):
        self._norm = TextNormalizer()

    def rerank(
        self,
        candidates: List[Dict],
        accommodations: List[Accommodation],
        collaborative_scores: Dict[str, float],
        activity: str,
        budget: str,
        season: str,
        vibe: str,
        family_friendly: Optional[bool],
        adventure_level: Optional[int],
        top_k: int,
    ) -> List[Recommendation]:
        results: List[Recommendation] = []

        for item in candidates:
            destination: Destination = item["destination"]
            semantic_score = self._clamp(item.get("semantic_score", 0.0))
            collaborative_score = self._clamp(collaborative_scores.get(destination.id, 0.0))

            activity_match = self._activity_match(destination, activity)
            vibe_match = self._vibe_match(destination, vibe)
            season_match = self._season_match(destination, season)
            budget_match = self._budget_match(destination, budget)
            accessibility_fit = self._accessibility_fit(destination)
            family_fit = self._family_fit(destination, family_friendly)
            accommodation_fit = self._accommodation_fit(destination, accommodations, budget)

            contextual_score = self._clamp(
                activity_match * settings.activity_weight
                + vibe_match * settings.vibe_weight
                + season_match * settings.season_weight
                + budget_match * settings.budget_weight
                + accessibility_fit * settings.accessibility_weight
                + family_fit * settings.family_weight
                + accommodation_fit * settings.accommodation_weight
            )

            final_score = self._clamp(
                semantic_score * settings.semantic_weight
                + collaborative_score * settings.collaborative_weight
                + contextual_score * settings.contextual_weight
            )

            results.append(
                Recommendation(
                    id=destination.id,
                    name=destination.name,
                    district=destination.district,
                    province=destination.province,
                    score=round(final_score, 4),
                    components=RecommendationComponents(
                        semantic=round(semantic_score, 4),
                        collaborative=round(collaborative_score, 4),
                        activity_match=round(activity_match, 4),
                        vibe_match=round(vibe_match, 4),
                        season_match=round(season_match, 4),
                        budget_match=round(budget_match, 4),
                        accessibility_fit=round(accessibility_fit, 4),
                        family_fit=round(family_fit, 4),
                        accommodation_fit=round(accommodation_fit, 4),
                    ),
                    reasons=[],
                    metadata={
                        "district": destination.district or "",
                        "province": destination.province or "",
                        "budget_level": destination.budget_level or "",
                        "accessibility": destination.accessibility or "",
                        "primary_category": self._primary_category(destination),
                        "contextual_score": f"{contextual_score:.4f}",
                        "retrieval_score": f"{item.get('retrieval_score', 0.0):.4f}",
                    },
                )
            )

        results.sort(key=lambda recommendation: recommendation.score, reverse=True)
        return self._apply_diversity(results, top_k=top_k)

    def _all_terms(self, destination: Destination) -> Set[str]:
        return {
            self._norm.normalize(term)
            for term in [*destination.activities, *destination.category, *destination.tags]
            if self._norm.normalize(term)
        }

    def _expanded_terms(self, value: str) -> Set[str]:
        query = self._norm.normalize(value)
        if not query:
            return set()

        alias_map = {
            "trekking": {"hiking", "trail", "trek"},
            "hiking": {"trekking", "trail", "trek"},
            "culture": {"cultural", "heritage", "traditional"},
            "cultural": {"culture", "heritage", "traditional"},
            "photography": {"viewpoint", "scenic", "panorama"},
            "boating": {"lake", "waterside"},
            "pilgrimage": {"spiritual", "temple", "heritage"},
            "relaxation": {"quiet", "peaceful", "retreat"},
            "peaceful": {"quiet", "relaxation", "retreat"},
            "nature": {"wildlife", "outdoors", "scenic"},
            "historic": {"heritage", "cultural"},
        }

        return {query, *alias_map.get(query, set())}

    def _activity_match(self, destination: Destination, activity: str) -> float:
        if not activity:
            return 0.5

        terms = self._all_terms(destination)
        query_terms = self._expanded_terms(activity)
        if query_terms.intersection(terms):
            return 1.0
        if any(any(query in term or term in query for term in terms) for query in query_terms):
            return 0.6
        return 0.0

    def _vibe_match(self, destination: Destination, vibe: str) -> float:
        if not vibe:
            return 0.5

        terms = self._all_terms(destination)
        query_terms = self._expanded_terms(vibe)
        if query_terms.intersection(terms):
            return 1.0
        if any(any(query in term or term in query for term in terms) for query in query_terms):
            return 0.55
        return 0.0

    def _season_match(self, destination: Destination, season: str) -> float:
        seasons = {self._norm.normalize(item) for item in destination.best_season}
        query = self._norm.normalize(season)
        if not query:
            return 0.5
        if query in seasons or "year-round" in seasons:
            return 1.0
        return 0.0

    def _budget_match(self, destination: Destination, budget: str) -> float:
        actual = self._norm.normalize(destination.budget_level)
        preferred = self._norm.normalize(budget)
        if not preferred:
            return 0.5
        if actual == preferred:
            return 1.0

        order = BudgetOrder.ORDER
        if actual in order and preferred in order:
            distance = abs(order.index(actual) - order.index(preferred))
            return 0.65 if distance == 1 else 0.0
        return 0.0

    def _accessibility_fit(self, destination: Destination) -> float:
        key = self._norm.normalize(destination.accessibility)
        return self._clamp(AccessibilityScores.MAP.get(key, 0.5))

    def _family_fit(self, destination: Destination, family_friendly: Optional[bool]) -> float:
        if family_friendly is None:
            return 0.5
        if family_friendly and destination.family_friendly:
            return 1.0
        if family_friendly and not destination.family_friendly:
            return 0.0
        return 0.55

    def _accommodation_fit(
        self,
        destination: Destination,
        accommodations: List[Accommodation],
        budget: str,
    ) -> float:
        stays = [stay for stay in accommodations if stay.destination_id == destination.id]
        if not stays:
            return 0.35

        preferred_budget = self._norm.normalize(budget)
        best_score = 0.45

        for stay in stays:
            stay_budget = self._norm.normalize(stay.price_range)
            if preferred_budget and stay_budget == preferred_budget:
                best_score = max(best_score, 1.0)
            elif stay_budget:
                best_score = max(best_score, 0.7)
            else:
                best_score = max(best_score, 0.45)

        return best_score

    def _primary_category(self, destination: Destination) -> str:
        if not destination.category:
            return "destination"
        return self._norm.normalize(destination.category[0]) or "destination"

    def _apply_diversity(
        self,
        ranked: List[Recommendation],
        *,
        top_k: int,
    ) -> List[Recommendation]:
        district_counts: Dict[str, int] = {}
        category_counts: Dict[str, int] = {}
        diversified: List[Recommendation] = []

        for recommendation in ranked:
            if len(diversified) >= top_k:
                break

            district = self._norm.normalize(recommendation.district) or "unknown"
            category = recommendation.metadata.get("primary_category", "destination")

            district_count = district_counts.get(district, 0)
            category_count = category_counts.get(category, 0)

            if district_count >= settings.max_results_per_district:
                continue
            if category_count >= settings.max_results_per_category:
                continue

            district_counts[district] = district_count + 1
            category_counts[category] = category_count + 1
            diversified.append(recommendation)

        if len(diversified) < top_k:
            chosen_ids = {recommendation.id for recommendation in diversified}
            for recommendation in ranked:
                if len(diversified) >= top_k:
                    break
                if recommendation.id not in chosen_ids:
                    diversified.append(recommendation)

        return diversified[:top_k]

    def _clamp(self, value: float) -> float:
        return max(0.0, min(1.0, float(value)))
