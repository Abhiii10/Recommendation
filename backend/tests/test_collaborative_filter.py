from backend.core.constants import EventTypes
from backend.domain.entities.interaction import Interaction
from backend.infrastructure.ml.collaborative_filter import CollaborativeFilter


def test_neutral_impressions_do_not_boost_collaborative_or_popularity_scores():
    recommender = CollaborativeFilter(
        [
            Interaction(
                user_id="user-1",
                destination_id="dest-neutral",
                event_type=EventTypes.RECOMMENDATION_SHOWN,
                value=1.0,
            ),
            Interaction(
                user_id="user-2",
                destination_id="dest-positive",
                event_type=EventTypes.CLICK,
                value=1.0,
            ),
        ]
    )

    collaborative_scores = recommender.score_candidates(
        user_id="user-1",
        candidate_ids=["dest-positive"],
    )
    popularity_scores = recommender.popular_destinations(
        candidate_ids=["dest-neutral", "dest-positive"],
    )

    assert collaborative_scores["dest-positive"] == 0.0
    assert popularity_scores["dest-neutral"] == 0.0
    assert popularity_scores["dest-positive"] == 1.0
