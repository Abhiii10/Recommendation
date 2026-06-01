from __future__ import annotations

from functools import lru_cache
import json
import logging
import random
from pathlib import Path
from typing import Any, Iterable

from backend.core.config import settings
from backend.core.constants import EventTypes

try:
    import torch
    from torch import nn
    from torch.nn import functional as F
except ImportError:  # pragma: no cover - exercised only when torch is absent
    torch = None
    nn = None
    F = None


logger = logging.getLogger(__name__)

MODEL_PATH = Path(settings.MODEL_DIR) / "two_tower.pt"
EMBEDDING_DIM = 64
HIDDEN_DIM = 128
OUTPUT_DIM = 64
DEFAULT_EPOCHS = 20
MIN_TWO_TOWER_INTERACTIONS = 5

POSITIVE_EVENTS = {
    EventTypes.SAVE,
    EventTypes.CLICK,
    "saved",
    "clicked",
}


if nn is not None:

    class UserTower(nn.Module):
        def __init__(
            self,
            num_users: int,
            embedding_dim: int = EMBEDDING_DIM,
            hidden_dim: int = HIDDEN_DIM,
            output_dim: int = OUTPUT_DIM,
        ) -> None:
            super().__init__()
            self.embedding = nn.Embedding(num_users, embedding_dim)
            self.layers = nn.Sequential(
                nn.Linear(embedding_dim, hidden_dim),
                nn.ReLU(),
                nn.Linear(hidden_dim, output_dim),
            )

        def forward(self, user_ids):
            return self.layers(self.embedding(user_ids))


    class ItemTower(nn.Module):
        def __init__(
            self,
            num_items: int,
            embedding_dim: int = EMBEDDING_DIM,
            hidden_dim: int = HIDDEN_DIM,
            output_dim: int = OUTPUT_DIM,
        ) -> None:
            super().__init__()
            self.embedding = nn.Embedding(num_items, embedding_dim)
            self.layers = nn.Sequential(
                nn.Linear(embedding_dim, hidden_dim),
                nn.ReLU(),
                nn.Linear(hidden_dim, output_dim),
            )

        def forward(self, item_ids):
            return self.layers(self.embedding(item_ids))


    class TwoTowerModel(nn.Module):
        def __init__(
            self,
            num_users: int,
            num_items: int,
            embedding_dim: int = EMBEDDING_DIM,
            hidden_dim: int = HIDDEN_DIM,
            output_dim: int = OUTPUT_DIM,
        ) -> None:
            super().__init__()
            self.user_tower = UserTower(
                num_users,
                embedding_dim=embedding_dim,
                hidden_dim=hidden_dim,
                output_dim=output_dim,
            )
            self.item_tower = ItemTower(
                num_items,
                embedding_dim=embedding_dim,
                hidden_dim=hidden_dim,
                output_dim=output_dim,
            )

        def forward(self, user_ids, item_ids):
            user_vector = F.normalize(self.user_tower(user_ids), p=2, dim=-1)
            item_vector = F.normalize(self.item_tower(item_ids), p=2, dim=-1)
            return (user_vector * item_vector).sum(dim=-1)

else:

    class UserTower:  # type: ignore[no-redef]
        pass


    class ItemTower:  # type: ignore[no-redef]
        pass


    class TwoTowerModel:  # type: ignore[no-redef]
        pass


class TwoTowerScorer:
    def __init__(self, model_path: Path | None = None) -> None:
        self.model_path = model_path or MODEL_PATH
        self.model = None
        self.user_to_idx: dict[str, int] = {}
        self.item_to_idx: dict[str, int] = {}
        self._loaded = False

    @property
    def is_available(self) -> bool:
        self.ensure_loaded()
        return self.model is not None

    def ensure_loaded(self) -> bool:
        if self._loaded:
            return self.model is not None

        self._loaded = True

        if torch is None:
            logger.info("Two-tower CF disabled because torch is not installed.")
            return False

        if not self.model_path.exists():
            logger.info("Two-tower CF model not found at %s; using basic CF.", self.model_path)
            return False

        try:
            checkpoint = torch.load(
                self.model_path,
                map_location="cpu",
                weights_only=False,
            )
            self.user_to_idx = {
                str(user_id): int(index)
                for user_id, index in checkpoint["user_to_idx"].items()
            }
            self.item_to_idx = {
                str(item_id): int(index)
                for item_id, index in checkpoint["item_to_idx"].items()
            }

            self.model = TwoTowerModel(
                num_users=len(self.user_to_idx),
                num_items=len(self.item_to_idx),
                embedding_dim=int(checkpoint.get("embedding_dim", EMBEDDING_DIM)),
                hidden_dim=int(checkpoint.get("hidden_dim", HIDDEN_DIM)),
                output_dim=int(checkpoint.get("output_dim", OUTPUT_DIM)),
            )
            self.model.load_state_dict(checkpoint["state_dict"])
            self.model.eval()

            logger.info("Two-tower CF model loaded from %s", self.model_path)
            return True
        except Exception as exc:
            self.model = None
            self.user_to_idx = {}
            self.item_to_idx = {}
            logger.warning("Two-tower CF model load failed; using basic CF: %s", exc)
            return False

    def score_candidates(
        self,
        *,
        user_id: str,
        candidate_ids: list[str],
        user_interaction_count: int,
    ) -> dict[str, float] | None:
        if user_interaction_count < MIN_TWO_TOWER_INTERACTIONS:
            return None

        if not self.ensure_loaded() or self.model is None or torch is None:
            return None

        user_index = self.user_to_idx.get(user_id)
        if user_index is None:
            return None

        known_candidates = [
            candidate_id
            for candidate_id in candidate_ids
            if candidate_id in self.item_to_idx
        ]

        if not known_candidates:
            return None

        try:
            with torch.no_grad():
                user_tensor = torch.tensor(
                    [user_index] * len(known_candidates),
                    dtype=torch.long,
                )
                item_tensor = torch.tensor(
                    [self.item_to_idx[candidate_id] for candidate_id in known_candidates],
                    dtype=torch.long,
                )
                raw_scores = self.model(user_tensor, item_tensor)
                probabilities = torch.sigmoid(raw_scores).tolist()

            scores = {candidate_id: 0.0 for candidate_id in candidate_ids}
            for candidate_id, score in zip(known_candidates, probabilities):
                scores[candidate_id] = _clamp(float(score))

            return scores
        except Exception as exc:
            logger.warning("Two-tower CF scoring failed; using basic CF: %s", exc)
            return None


@lru_cache(maxsize=1)
def get_two_tower_scorer() -> TwoTowerScorer:
    return TwoTowerScorer()


def train_two_tower(
    *,
    epochs: int = DEFAULT_EPOCHS,
    model_path: Path | None = None,
    seed: int | None = None,
) -> dict[str, Any]:
    if torch is None or nn is None:
        return {
            "trained": False,
            "message": "torch is not installed. Install CPU torch before training.",
        }

    from backend.infrastructure.repositories.interaction_repository_factory import (
        build_interaction_repository,
    )
    from backend.infrastructure.repositories.json_destination_repository import (
        JsonDestinationRepository,
    )

    random_seed = settings.RANDOM_SEED if seed is None else seed
    random.seed(random_seed)
    torch.manual_seed(random_seed)

    interactions = build_interaction_repository().get_all()
    destinations = JsonDestinationRepository().get_all()
    destination_ids = sorted({destination.id for destination in destinations})

    triples = _build_training_triples(interactions, destination_ids)

    if not triples:
        return {
            "trained": False,
            "message": "No positive interaction pairs found for two-tower training.",
            "epochs": epochs,
        }

    users = sorted({user_id for user_id, _, _ in triples})
    items = sorted(destination_ids)
    user_to_idx = {user_id: index for index, user_id in enumerate(users)}
    item_to_idx = {item_id: index for index, item_id in enumerate(items)}

    model = TwoTowerModel(
        num_users=len(user_to_idx),
        num_items=len(item_to_idx),
        embedding_dim=EMBEDDING_DIM,
        hidden_dim=HIDDEN_DIM,
        output_dim=OUTPUT_DIM,
    )
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)

    indexed_triples = [
        (
            user_to_idx[user_id],
            item_to_idx[positive_id],
            item_to_idx[negative_id],
        )
        for user_id, positive_id, negative_id in triples
        if positive_id in item_to_idx and negative_id in item_to_idx
    ]

    if not indexed_triples:
        return {
            "trained": False,
            "message": "No trainable positive/negative item pairs found.",
            "epochs": epochs,
        }

    last_loss = 0.0

    for _ in range(epochs):
        random.shuffle(indexed_triples)
        epoch_losses: list[float] = []

        for batch in _batches(indexed_triples, batch_size=256):
            user_ids = torch.tensor([row[0] for row in batch], dtype=torch.long)
            positive_ids = torch.tensor([row[1] for row in batch], dtype=torch.long)
            negative_ids = torch.tensor([row[2] for row in batch], dtype=torch.long)

            positive_scores = model(user_ids, positive_ids)
            negative_scores = model(user_ids, negative_ids)
            loss = -F.logsigmoid(positive_scores - negative_scores).mean()

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            epoch_losses.append(float(loss.detach().item()))

        if epoch_losses:
            last_loss = sum(epoch_losses) / len(epoch_losses)

    output_path = model_path or MODEL_PATH
    output_path.parent.mkdir(parents=True, exist_ok=True)
    torch.save(
        {
            "state_dict": model.state_dict(),
            "user_to_idx": user_to_idx,
            "item_to_idx": item_to_idx,
            "embedding_dim": EMBEDDING_DIM,
            "hidden_dim": HIDDEN_DIM,
            "output_dim": OUTPUT_DIM,
            "epochs": epochs,
            "loss": last_loss,
        },
        output_path,
    )
    get_two_tower_scorer.cache_clear()

    return {
        "trained": True,
        "model_path": str(output_path),
        "epochs": epochs,
        "loss": round(last_loss, 6),
        "users": len(user_to_idx),
        "items": len(item_to_idx),
        "training_pairs": len(indexed_triples),
    }


def _build_training_triples(
    interactions: Iterable[Any],
    destination_ids: list[str],
) -> list[tuple[str, str, str]]:
    all_items = set(destination_ids)
    positive_by_user: dict[str, set[str]] = {}
    visited_by_user: dict[str, set[str]] = {}

    for interaction in interactions:
        user_id = str(getattr(interaction, "user_id", "") or "")
        destination_id = str(getattr(interaction, "destination_id", "") or "")
        event_type = str(getattr(interaction, "event_type", "") or "").lower()

        if not user_id or not destination_id:
            continue

        visited_by_user.setdefault(user_id, set()).add(destination_id)

        if event_type in POSITIVE_EVENTS:
            positive_by_user.setdefault(user_id, set()).add(destination_id)

    triples: list[tuple[str, str, str]] = []
    for user_id, positive_items in positive_by_user.items():
        negative_pool = list(all_items - visited_by_user.get(user_id, set()))
        if not negative_pool:
            continue

        for positive_id in positive_items:
            negative_id = random.choice(negative_pool)
            triples.append((user_id, positive_id, negative_id))

    return triples


def _batches(items: list[tuple[int, int, int]], batch_size: int):
    for start in range(0, len(items), batch_size):
        yield items[start:start + batch_size]


def _clamp(value: float) -> float:
    return max(0.0, min(1.0, float(value or 0.0)))


if __name__ == "__main__":
    result = train_two_tower()
    print(json.dumps(result, indent=2))
