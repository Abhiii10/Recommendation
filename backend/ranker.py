"""
Public ranker facade for backend recommendation ranking.

The implementation lives in backend.infrastructure.ml.ranker; this module keeps
the import path simple for scripts, admin tasks, and future destination updates.
"""

from backend.infrastructure.ml.ranker import (
    FEATURE_NAMES,
    RankingModel,
    build_ranker_features,
    build_training_feature_vector,
    get_ranking_model,
    rebuild_index,
)

__all__ = [
    "FEATURE_NAMES",
    "RankingModel",
    "build_ranker_features",
    "build_training_feature_vector",
    "get_ranking_model",
    "rebuild_index",
]
