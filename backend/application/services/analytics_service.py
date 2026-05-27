from __future__ import annotations

from collections import Counter, defaultdict
from typing import Dict, List

from backend.application.dto.responses import (
    DestinationAnalyticsDto,
    InteractionEventCountDto,
    RecommenderAnalyticsDto,
)
from backend.core.constants import EventTypes
from backend.domain.entities.destination import Destination
from backend.domain.entities.interaction import Interaction
from backend.infrastructure.repositories.interaction_repository_factory import (
    build_interaction_repository,
)
from backend.infrastructure.repositories.json_destination_repository import (
    JsonDestinationRepository,
)


class AnalyticsService:
    def __init__(self) -> None:
        self._interaction_repo = build_interaction_repository()
        self._destination_repo = JsonDestinationRepository()

    def recommender_summary(self, top_k: int = 10) -> RecommenderAnalyticsDto:
        interactions = self._interaction_repo.get_all()
        destinations = self._destination_repo.get_all()
        destination_by_id = {destination.id: destination for destination in destinations}

        event_counter: Counter[str] = Counter()
        event_values: Dict[str, float] = defaultdict(float)
        destination_metrics: Dict[str, Counter[str]] = defaultdict(Counter)
        destination_rating_totals: Dict[str, float] = defaultdict(float)

        users = set()
        destination_ids = set()

        for interaction in interactions:
            event_type = interaction.event_type.strip().lower()
            users.add(interaction.user_id)
            destination_ids.add(interaction.destination_id)
            event_counter[event_type] += 1
            event_values[event_type] += float(interaction.value or 0.0)
            destination_metrics[interaction.destination_id][event_type] += 1

            if event_type == EventTypes.RATING:
                destination_rating_totals[interaction.destination_id] += float(
                    interaction.value or 0.0
                )

        impressions = event_counter[EventTypes.RECOMMENDATION_SHOWN]
        clicks = event_counter[EventTypes.CLICK]
        detail_views = event_counter[EventTypes.DETAIL_VIEW]
        saves = event_counter[EventTypes.SAVE]
        ratings = event_counter[EventTypes.RATING]

        top_destinations = self._top_destinations(
            destination_metrics=destination_metrics,
            destination_rating_totals=destination_rating_totals,
            destination_by_id=destination_by_id,
            top_k=top_k,
        )

        return RecommenderAnalyticsDto(
            total_interactions=len(interactions),
            unique_users=len(users),
            unique_destinations=len(destination_ids),
            impressions=impressions,
            clicks=clicks,
            detail_views=detail_views,
            saves=saves,
            ratings=ratings,
            click_through_rate=self._rate(clicks, impressions),
            detail_view_rate=self._rate(detail_views, impressions),
            save_rate=self._rate(saves, impressions),
            rating_rate=self._rate(ratings, impressions),
            event_counts=[
                InteractionEventCountDto(
                    event_type=event_type,
                    count=count,
                    total_value=round(event_values[event_type], 4),
                )
                for event_type, count in event_counter.most_common()
            ],
            top_destinations=top_destinations,
        )

    def _top_destinations(
        self,
        *,
        destination_metrics: Dict[str, Counter[str]],
        destination_rating_totals: Dict[str, float],
        destination_by_id: Dict[str, Destination],
        top_k: int,
    ) -> List[DestinationAnalyticsDto]:
        ranked_destination_ids = sorted(
            destination_metrics,
            key=lambda destination_id: self._engagement_score(
                destination_metrics[destination_id]
            ),
            reverse=True,
        )

        results: List[DestinationAnalyticsDto] = []

        for destination_id in ranked_destination_ids[:top_k]:
            metrics = destination_metrics[destination_id]
            destination = destination_by_id.get(destination_id)

            impressions = metrics[EventTypes.RECOMMENDATION_SHOWN]
            clicks = metrics[EventTypes.CLICK]
            saves = metrics[EventTypes.SAVE]
            ratings = metrics[EventTypes.RATING]
            average_rating = 0.0

            if ratings > 0:
                average_rating = destination_rating_totals[destination_id] / ratings

            results.append(
                DestinationAnalyticsDto(
                    id=destination_id,
                    name=destination.name if destination else destination_id,
                    district=destination.district if destination else None,
                    province=destination.province if destination else None,
                    impressions=impressions,
                    clicks=clicks,
                    detail_views=metrics[EventTypes.DETAIL_VIEW],
                    saves=saves,
                    unsaves=metrics[EventTypes.UNSAVE],
                    ratings=ratings,
                    average_rating=round(average_rating, 2),
                    click_through_rate=self._rate(clicks, impressions),
                    save_rate=self._rate(saves, impressions),
                )
            )

        return results

    def _engagement_score(self, metrics: Counter[str]) -> float:
        return (
            metrics[EventTypes.RECOMMENDATION_SHOWN] * 0.1
            + metrics[EventTypes.CLICK] * 1.0
            + metrics[EventTypes.DETAIL_VIEW] * 1.5
            + metrics[EventTypes.SAVE] * 3.0
            + metrics[EventTypes.RATING] * 3.5
            - metrics[EventTypes.UNSAVE] * 1.5
        )

    def _rate(self, numerator: int, denominator: int) -> float:
        if denominator <= 0:
            return 0.0

        return round(numerator / denominator, 4)
