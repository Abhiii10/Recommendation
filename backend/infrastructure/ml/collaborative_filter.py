from __future__ import annotations
from collections import defaultdict
from typing import Dict, List, Set

from backend.core.constants import EventTypes
from backend.domain.entities.interaction import Interaction


class InteractionWeightStrategy:
    _WEIGHTS = {
        EventTypes.CLICK:       1.0,
        EventTypes.DETAIL_VIEW: 2.0,
        EventTypes.SAVE:        4.0,
        EventTypes.RATING:      5.0,
    }

    def weight(self, event_type: str) -> float:
        return self._WEIGHTS.get(event_type, 1.0)


class CollaborativeFilter:
    """
    Lightweight item-item collaborative filter using weighted Jaccard
    similarity over interaction co-occurrence.

    For a user who has interacted with items S, the collaborative score
    for a candidate item c is:
        sum_{s in S} Jaccard(users(c), users(s))
    """

    def __init__(self, interactions: List[Interaction]):
        self._interactions = interactions
        self._strategy = InteractionWeightStrategy()

    # ── private ────────────────────────────────────────────────────────────────

    def _user_item_matrix(self) -> Dict[str, Dict[str, float]]:
        matrix: Dict[str, Dict[str, float]] = defaultdict(lambda: defaultdict(float))
        for ix in self._interactions:
            w = self._strategy.weight(ix.event_type)
            matrix[ix.user_id][ix.destination_id] += w * ix.value
        return matrix

    def _item_user_sets(
        self, matrix: Dict[str, Dict[str, float]]
    ) -> Dict[str, Set[str]]:
        item_users: Dict[str, Set[str]] = defaultdict(set)
        for uid, items in matrix.items():
            for iid in items:
                item_users[iid].add(uid)
        return item_users

    # ── public ─────────────────────────────────────────────────────────────────

    def score_candidates(
        self, user_id: str, candidate_ids: List[str]
    ) -> Dict[str, float]:
        if not user_id:
            return {cid: 0.0 for cid in candidate_ids}

        matrix = self._user_item_matrix()
        user_items = matrix.get(user_id, {})
        if not user_items:
            return {cid: 0.0 for cid in candidate_ids}

        item_users = self._item_user_sets(matrix)
        scores: Dict[str, float] = {}

        for cid in candidate_ids:
            total = 0.0
            uc = item_users.get(cid, set())
            for seen_id in user_items:
                us = item_users.get(seen_id, set())
                union = len(uc | us)
                inter = len(uc & us)
                total += (inter / union) if union else 0.0
            scores[cid] = total

        # Normalise to [0, 1]
        if scores:
            max_s = max(scores.values())
            if max_s > 0:
                scores = {k: v / max_s for k, v in scores.items()}

        return scores
