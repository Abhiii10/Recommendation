"""
Synthetic user and interaction generation.

Used because the app is not publicly deployed and has no real user data yet.
Generates synthetic user profiles and simulated interactions so the ML
ranking model has data to train on.

Workflow:
  1. Load all destinations from destinations.json
  2. Create N synthetic User objects with random preferences
  3. For each user, sample destinations and assign pseudo-relevance labels
  4. Convert labels to realistic event types (click, save, skip, etc.)
  5. Write users to users.json and interactions to interactions.json
"""

from __future__ import annotations

import random
import uuid
from datetime import datetime, timezone
from typing import Any

from backend.core.config import settings
from backend.domain.entities.destination import Destination
from backend.domain.entities.interaction import Interaction
from backend.domain.entities.user import User
from backend.infrastructure.repositories.json_destination_repository import JsonDestinationRepository
from backend.infrastructure.repositories.json_interaction_repository import JsonInteractionRepository
from backend.infrastructure.repositories.json_user_repository import JsonUserRepository
from backend.infrastructure.ml.feature_builder import build_ranking_features


ACTIVITIES = [
    "trekking",
    "hiking",
    "culture",
    "village",
    "nature",
    "homestay",
    "wildlife",
    "photography",
    "spiritual",
    "adventure",
    "pilgrimage",
    "relaxation",
]

BUDGETS  = ["budget", "medium", "premium"]
SEASONS  = ["spring", "summer", "autumn", "winter", "year-round"]
VIBES    = ["nature", "cultural", "adventure", "peaceful", "rural", "spiritual"]


def generate_preference() -> dict:
    return {
        "activity":       random.choice(ACTIVITIES),
        "budget":         random.choice(BUDGETS),
        "season":         random.choice(SEASONS),
        "vibe":           random.choice(VIBES),
        "family_friendly": random.choice([True, False, None]),
        "adventure_level": random.randint(1, 5),
    }


def synthetic_relevance_label(preferences: dict, destination: Any) -> int:
    """
    Computes a pseudo-relevance label (0 or 1) based on how well the
    destination matches the user preferences.

    Uses a weighted combination of feature scores plus Gaussian noise
    to simulate realistic, slightly noisy user behaviour.
    """
    features = build_ranking_features(
        preferences=preferences,
        destination=destination,
        semantic_score=0.5,
        user_history_score=0.0,
    )

    score = (
        0.20 * features[2] +  # activity
        0.15 * features[3] +  # budget
        0.15 * features[4] +  # season
        0.15 * features[5] +  # vibe
        0.10 * features[6] +  # family
        0.10 * features[7] +  # adventure
        0.10 * features[8] +  # popularity
        0.05 * features[9]    # rating
    )

    noise = random.uniform(-0.15, 0.15)
    return 1 if score + noise >= 0.45 else 0


def event_from_label(label: int) -> str:
    """Picks a realistic event type based on whether the destination was relevant."""
    if label == 1:
        return random.choices(
            ["click", "save", "rating", "detail_view"],
            weights=[3, 2, 1, 3],
        )[0]
    return random.choices(
        ["detail_view", "detail_view"],   # only neutral — no negative events in your schema
        weights=[1, 1],
    )[0]


def generate_synthetic_interactions(
    n_users: int = 100,
    interactions_per_user: int = 15,
) -> dict:
    """
    Main entry point.
    Creates synthetic users and their interactions, persisting both to JSON.

    Returns a summary dict compatible with the /evaluate/generate-synthetic-data
    API response.
    """
    dest_repo        = JsonDestinationRepository()
    interaction_repo = JsonInteractionRepository()
    user_repo        = JsonUserRepository()

    destinations = dest_repo.get_all()

    if not destinations:
        return {
            "users_created": 0,
            "interactions_created": 0,
            "message": "No destinations found. Load destination data first.",
        }

    # ── Create synthetic users ────────────────────────────────────────────────
    users: list[User] = []
    for i in range(n_users):
        user = User(
            id=f"synthetic_{uuid.uuid4().hex[:10]}",
            username=f"synthetic_user_{i}_{uuid.uuid4().hex[:5]}",
            email=None,
            is_synthetic=True,
            preferences=generate_preference(),
        )
        users.append(user)

    user_repo.add_many(users)

    # ── Generate interactions ─────────────────────────────────────────────────
    new_interactions: list[Interaction] = []
    now_iso = datetime.now(timezone.utc).isoformat()

    for user in users:
        sampled = random.sample(
            destinations,
            k=min(interactions_per_user, len(destinations)),
        )

        for dest in sampled:
            label      = synthetic_relevance_label(user.preferences, dest)
            event_type = event_from_label(label)

            # For rating events, pick a score that reflects relevance
            value = 1.0
            if event_type == "rating":
                value = random.choice([4.0, 4.5, 5.0]) if label == 1 else random.choice([1.0, 2.0, 2.5])

            interaction = Interaction(
                user_id=user.id,
                destination_id=dest.id,
                event_type=event_type,
                value=value,
                timestamp=now_iso,
            )
            new_interactions.append(interaction)

    for ix in new_interactions:
        interaction_repo.add(ix)

    return {
        "users_created": len(users),
        "interactions_created": len(new_interactions),
        "message": "Synthetic users and interactions generated successfully.",
    }