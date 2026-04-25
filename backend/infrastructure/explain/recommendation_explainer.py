from __future__ import annotations

from typing import List, Optional

from backend.core.config import settings
from backend.domain.entities.destination import Destination
from backend.domain.entities.recommendation import Recommendation


class RecommendationExplainer:
    """Builds short, factor-aware explanations from weighted score contributions."""

    def build(
        self,
        recommendation: Recommendation,
        destination: Destination,
        activity: str,
        budget: str,
        season: str,
        vibe: str,
        family_friendly: Optional[bool],
    ) -> List[str]:
        weighted_factors = [
            (
                recommendation.components.semantic * settings.semantic_weight,
                self._semantic_reason(activity=activity, vibe=vibe, destination=destination),
            ),
            (
                recommendation.components.collaborative * settings.collaborative_weight,
                "Aligned with traveler behavior similar to yours",
            ),
            (
                recommendation.components.activity_match
                * settings.contextual_weight
                * settings.activity_weight,
                self._activity_reason(activity),
            ),
            (
                recommendation.components.vibe_match
                * settings.contextual_weight
                * settings.vibe_weight,
                self._vibe_reason(vibe),
            ),
            (
                recommendation.components.season_match
                * settings.contextual_weight
                * settings.season_weight,
                self._season_reason(season),
            ),
            (
                recommendation.components.budget_match
                * settings.contextual_weight
                * settings.budget_weight,
                self._budget_reason(budget),
            ),
            (
                recommendation.components.accessibility_fit
                * settings.contextual_weight
                * settings.accessibility_weight,
                self._accessibility_reason(destination),
            ),
            (
                recommendation.components.family_fit
                * settings.contextual_weight
                * settings.family_weight,
                self._family_reason(family_friendly),
            ),
            (
                recommendation.components.accommodation_fit
                * settings.contextual_weight
                * settings.accommodation_weight,
                "Accommodation options support this trip well",
            ),
        ]

        active_factors = [
            (score, message)
            for score, message in weighted_factors
            if score > 0.0 and message
        ]
        total = sum(score for score, _ in active_factors)

        if total <= 0:
            return ["Strong overall fit across your travel profile"]

        active_factors.sort(key=lambda item: item[0], reverse=True)
        reasons: List[str] = []

        for score, message in active_factors[:3]:
            percentage = round((score / total) * 100)
            reasons.append(f"{message} ({percentage}%)")

        return reasons

    def _semantic_reason(
        self,
        *,
        activity: str,
        vibe: str,
        destination: Destination,
    ) -> str:
        if activity:
            return f"Strong semantic match for your {activity.lower()} travel style"
        if vibe:
            return f"Strong semantic match for a {vibe.lower()} trip"
        return f"Strong semantic match to {destination.name}"

    def _activity_reason(self, activity: str) -> str:
        return (
            f"Matches your activity preference for {activity.lower()}"
            if activity
            else "Matches your activity preferences"
        )

    def _vibe_reason(self, vibe: str) -> str:
        return (
            f"Matches your preferred {vibe.lower()} vibe"
            if vibe
            else "Matches your preferred vibe"
        )

    def _season_reason(self, season: str) -> str:
        return (
            f"Best season match for {season.lower()}"
            if season
            else "Good seasonal fit"
        )

    def _budget_reason(self, budget: str) -> str:
        return f"Fits your {budget.lower()} budget" if budget else "Fits your budget"

    def _accessibility_reason(self, destination: Destination) -> str:
        if destination.accessibility:
            return f"Accessibility fit is strong ({destination.accessibility.lower()})"
        return "Accessibility fit is strong"

    def _family_reason(self, family_friendly: Optional[bool]) -> str:
        if family_friendly:
            return "Family friendly for the kind of trip you selected"
        return "Flexible for mixed traveler groups"
