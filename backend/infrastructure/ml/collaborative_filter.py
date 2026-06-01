from __future__ import annotations
from collections import defaultdict
from typing import Dict, List, Optional, Set

from backend.core.constants import EventTypes
from backend.domain.entities.interaction import Interaction
from backend.two_tower import get_two_tower_scorer


class InteractionWeightStrategy:
    _WEIGHTS = {
        EventTypes.RECOMMENDATION_SHOWN: 0.0,
        EventTypes.CLICK:       1.5,
        EventTypes.DETAIL_VIEW: 2.0,
        EventTypes.SAVE:        4.0,
        EventTypes.RATING:      5.0,
        EventTypes.MORE_LIKE_THIS: 4.0,
        EventTypes.UNSAVE: 0.0,
        EventTypes.SKIP: 0.0,
        EventTypes.DISLIKE: 0.0,
        EventTypes.NOT_INTERESTED: 0.0,
        EventTypes.SEARCH: 0.0,
        EventTypes.CHAT_USED: 0.0,
    }

    def weight(self, event_type: str) -> float:
        return self._WEIGHTS.get(event_type, 0.0)


class CollaborativeFilter:
    """
    Lightweight item-item collaborative filter using weighted Jaccard
    similarity over interaction co-occurrence.

    For a user who has interacted with items S, the collaborative score
    for a candidate item c is:
        sum_{s in S} Jaccard(users(c), users(s))

    UPGRADED: The old version called _user_item_matrix() and _item_user_sets()
    inside score_candidates() on every recommendation request. This meant
    looping over ALL interactions from scratch every single time a user pressed
    "Generate Recommendations".

    The fix: build and cache the matrix once in __init__. Since
    RecommendationService creates a new CollaborativeFilter per request (it
    calls JsonInteractionRepository().get_all() fresh), the cache is always
    up-to-date without needing explicit invalidation.
    """

    def __init__(self, interactions: List[Interaction]):
        self._interactions = interactions
        self._strategy = InteractionWeightStrategy()

        # Build once at construction — not per score_candidates() call
        self._matrix: Dict[str, Dict[str, float]] = self._build_user_item_matrix()
        self._item_users: Dict[str, Set[str]] = self._build_item_user_sets(self._matrix)
        self._interaction_counts: Dict[str, int] = self._build_interaction_counts()

    # ── private ────────────────────────────────────────────────────────────────

    def _build_user_item_matrix(self) -> Dict[str, Dict[str, float]]:
        matrix: Dict[str, Dict[str, float]] = defaultdict(lambda: defaultdict(float))
        for ix in self._interactions:
            w = self._strategy.weight(ix.event_type)
            if w <= 0.0:
                continue
            matrix[ix.user_id][ix.destination_id] += w * ix.value
        return matrix

    def _build_item_user_sets(
        self, matrix: Dict[str, Dict[str, float]]
    ) -> Dict[str, Set[str]]:
        item_users: Dict[str, Set[str]] = defaultdict(set)
        for uid, items in matrix.items():
            for iid in items:
                item_users[iid].add(uid)
        return item_users

    def _build_interaction_counts(self) -> Dict[str, int]:
        counts: Dict[str, int] = defaultdict(int)
        for ix in self._interactions:
            if self._strategy.weight(ix.event_type) > 0.0:
                counts[ix.user_id] += 1
        return counts

    # ── public ─────────────────────────────────────────────────────────────────

    def score_candidates(
        self, user_id: str, candidate_ids: List[str]
    ) -> Dict[str, float]:
        """
        Returns normalised [0, 1] collaborative scores for each candidate.

        Cold-start: if the user has no recorded interactions, all scores are 0.0.
        The reranker blends collaborative at 0 weight in this case gracefully.
        """
        basic_scores = self._basic_score_candidates(
            user_id=user_id,
            candidate_ids=candidate_ids,
        )

        if not user_id:
            return basic_scores

        two_tower_scores = get_two_tower_scorer().score_candidates(
            user_id=user_id,
            candidate_ids=candidate_ids,
            user_interaction_count=self._interaction_counts.get(user_id, 0),
        )

        if two_tower_scores is None:
            return basic_scores

        return {
            cid: (
                0.7 * two_tower_scores.get(cid, 0.0)
                + 0.3 * basic_scores.get(cid, 0.0)
            )
            for cid in candidate_ids
        }

    def _basic_score_candidates(
        self,
        user_id: str,
        candidate_ids: List[str],
    ) -> Dict[str, float]:
        if not user_id:
            return {cid: 0.0 for cid in candidate_ids}

        # Use cached matrix — no rebuild
        user_items = self._matrix.get(user_id, {})
        if not user_items:
            return {cid: 0.0 for cid in candidate_ids}

        scores: Dict[str, float] = {}

        for cid in candidate_ids:
            total = 0.0
            uc = self._item_users.get(cid, set())
            for seen_id in user_items:
                us = self._item_users.get(seen_id, set())
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

    def popular_destinations(
        self, candidate_ids: List[str], top_k: Optional[int] = None
    ) -> Dict[str, float]:
        """
        Popularity fallback: score candidates by total weighted interaction count
        across ALL users. Useful as secondary signal for cold-start users.
        Returns normalised [0, 1] scores.
        """
        raw: Dict[str, float] = {}
        candidate_set = set(candidate_ids)
        for items in self._matrix.values():
            for iid, score in items.items():
                if iid in candidate_set:
                    raw[iid] = raw.get(iid, 0.0) + score

        for cid in candidate_ids:
            raw.setdefault(cid, 0.0)

        max_s = max(raw.values()) if raw else 1.0
        if max_s > 0:
            raw = {k: v / max_s for k, v in raw.items()}

        return raw
