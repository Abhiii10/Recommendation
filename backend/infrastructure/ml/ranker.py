"""
ML ranking model.

Trains a learning-based ranker from JSON interaction data.

Important:
- Positive events: click, save, rating
- Negative events: skip, dislike, not_interested
- detail_view is treated as neutral/weak and converted using value
"""

from __future__ import annotations

import logging
import os

import joblib
import numpy as np
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.metrics import accuracy_score, roc_auc_score

from backend.core.config import settings
from backend.core.constants import EventTypes
from backend.infrastructure.repositories.json_destination_repository import JsonDestinationRepository
from backend.infrastructure.repositories.interaction_repository_factory import (
    build_interaction_repository,
)
from backend.infrastructure.repositories.json_user_repository import JsonUserRepository
from backend.infrastructure.ml.feature_builder import build_ranking_features

logger = logging.getLogger(__name__)


POSITIVE_EVENTS = {
    EventTypes.CLICK,
    EventTypes.SAVE,
    EventTypes.RATING,
    EventTypes.MORE_LIKE_THIS,
}
NEGATIVE_EVENTS = {
    EventTypes.SKIP,
    EventTypes.DISLIKE,
    EventTypes.NOT_INTERESTED,
    EventTypes.UNSAVE,
}


class RankingModel:
    def __init__(self):
        self.model = GradientBoostingClassifier(random_state=settings.RANDOM_SEED)
        self.is_trained = False

        os.makedirs(settings.MODEL_DIR, exist_ok=True)
        self.model_path = os.path.join(settings.MODEL_DIR, "ranking_model.joblib")

    def save(self) -> None:
        joblib.dump(self.model, self.model_path)
        logger.info("Ranking model saved to %s", self.model_path)

    def load(self) -> bool:
        if not os.path.exists(self.model_path):
            return False

        self.model = joblib.load(self.model_path)
        self.is_trained = True
        logger.info("Ranking model loaded from %s", self.model_path)
        return True

    def predict_score(self, features: list[float]) -> float:
        if not self.is_trained:
            return self.fallback_score(features)

        arr = np.array(features).reshape(1, -1)

        try:
            return float(self.model.predict_proba(arr)[0][1])
        except Exception:
            return self.fallback_score(features)

    @staticmethod
    def fallback_score(features: list[float]) -> float:
        """
        Fallback score used before the ML model is trained.
        """

        return float(
            0.35 * features[0] +   # semantic_score
            0.10 * features[1] +   # user_history_score
            0.15 * features[2] +   # activity_score
            0.10 * features[3] +   # budget_score
            0.10 * features[4] +   # season_score
            0.10 * features[5] +   # vibe_score
            0.05 * features[8] +   # popularity_score
            0.05 * features[9]     # rating_score
        )

    def _label_interaction(self, interaction) -> int | None:
        """
        Converts an interaction into a training label.

        Returns:
            1    positive
            0    negative
            None ignore sample
        """

        event_type = interaction.event_type

        if event_type in POSITIVE_EVENTS:
            return 1

        if event_type in NEGATIVE_EVENTS:
            return 0

        # detail_view/view are weak signals.
        # If value exists and is high, treat as positive.
        # Otherwise treat as negative/neutral.
        if event_type in {EventTypes.DETAIL_VIEW, "view"}:
            value = getattr(interaction, "value", 1.0)
            return 1 if float(value or 0.0) >= 2.0 else 0

        return None

    def train_from_storage(self) -> dict:
        """
        Trains the ranking model from JSON storage.
        """

        user_repo = JsonUserRepository()
        interaction_repo = build_interaction_repository()
        dest_repo = JsonDestinationRepository()

        users = {user.id: user for user in user_repo.get_all()}
        destinations = {dest.id: dest for dest in dest_repo.get_all()}
        interactions = interaction_repo.get_all()

        X: list[list[float]] = []
        y: list[int] = []

        skipped = 0

        for interaction in interactions:
            user = users.get(interaction.user_id)
            destination = destinations.get(interaction.destination_id)

            if user is None or destination is None:
                skipped += 1
                continue

            label = self._label_interaction(interaction)

            if label is None:
                skipped += 1
                continue

            features = build_ranking_features(
                preferences=user.preferences or {},
                destination=destination,
                semantic_score=0.5,
                user_history_score=0.0,
            )

            X.append(features)
            y.append(label)

        positive_count = int(sum(y))
        negative_count = int(len(y) - positive_count)

        if len(X) < 20 or len(set(y)) < 2:
            self.is_trained = False

            return {
                "trained": False,
                "samples": len(X),
                "positive_samples": positive_count,
                "negative_samples": negative_count,
                "skipped_samples": skipped,
                "message": (
                    "Not enough balanced interaction data to train ranking model. "
                    "Run /api/v1/evaluate/generate-synthetic-data first."
                ),
            }

        X_arr = np.array(X)
        y_arr = np.array(y)

        self.model.fit(X_arr, y_arr)
        self.is_trained = True
        self.save()

        predictions = self.model.predict(X_arr)

        metrics = {
            "accuracy": float(accuracy_score(y_arr, predictions)),
            "samples": int(len(X)),
            "positive_samples": positive_count,
            "negative_samples": negative_count,
            "skipped_samples": skipped,
        }

        try:
            probabilities = self.model.predict_proba(X_arr)[:, 1]
            metrics["roc_auc"] = float(roc_auc_score(y_arr, probabilities))
        except Exception:
            metrics["roc_auc"] = None

        return {
            "trained": True,
            "model": "GradientBoostingClassifier",
            "metrics": metrics,
            "message": "Ranking model trained successfully.",
        }
