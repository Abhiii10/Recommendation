"""
Feature engineering for ML ranking model.

Converts a (user preferences, destination) pair into a fixed-length
numeric vector that the GradientBoostingClassifier can train on.

Feature order must never change after training — the saved model
depends on the index positions being stable.
"""

from __future__ import annotations

from typing import Any
import numpy as np


# ── Event weights (used by synthetic_data to score interactions) ──────────────
EVENT_WEIGHTS = {
    "view":            1.0,
    "click":           2.0,
    "detail_view":     2.0,
    "save":            4.0,
    "like":            5.0,
    "rating":          5.0,
    "more_like_this":  4.0,
    "skip":           -2.0,
    "dislike":        -4.0,
    "not_interested": -5.0,
}


def list_overlap_score(a: list[str], b: list[str]) -> float:
    """Jaccard overlap between two lists, case-insensitive."""
    if not a or not b:
        return 0.0
    a_set = {str(x).lower() for x in a if x}
    b_set = {str(x).lower() for x in b if x}
    intersection = len(a_set & b_set)
    union = len(a_set | b_set)
    return intersection / union if union else 0.0


def exact_match_score(a: Any, b: Any) -> float:
    if a is None or b is None:
        return 0.0
    return 1.0 if str(a).lower() == str(b).lower() else 0.0


def level_similarity(user_level: int | None, destination_level: int | None) -> float:
    """Returns how closely two 1–5 integer levels match."""
    if user_level is None or destination_level is None:
        return 0.5
    diff = abs(int(user_level) - int(destination_level))
    return max(0.0, 1.0 - diff / 4.0)


def build_ranking_features(
    preferences: dict,
    destination: Any,
    semantic_score: float,
    user_history_score: float = 0.0,
) -> list[float]:
    """
    Returns an 11-dimensional numeric feature vector for the ranking model.
    Feature order must stay stable across all training and inference calls.
    """

    preferred_activity  = preferences.get("activity")
    preferred_budget    = preferences.get("budget")
    preferred_season    = preferences.get("season")
    preferred_vibe      = preferences.get("vibe")
    preferred_family    = preferences.get("family_friendly")
    preferred_adventure = preferences.get("adventure_level")

    activities = destination.activities or []
    categories = destination.category   or []
    seasons    = destination.best_season or []
    tags       = destination.tags        or []

    activity_score = list_overlap_score([preferred_activity], activities + tags)
    budget_score   = exact_match_score(preferred_budget, destination.budget_level)
    season_score   = list_overlap_score([preferred_season, "year-round"], seasons)
    vibe_score     = list_overlap_score(
        [preferred_vibe],
        categories + activities + tags,
    )

    if preferred_family is None:
        family_score = 0.5
    else:
        family_score = 1.0 if bool(preferred_family) == bool(destination.family_friendly) else 0.0

    adventure_score  = level_similarity(preferred_adventure, destination.adventure_level)

    popularity       = float(destination.popularity_score   or 0.0)
    rating           = float(destination.avg_rating         or 0.0) / 5.0
    interaction_score = min(float(destination.total_interactions or 0) / 100.0, 1.0)

    return [
        float(semantic_score),       # 0
        float(user_history_score),   # 1
        float(activity_score),       # 2
        float(budget_score),         # 3
        float(season_score),         # 4
        float(vibe_score),           # 5
        float(family_score),         # 6
        float(adventure_score),      # 7
        float(popularity),           # 8
        float(rating),               # 9
        float(interaction_score),    # 10
    ]


FEATURE_NAMES = [
    "semantic_score",
    "user_history_score",
    "activity_score",
    "budget_score",
    "season_score",
    "vibe_score",
    "family_score",
    "adventure_score",
    "popularity_score",
    "rating_score",
    "interaction_score",
]


def feature_vector_to_dict(features: list[float]) -> dict:
    return dict(zip(FEATURE_NAMES, features))