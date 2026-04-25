from __future__ import annotations

from typing import Dict, Iterable, List, Set

import numpy as np

from backend.core.config import settings
from backend.domain.entities.destination import Destination
from backend.infrastructure.ml.sbert_encoder import DestinationTextBuilder, SbertEncoder


class CandidateRetriever:
    """
    Encodes destinations once at startup and retrieves candidates using a hybrid
    of semantic similarity plus lightweight structured boosts.
    """

    def __init__(self, destinations: List[Destination]):
        self.destinations = destinations
        self._encoder = SbertEncoder()
        self._text_builder = DestinationTextBuilder()

        texts = [self._text_builder.build(destination) for destination in destinations]
        self._matrix: np.ndarray = self._encoder.encode_texts(texts)
        self._id_to_idx: Dict[str, int] = {
            destination.id: index for index, destination in enumerate(destinations)
        }

    def retrieve(
        self,
        query_text: str,
        top_k: int,
        *,
        activity: str = "",
        vibe: str = "",
        season: str = "",
        budget: str = "",
    ) -> List[Dict]:
        query_vector = self._encoder.encode_text(query_text)
        semantic_scores = self._normalize_scores(self._matrix @ query_vector)
        query_terms = self._build_query_terms(
            query_text=query_text,
            activity=activity,
            vibe=vibe,
            season=season,
            budget=budget,
        )

        scored: List[Dict] = []
        for index, destination in enumerate(self.destinations):
            activity_boost = self._activity_match(destination, activity)
            category_boost = self._category_overlap(destination, query_terms)
            retrieval_score = (
                semantic_scores[index] * settings.retrieval_semantic_weight
                + activity_boost * settings.retrieval_activity_weight
                + category_boost * settings.retrieval_category_weight
            )

            scored.append(
                {
                    "destination": destination,
                    "semantic_score": round(float(semantic_scores[index]), 4),
                    "retrieval_score": round(float(retrieval_score), 4),
                }
            )

        scored.sort(key=lambda item: item["retrieval_score"], reverse=True)
        return scored[:top_k]

    def similar_to_destination(self, destination_id: str, top_k: int) -> List[Dict]:
        if destination_id not in self._id_to_idx:
            return []

        source_index = self._id_to_idx[destination_id]
        source_vector = self._matrix[source_index]
        semantic_scores = self._normalize_scores(self._matrix @ source_vector)
        ranked = np.argsort(semantic_scores)[::-1]

        results: List[Dict] = []
        for index in ranked:
            destination = self.destinations[index]
            if destination.id == destination_id:
                continue

            results.append(
                {
                    "destination": destination,
                    "semantic_score": round(float(semantic_scores[index]), 4),
                }
            )

            if len(results) >= top_k:
                break

        return results

    def get_all_embeddings(self) -> np.ndarray:
        return self._matrix

    def _normalize_scores(self, values: np.ndarray) -> np.ndarray:
        return np.clip((values + 1.0) / 2.0, 0.0, 1.0)

    def _build_query_terms(
        self,
        *,
        query_text: str,
        activity: str,
        vibe: str,
        season: str,
        budget: str,
    ) -> Set[str]:
        terms = set(self._tokenize(query_text))

        for value in (activity, vibe, season, budget):
            normalized = self._normalize(value)
            if not normalized:
                continue
            terms.add(normalized)
            terms.update(self._aliases(normalized))

        return terms

    def _activity_match(self, destination: Destination, activity: str) -> float:
        query = self._normalize(activity)
        if not query:
            return 0.0

        terms = self._all_terms(destination)
        if query in terms:
            return 1.0
        if any(query in term or term in query for term in terms):
            return 0.6
        if self._aliases(query).intersection(terms):
            return 0.75
        return 0.0

    def _category_overlap(self, destination: Destination, query_terms: Set[str]) -> float:
        if not query_terms:
            return 0.0

        category_terms = {
            self._normalize(term)
            for term in [*destination.category, *destination.tags]
            if self._normalize(term)
        }
        if not category_terms:
            return 0.0

        matches = 0
        for query_term in query_terms:
            expanded = {query_term, *self._aliases(query_term)}
            if expanded.intersection(category_terms):
                matches += 1

        return min(1.0, matches / max(1, min(len(query_terms), 4)))

    def _all_terms(self, destination: Destination) -> Set[str]:
        return {
            self._normalize(term)
            for term in [*destination.activities, *destination.category, *destination.tags]
            if self._normalize(term)
        }

    def _aliases(self, value: str) -> Set[str]:
        alias_map = {
            "trekking": {"hiking", "trail", "trek"},
            "hiking": {"trekking", "trail", "trek"},
            "culture": {"cultural", "heritage", "traditional"},
            "cultural": {"culture", "heritage", "traditional"},
            "photography": {"viewpoint", "scenic", "panorama"},
            "boating": {"lake", "waterside"},
            "pilgrimage": {"spiritual", "temple", "heritage"},
            "relaxation": {"quiet", "peaceful", "retreat"},
            "peaceful": {"quiet", "relaxation", "retreat"},
            "scenic": {"viewpoint", "photography", "panorama"},
            "historic": {"heritage", "cultural"},
            "nature": {"wildlife", "scenic", "outdoors"},
            "social": {"community", "family"},
        }
        return alias_map.get(value, set())

    def _tokenize(self, value: str) -> Iterable[str]:
        return [
            token
            for token in "".join(
                character if character.isalnum() or character.isspace() else " "
                for character in value.lower()
            ).split()
            if token
        ]

    def _normalize(self, value: str | None) -> str:
        return value.strip().lower() if value else ""
