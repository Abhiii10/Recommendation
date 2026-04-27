"""
ML ranking model.

Uses GradientBoostingClassifier — works well on small/medium datasets
and requires no extra dependencies beyond scikit-learn.

Training flow:
  1. Load all interactions from interactions.json
  2. Join with users (from users.json) and destinations (from destinations.json)
  3. Build feature vectors for each (user, destination) interaction pair
  4. Label: 1 for positive events (save, rating, click), 0 for neutral/negative
  5. Train GBC and save model to disk as ranking_model.joblib

Inference:
  - predict_score() returns a probability (0–1) that the user would positively
    interact with the destination
  - If model is not trained yet, falls back to a weighted linear score
"""

from __future__ import annotations

import logging
import os
from typing import Any

import joblib
import numpy as np
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.metrics import accuracy_score, roc_auc_score

from backend.core.config import settings
from backend.domain.entities.destination import Destination
from backend.domain.entities.interaction import Interaction
from backend.domain.entities.user import User
from backend.infrastructure.repositories.json_destination_repository import JsonDestinationRepository
from backend.infrastructure.repositories.json_interaction_repository import JsonInteractionRepository
from backend.infrastructure.repositories.json_user_repository import JsonUserRepository
from backend.infrastructure.ml.feature_builder import build_ranking_features

logger = logging.getLogger(__name__)


POSITIVE_EVENTS = {"click", "save", "rating", "detail_view"}
NEGATIVE_EVENTS: set[str] = set()   # no hard-negative events in current schema


class RankingModel:
    def __init__(self):
        self.model      = GradientBoostingClassifier(random_state=settings.RANDOM_SEED)
        self.is_trained = False

        os.makedirs(settings.MODEL_DIR, exist_ok=True)
        self.model_path = os.path.join(settings.MODEL_DIR, "ranking_model.joblib")

    # ── Persistence ───────────────────────────────────────────────────────────

    def save(self) -> None:
        joblib.dump(self.model, self.model_path)
        logger.info("Ranking model saved to %s", self.model_path)

    def load(self) -> bool:
        if not os.path.exists(self.model_path):
            return False
        self.model      = joblib.load(self.model_path)
        self.is_trained = True
        logger.info("Ranking model loaded from %s", self.model_path)
        return True

    # ── Inference ─────────────────────────────────────────────────────────────

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
        Linear weighted fallback used before the model is trained.
        Mirrors the weights used in contextual_reranker.py so cold-start
        behaviour is consistent with the existing pipeline.
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

    # ── Training ──────────────────────────────────────────────────────────────

    def train_from_storage(self) -> dict:
        """
        Trains the ranking model from data in JSON storage.
        Reads users, interactions, and destinations — no database needed.
        """
        user_repo        = JsonUserRepository()
        interaction_repo = JsonInteractionRepository()
        dest_repo        = JsonDestinationRepository()

        users        = {u.id: u for u in user_repo.get_all()}
        destinations = {d.id: d for d in dest_repo.get_all()}
        interactions = interaction_repo.get_all()

        X: list[list[float]] = []
        y: list[int]          = []

        for ix in interactions:
            user = users.get(ix.user_id)
            dest = destinations.get(ix.destination_id)

            if user is None or dest is None:
                continue

            if ix.event_type in POSITIVE_EVENTS:
                label = 1
            elif ix.event_type in NEGATIVE_EVENTS:
                label = 0
            else:
                # Treat neutral events (detail_view with low value) as negative
                label = 0 if ix.value < 2.0 else 1

            features = build_ranking_features(
                preferences=user.preferences or {},
                destination=dest,
                semantic_score=0.5,
                user_history_score=0.0,
            )
            X.append(features)
            y.append(label)

        if len(X) < 20 or len(set(y)) < 2:
            self.is_trained = False
            return {
                "trained": False,
                "samples": len(X),
                "message": (
                    "Not enough balanced interaction data to train ranking model. "
                    f"Got {len(X)} samples with {len(set(y))} unique labels. "
                    "Run /evaluate/generate-synthetic-data first."
                ),
            }

        X_arr = np.array(X)
        y_arr = np.array(y)

        self.model.fit(X_arr, y_arr)
        self.is_trained = True
        self.save()

        predictions = self.model.predict(X_arr)
        metrics = {
            "accuracy":         float(accuracy_score(y_arr, predictions)),
            "samples":          int(len(X)),
            "positive_samples": int(sum(y)),
            "negative_samples": int(len(y) - sum(y)),
        }

        try:
            probabilities    = self.model.predict_proba(X_arr)[:, 1]
            metrics["roc_auc"] = float(roc_auc_score(y_arr, probabilities))
        except Exception:
            metrics["roc_auc"] = None

        return {
            "trained": True,
            "model":   "GradientBoostingClassifier",
            "metrics": metrics,
            "message": "Ranking model trained successfully.",
        }