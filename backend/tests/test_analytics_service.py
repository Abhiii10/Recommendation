from datetime import datetime, timezone

from backend.application.services import analytics_service as analytics_module
from backend.application.services.analytics_service import AnalyticsService
from backend.core.constants import EventTypes
from backend.domain.entities.destination import Destination
from backend.domain.entities.interaction import Interaction


class FakeInteractionRepository:
    def get_all(self):
        return [
            Interaction(
                user_id="user-1",
                destination_id="dest-1",
                event_type=EventTypes.RECOMMENDATION_SHOWN,
                value=1.0,
            ),
            Interaction(
                user_id="user-2",
                destination_id="dest-1",
                event_type=EventTypes.RECOMMENDATION_SHOWN,
                value=0.5,
            ),
            Interaction(
                user_id="user-1",
                destination_id="dest-1",
                event_type=EventTypes.CLICK,
                value=1.0,
            ),
            Interaction(
                user_id="user-1",
                destination_id="dest-1",
                event_type=EventTypes.SAVE,
                value=1.0,
            ),
            Interaction(
                user_id="user-2",
                destination_id="dest-1",
                event_type=EventTypes.RATING,
                value=4.0,
            ),
        ]


class FakeDestinationRepository:
    def get_all(self):
        return [
            Destination(
                id="dest-1",
                name="Ghandruk",
                district="Kaski",
                province="Gandaki",
            )
        ]


def test_recommender_summary_computes_rates_and_top_destinations(monkeypatch):
    monkeypatch.setattr(
        analytics_module,
        "build_interaction_repository",
        lambda: FakeInteractionRepository(),
    )
    monkeypatch.setattr(
        analytics_module,
        "JsonDestinationRepository",
        lambda: FakeDestinationRepository(),
    )

    summary = AnalyticsService().recommender_summary(top_k=3)

    assert summary.total_interactions == 5
    assert summary.unique_users == 2
    assert summary.unique_destinations == 1
    assert summary.impressions == 2
    assert summary.clicks == 1
    assert summary.saves == 1
    assert summary.ratings == 1
    assert summary.click_through_rate == 0.5
    assert summary.save_rate == 0.5
    assert summary.rating_rate == 0.5

    top = summary.top_destinations[0]
    assert top.id == "dest-1"
    assert top.name == "Ghandruk"
    assert top.average_rating == 4.0
    assert top.click_through_rate == 0.5


def test_recommendation_quality_computes_online_metrics(monkeypatch):
    timestamp = datetime.now(timezone.utc).isoformat()
    recommendation_id = "rec-1"

    class QualityInteractionRepository:
        def get_all(self):
            return [
                Interaction(
                    user_id="user-1",
                    destination_id="dest-1",
                    event_type=EventTypes.RECOMMENDATION_SHOWN,
                    timestamp=timestamp,
                    recommendation_id=recommendation_id,
                    recommended_destination_ids=["dest-1", "dest-2", "dest-3"],
                    pipeline_used="online",
                ),
                Interaction(
                    user_id="user-1",
                    destination_id="dest-2",
                    event_type=EventTypes.RECOMMENDATION_SHOWN,
                    timestamp=timestamp,
                    recommendation_id=recommendation_id,
                    recommended_destination_ids=["dest-1", "dest-2", "dest-3"],
                    pipeline_used="online",
                ),
                Interaction(
                    user_id="user-1",
                    destination_id="dest-3",
                    event_type=EventTypes.RECOMMENDATION_SHOWN,
                    timestamp=timestamp,
                    recommendation_id=recommendation_id,
                    recommended_destination_ids=["dest-1", "dest-2", "dest-3"],
                    pipeline_used="online",
                ),
                Interaction(
                    user_id="user-1",
                    destination_id="dest-2",
                    event_type=EventTypes.CLICK,
                    timestamp=timestamp,
                    recommendation_id=recommendation_id,
                ),
                Interaction(
                    user_id="user-1",
                    destination_id="dest-3",
                    event_type=EventTypes.SAVE,
                    timestamp=timestamp,
                    recommendation_id=recommendation_id,
                ),
            ]

    monkeypatch.setattr(
        analytics_module,
        "build_interaction_repository",
        lambda: QualityInteractionRepository(),
    )

    quality = AnalyticsService().recommendation_quality()

    assert quality.recommendations_shown == 3
    assert quality.clicks == 1
    assert quality.saves == 1
    assert quality.click_through_rate == 0.3333
    assert quality.save_rate == 0.3333
    assert quality.average_clicked_position == 2.0
    assert quality.pipeline_breakdown == {"online": 100.0}
