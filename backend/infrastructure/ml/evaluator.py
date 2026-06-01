"""
Offline recommender evaluation.

Evaluates the full recommendation pipeline against synthetic users
using standard IR metrics: Precision@K, Recall@K, nDCG@K,
Catalog Coverage, Diversity, and Novelty.

How it works:
  1. Load synthetic users from users.json
  2. Load all destinations from destinations.json
  3. For each user, compute which destinations are "relevant" using
     synthetic_relevance_label() — the same function used during training
  4. Score all destinations using the ML ranker (or fallback if untrained)
  5. Compare top-K recommended against the relevant set
  6. Average metrics across all users
"""

from __future__ import annotations

import math
from typing import Any

import numpy as np

from backend.domain.entities.destination import Destination
from backend.infrastructure.repositories.json_destination_repository import JsonDestinationRepository
from backend.infrastructure.repositories.json_user_repository import JsonUserRepository
from backend.infrastructure.ml.synthetic_data import synthetic_relevance_label
from backend.infrastructure.ml.ranker import (
    build_training_feature_vector,
    get_ranking_model,
)


# ── Individual metric functions ───────────────────────────────────────────────

def precision_at_k(recommended: list[str], relevant: set[str], k: int) -> float:
    if not recommended:
        return 0.0
    top_k = recommended[:k]
    hits  = sum(1 for item in top_k if item in relevant)
    return hits / len(top_k)


def recall_at_k(recommended: list[str], relevant: set[str], k: int) -> float:
    if not relevant:
        return 0.0
    top_k = recommended[:k]
    hits  = sum(1 for item in top_k if item in relevant)
    return hits / len(relevant)


def ndcg_at_k(recommended: list[str], relevant: set[str], k: int) -> float:
    dcg = sum(
        1.0 / math.log2(i + 2)
        for i, item in enumerate(recommended[:k])
        if item in relevant
    )
    ideal_hits = min(len(relevant), k)
    idcg = sum(1.0 / math.log2(i + 2) for i in range(ideal_hits))
    return dcg / idcg if idcg > 0 else 0.0


def catalog_coverage(all_recommendations: list[str], total_items: int) -> float:
    if total_items == 0:
        return 0.0
    return len(set(all_recommendations)) / total_items


def diversity_score(recommended_destinations: list[Any]) -> float:
    """
    Average pairwise Jaccard distance across categories + activities.
    Higher = more diverse (less repetitive) recommendations.
    """
    if len(recommended_destinations) <= 1:
        return 0.0

    signatures = []
    for dest in recommended_destinations:
        sig = set()
        sig.update(str(x).lower() for x in (dest.category or []))
        sig.update(str(x).lower() for x in (dest.activities or []))
        signatures.append(sig)

    distances = []
    for i in range(len(signatures)):
        for j in range(i + 1, len(signatures)):
            a, b = signatures[i], signatures[j]
            if not a and not b:
                distances.append(0.0)
                continue
            union        = len(a | b)
            intersection = len(a & b)
            similarity   = intersection / union if union else 0.0
            distances.append(1.0 - similarity)

    return float(np.mean(distances)) if distances else 0.0


def novelty_score(recommended_destinations: list[Any]) -> float:
    """
    Average (1 - popularity_score) across recommended destinations.
    Higher = recommending less-popular / more novel destinations.
    """
    if not recommended_destinations:
        return 0.0
    values = [
        1.0 - float(dest.popularity_score or 0.0)
        for dest in recommended_destinations
    ]
    return float(np.mean(values))


# ── Main evaluation function ──────────────────────────────────────────────────

def evaluate_recommender(
    n_users: int = 50,
    k: int = 10,
) -> dict:
    """
    Evaluates the recommender using synthetic users and pseudo-relevance labels.
    No database or async calls — reads directly from JSON storage.
    """
    user_repo = JsonUserRepository()
    dest_repo = JsonDestinationRepository()

    users        = user_repo.get_synthetic()[:n_users]
    destinations = dest_repo.get_all()

    if not users:
        return {
            "precision_at_k": 0.0,
            "recall_at_k":    0.0,
            "ndcg_at_k":      0.0,
            "coverage":       0.0,
            "diversity":      0.0,
            "novelty":        0.0,
            "n_users":        0,
            "k":              k,
            "message": (
                "No synthetic users found. "
                "Call POST /evaluate/generate-synthetic-data first."
            ),
        }

    if not destinations:
        return {
            "precision_at_k": 0.0,
            "recall_at_k":    0.0,
            "ndcg_at_k":      0.0,
            "coverage":       0.0,
            "diversity":      0.0,
            "novelty":        0.0,
            "n_users":        len(users),
            "k":              k,
            "message":        "No destinations found.",
        }

    ranker = get_ranking_model()
    ranker.ensure_loaded()   # loads saved model if available, otherwise uses fallback

    precision_values  = []
    recall_values     = []
    ndcg_values       = []
    diversity_values  = []
    novelty_values    = []
    all_recommended_ids: list[str] = []

    for user in users:
        preferences = user.preferences or {}

        # Relevant destinations for this user (pseudo ground truth)
        relevant_ids = {
            dest.id
            for dest in destinations
            if synthetic_relevance_label(preferences, dest) == 1
        }

        # Score and rank all destinations
        scored = []
        for dest in destinations:
            features = build_training_feature_vector(
                preferences=preferences,
                destination=dest,
                semantic_score=0.5,
                collaborative_score=0.0,
            )
            score = ranker.predict_score(features)
            scored.append((dest, score))

        scored.sort(key=lambda x: x[1], reverse=True)

        recommended_destinations = [item[0] for item in scored[:k]]
        recommended_ids          = [dest.id for dest in recommended_destinations]

        all_recommended_ids.extend(recommended_ids)

        precision_values.append(precision_at_k(recommended_ids, relevant_ids, k))
        recall_values.append(   recall_at_k(   recommended_ids, relevant_ids, k))
        ndcg_values.append(     ndcg_at_k(     recommended_ids, relevant_ids, k))
        diversity_values.append(diversity_score(recommended_destinations))
        novelty_values.append(  novelty_score(  recommended_destinations))

    return {
        "precision_at_k": float(np.mean(precision_values)),
        "recall_at_k":    float(np.mean(recall_values)),
        "ndcg_at_k":      float(np.mean(ndcg_values)),
        "coverage":       catalog_coverage(all_recommended_ids, len(destinations)),
        "diversity":      float(np.mean(diversity_values)),
        "novelty":        float(np.mean(novelty_values)),
        "n_users":        len(users),
        "k":              k,
    }
