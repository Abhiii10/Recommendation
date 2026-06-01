"""
LightGBM learning-to-rank model for destination recommendations.

The ranker uses LambdaRank when a trained model is available. Until enough
interaction data exists, it falls back to the fixed production formula:

    final_score = 0.50 * semantic + 0.20 * collaborative + 0.30 * contextual
"""

from __future__ import annotations

from collections import Counter, defaultdict
from functools import lru_cache
import logging
import math
from pathlib import Path
from typing import Any

import joblib
import numpy as np

from backend.core.config import settings
from backend.core.constants import BudgetOrder, EventTypes
from backend.domain.entities.destination import Destination
from backend.infrastructure.repositories.interaction_repository_factory import (
    build_interaction_repository,
)
from backend.infrastructure.repositories.json_destination_repository import (
    JsonDestinationRepository,
)
from backend.infrastructure.repositories.json_user_repository import JsonUserRepository

logger = logging.getLogger(__name__)


FEATURE_NAMES = [
    "semantic_score",
    "collaborative_score",
    "contextual_score",
    "popularity_score",
    "activity_match",
    "season_match",
    "budget_match",
    "vibe_match",
]


RELEVANCE_BY_EVENT = {
    "saved": 3,
    "book": 3,
    "booked": 3,
    "booking": 3,
    EventTypes.SAVE: 3,
    EventTypes.MORE_LIKE_THIS: 3,
    EventTypes.RATING: 3,
    "clicked": 2,
    EventTypes.CLICK: 2,
    "view": 1,
    "viewed": 1,
    EventTypes.DETAIL_VIEW: 1,
    EventTypes.RECOMMENDATION_SHOWN: 1,
    "skipped": 0,
    EventTypes.SKIP: 0,
    EventTypes.DISLIKE: 0,
    EventTypes.NOT_INTERESTED: 0,
    EventTypes.UNSAVE: 0,
}


def build_ranker_features(
    *,
    semantic_score: float,
    collaborative_score: float,
    contextual_score: float,
    popularity_score: float,
    activity_match: float,
    season_match: float,
    budget_match: float,
    vibe_match: float,
) -> list[float]:
    """
    Builds the stable 8-feature vector used by the LambdaRank model.
    """

    return [
        _clamp(semantic_score),
        _clamp(collaborative_score),
        _clamp(contextual_score),
        _clamp(popularity_score),
        _clamp(activity_match),
        _clamp(season_match),
        _clamp(budget_match),
        _clamp(vibe_match),
    ]


def build_training_feature_vector(
    preferences: dict[str, Any],
    destination: Destination,
    *,
    semantic_score: float = 0.5,
    collaborative_score: float = 0.0,
) -> list[float]:
    """
    Builds ranker features from a user preference profile and a destination.

    This is used by offline evaluation and by admin model training where the
    complete recommendation request context is not available.
    """

    activity_match = _activity_match(preferences, destination)
    season_match = _season_match(preferences, destination)
    budget_match = _budget_match(preferences, destination)
    vibe_match = _vibe_match(preferences, destination)

    contextual_score = _clamp(
        0.30 * activity_match
        + 0.25 * vibe_match
        + 0.25 * season_match
        + 0.20 * budget_match
    )

    return build_ranker_features(
        semantic_score=semantic_score,
        collaborative_score=collaborative_score,
        contextual_score=contextual_score,
        popularity_score=float(destination.popularity_score or 0.0),
        activity_match=activity_match,
        season_match=season_match,
        budget_match=budget_match,
        vibe_match=vibe_match,
    )


class RankingModel:
    """
    LightGBM LambdaRank wrapper with a deterministic fixed-weight fallback.
    """

    def __init__(self, model_path: Path | None = None) -> None:
        self.model = None
        self.is_trained = False
        self.mode = "fallback"
        self._load_attempted = False

        self.model_path = model_path or Path(settings.MODEL_DIR) / "ranker.pkl"
        self.model_path.parent.mkdir(parents=True, exist_ok=True)

    def ensure_loaded(self) -> bool:
        if self._load_attempted:
            return self.is_trained
        return self.load()

    def save(self) -> None:
        if self.model is None:
            raise RuntimeError("Cannot save ranker before a model is trained.")

        joblib.dump(
            {
                "model": self.model,
                "feature_names": FEATURE_NAMES,
                "objective": "lambdarank",
            },
            self.model_path,
        )
        logger.info("LightGBM ranker saved to %s", self.model_path)

    def load(self) -> bool:
        self._load_attempted = True

        if not self.model_path.exists():
            self.model = None
            self.is_trained = False
            self.mode = "fallback"
            logger.info(
                "Recommendation ranker active mode: fallback "
                "(no model found at %s)",
                self.model_path,
            )
            return False

        try:
            payload = joblib.load(self.model_path)
            if isinstance(payload, dict):
                self.model = payload.get("model")
            else:
                self.model = payload

            if self.model is None:
                raise ValueError("Loaded ranker payload does not contain a model.")

            self.is_trained = True
            self.mode = "learned"
            logger.info(
                "Recommendation ranker active mode: learned "
                "(LightGBM LambdaRank loaded from %s)",
                self.model_path,
            )
            return True
        except Exception as exc:
            self.model = None
            self.is_trained = False
            self.mode = "fallback"
            logger.warning(
                "Could not load LightGBM ranker from %s; using fallback formula: %s",
                self.model_path,
                exc,
            )
            return False

    def predict_score(self, features: list[float]) -> float:
        normalized_features = _normalize_feature_length(features)

        if not self.is_trained or self.model is None:
            return self.fallback_score(normalized_features)

        try:
            arr = np.array([normalized_features], dtype=np.float32)
            raw_score = float(self.model.predict(arr)[0])
            return _sigmoid(raw_score)
        except Exception as exc:
            logger.warning("LightGBM prediction failed; using fallback score: %s", exc)
            return self.fallback_score(normalized_features)

    @staticmethod
    def fallback_score(features: list[float]) -> float:
        """
        Fixed scoring formula used until a LambdaRank model is trained.
        """

        normalized_features = _normalize_feature_length(features)
        semantic_score = normalized_features[0]
        collaborative_score = normalized_features[1]
        contextual_score = normalized_features[2]

        return _clamp(
            0.50 * semantic_score
            + 0.20 * collaborative_score
            + 0.30 * contextual_score
        )

    def train_from_storage(self) -> dict[str, Any]:
        """
        Trains LambdaRank from stored user interaction data.
        """

        try:
            from lightgbm import LGBMRanker
        except ImportError as exc:
            self.model = None
            self.is_trained = False
            self.mode = "fallback"
            return {
                "trained": False,
                "mode": self.mode,
                "model": "LightGBM LGBMRanker",
                "message": (
                    "lightgbm is not installed. Install backend requirements "
                    "before training the ranker."
                ),
                "error": str(exc),
            }

        user_repo = JsonUserRepository()
        interaction_repo = build_interaction_repository()
        destination_repo = JsonDestinationRepository()

        users = {user.id: user for user in user_repo.get_all()}
        destinations = {dest.id: dest for dest in destination_repo.get_all()}
        interactions = interaction_repo.get_all()

        samples_by_user: dict[str, list[tuple[list[float], int]]] = defaultdict(list)
        label_counts: Counter[int] = Counter()
        skipped = 0

        for interaction in interactions:
            destination = destinations.get(interaction.destination_id)
            if destination is None:
                skipped += 1
                continue

            relevance = self._relevance_label(interaction)
            if relevance is None:
                skipped += 1
                continue

            user = users.get(interaction.user_id)
            preferences = user.preferences if user is not None else {}
            features = build_training_feature_vector(
                preferences=preferences or {},
                destination=destination,
                semantic_score=0.5,
                collaborative_score=0.0,
            )

            samples_by_user[interaction.user_id].append((features, relevance))
            label_counts[relevance] += 1

        X: list[list[float]] = []
        y: list[int] = []
        groups: list[int] = []

        for samples in samples_by_user.values():
            if len(samples) < 2:
                skipped += len(samples)
                continue

            groups.append(len(samples))
            for features, relevance in samples:
                X.append(features)
                y.append(relevance)

        if len(X) < 20 or len(groups) < 2 or len(set(y)) < 2:
            self.model = None
            self.is_trained = False
            self.mode = "fallback"
            logger.info(
                "Recommendation ranker active mode: fallback "
                "(not enough interaction data for LambdaRank training)"
            )
            return {
                "trained": False,
                "mode": self.mode,
                "model": "LightGBM LGBMRanker",
                "objective": "lambdarank",
                "samples": len(X),
                "groups": len(groups),
                "label_counts": dict(label_counts),
                "skipped_samples": skipped,
                "message": (
                    "Not enough grouped interaction data to train LambdaRank. "
                    "Need at least 20 samples, 2 user groups, and 2 relevance labels."
                ),
            }

        model = LGBMRanker(
            objective="lambdarank",
            metric="ndcg",
            n_estimators=120,
            learning_rate=0.05,
            num_leaves=15,
            random_state=settings.RANDOM_SEED,
            verbosity=-1,
        )

        X_arr = np.array(X, dtype=np.float32)
        y_arr = np.array(y, dtype=np.int32)

        model.fit(X_arr, y_arr, group=groups)

        self.model = model
        self.is_trained = True
        self.mode = "learned"
        self.save()

        logger.info(
            "Recommendation ranker active mode: learned "
            "(trained LightGBM LambdaRank on %s samples across %s groups)",
            len(X),
            len(groups),
        )

        return {
            "trained": True,
            "mode": self.mode,
            "model": "LightGBM LGBMRanker",
            "objective": "lambdarank",
            "samples": len(X),
            "groups": len(groups),
            "label_counts": dict(label_counts),
            "skipped_samples": skipped,
            "feature_names": FEATURE_NAMES,
            "model_path": str(self.model_path),
            "message": "LightGBM LambdaRank model trained successfully.",
        }

    def rebuild_index(self) -> dict[str, Any]:
        """
        Rebuilds the learned ranking model after destination or interaction updates.
        """

        return self.train_from_storage()

    def _relevance_label(self, interaction: Any) -> int | None:
        event_type = str(getattr(interaction, "event_type", "")).lower()

        if event_type == EventTypes.RATING:
            value = float(getattr(interaction, "value", 0.0) or 0.0)
            if value >= 4.0:
                return 3
            if value >= 2.5:
                return 2
            if value > 0:
                return 1
            return 0

        return RELEVANCE_BY_EVENT.get(event_type)


@lru_cache(maxsize=1)
def get_ranking_model() -> RankingModel:
    return RankingModel()


def rebuild_index() -> dict[str, Any]:
    """
    Retrains the cached ranker. Call this after destination or interaction updates.
    """

    return get_ranking_model().rebuild_index()


def _normalize_feature_length(features: list[float]) -> list[float]:
    if len(features) == len(FEATURE_NAMES):
        return [_clamp(value) for value in features]

    if len(features) >= 11:
        return build_ranker_features(
            semantic_score=features[0],
            collaborative_score=features[1],
            contextual_score=_clamp(
                0.30 * features[2]
                + 0.25 * features[5]
                + 0.25 * features[4]
                + 0.20 * features[3]
            ),
            popularity_score=features[8],
            activity_match=features[2],
            season_match=features[4],
            budget_match=features[3],
            vibe_match=features[5],
        )

    padded = [float(value) for value in features[: len(FEATURE_NAMES)]]
    padded.extend([0.0] * (len(FEATURE_NAMES) - len(padded)))
    return [_clamp(value) for value in padded]


def _activity_match(preferences: dict[str, Any], destination: Destination) -> float:
    preferred_activity = preferences.get("activity")
    if not preferred_activity:
        return 0.5

    destination_terms = _terms(destination.activities, destination.tags, destination.category)
    query_terms = _query_terms(preferred_activity)
    return _term_match(query_terms, destination_terms)


def _season_match(preferences: dict[str, Any], destination: Destination) -> float:
    preferred_season = str(preferences.get("season") or "").strip().lower()
    if not preferred_season:
        return 0.5

    seasons = _terms(destination.best_season)
    if preferred_season in seasons or "year-round" in seasons:
        return 1.0

    return 0.0


def _budget_match(preferences: dict[str, Any], destination: Destination) -> float:
    preferred_budget = str(preferences.get("budget") or "").strip().lower()
    actual_budget = str(destination.budget_level or "").strip().lower()

    if not preferred_budget:
        return 0.5

    if preferred_budget == actual_budget:
        return 1.0

    if preferred_budget in BudgetOrder.ORDER and actual_budget in BudgetOrder.ORDER:
        distance = abs(
            BudgetOrder.ORDER.index(preferred_budget)
            - BudgetOrder.ORDER.index(actual_budget)
        )
        return 0.65 if distance == 1 else 0.0

    return 0.0


def _vibe_match(preferences: dict[str, Any], destination: Destination) -> float:
    preferred_vibe = preferences.get("vibe")
    if not preferred_vibe:
        return 0.5

    destination_terms = _terms(destination.category, destination.activities, destination.tags)
    query_terms = _query_terms(preferred_vibe)
    return _term_match(query_terms, destination_terms)


def _term_match(query_terms: set[str], destination_terms: set[str]) -> float:
    if query_terms.intersection(destination_terms):
        return 1.0

    if any(
        query in term or term in query
        for query in query_terms
        for term in destination_terms
    ):
        return 0.6

    return 0.0


def _query_terms(value: Any) -> set[str]:
    normalized = str(value or "").strip().lower()
    if not normalized:
        return set()

    aliases = {
        "culture": {"culture", "cultural", "heritage", "historic"},
        "cultural": {"culture", "cultural", "heritage", "historic"},
        "trekking": {"trekking", "trek", "hiking", "trail", "adventure"},
        "hiking": {"trekking", "trek", "hiking", "trail"},
        "nature": {"nature", "scenic", "wildlife", "forest", "outdoors"},
        "peaceful": {"peaceful", "quiet", "relaxation", "retreat"},
        "spiritual": {"spiritual", "pilgrimage", "temple", "shrine"},
        "adventure": {"adventure", "trekking", "rafting", "hiking"},
    }

    return {normalized, *aliases.get(normalized, set())}


def _terms(*groups: list[str]) -> set[str]:
    return {
        str(term).strip().lower()
        for group in groups
        for term in (group or [])
        if str(term).strip()
    }


def _sigmoid(value: float) -> float:
    try:
        return _clamp(1.0 / (1.0 + math.exp(-value)))
    except OverflowError:
        return 0.0 if value < 0 else 1.0


def _clamp(value: float) -> float:
    return max(0.0, min(1.0, float(value or 0.0)))
