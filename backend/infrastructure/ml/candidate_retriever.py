from __future__ import annotations

from dataclasses import dataclass
import threading
from typing import Dict, Iterable, List, Set
import weakref

import faiss
import numpy as np

from backend.core.config import settings
from backend.domain.entities.destination import Destination
from backend.infrastructure.ml.sbert_encoder import DestinationTextBuilder, SbertEncoder


_FAISS_RETRIEVAL_POOL_SIZE = 500


@dataclass(frozen=True)
class _FaissIndexCache:
    signature: tuple[str, ...]
    matrix: np.ndarray
    index: faiss.IndexFlatIP
    id_to_idx: Dict[str, int]


class CandidateRetriever:
    """
    Encodes destinations once at startup and retrieves candidates using a hybrid
    of semantic similarity plus lightweight structured boosts.
    """

    _cache: _FaissIndexCache | None = None
    _cache_lock = threading.Lock()
    _instances: "weakref.WeakSet[CandidateRetriever]" = weakref.WeakSet()

    def __init__(self, destinations: List[Destination]):
        self.destinations = destinations
        self._encoder = SbertEncoder()
        self._text_builder = DestinationTextBuilder()

        cache = self._ensure_index(destinations)
        self._matrix = cache.matrix
        self._index = cache.index
        self._id_to_idx = cache.id_to_idx
        self.__class__._instances.add(self)

    def rebuild_index(self, destinations: List[Destination] | None = None) -> None:
        """
        Rebuilds the in-memory FAISS index after destination data changes.

        Call this after adding, removing, or editing destinations so future
        retrievals search the latest SBERT embedding matrix.
        """

        if destinations is not None:
            self.destinations = destinations

        cache = self._ensure_index(self.destinations, force=True)
        self._matrix = cache.matrix
        self._index = cache.index
        self._id_to_idx = cache.id_to_idx

    def _ensure_index(
        self,
        destinations: List[Destination],
        *,
        force: bool = False,
    ) -> _FaissIndexCache:
        signature = tuple(destination.id for destination in destinations)

        with self._cache_lock:
            if (
                not force
                and self.__class__._cache is not None
                and self.__class__._cache.signature == signature
            ):
                return self.__class__._cache

            cache = self._build_faiss_index(destinations, signature)
            self.__class__._cache = cache
            return cache

    def _build_faiss_index(
        self,
        destinations: List[Destination],
        signature: tuple[str, ...],
    ) -> _FaissIndexCache:
        texts = [self._text_builder.build(destination) for destination in destinations]
        matrix = self._encoder.encode_texts(texts).astype("float32")
        matrix = np.ascontiguousarray(matrix)
        faiss.normalize_L2(matrix)

        faiss_index = faiss.IndexFlatIP(matrix.shape[1])
        faiss_index.add(matrix)

        id_to_idx = {
            destination.id: idx for idx, destination in enumerate(destinations)
        }
        return _FaissIndexCache(
            signature=signature,
            matrix=matrix,
            index=faiss_index,
            id_to_idx=id_to_idx,
        )

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
        if not self.destinations:
            return []

        query_vector = self._query_matrix(query_text)
        search_k = min(
            len(self.destinations),
            max(top_k, _FAISS_RETRIEVAL_POOL_SIZE),
        )
        similarities, indices = self._index.search(query_vector, search_k)
        query_terms = self._build_query_terms(
            query_text=query_text,
            activity=activity,
            vibe=vibe,
            season=season,
            budget=budget,
        )

        scored: List[Dict] = []
        for raw_score, index in zip(similarities[0], indices[0]):
            if index < 0:
                continue

            destination = self.destinations[int(index)]
            semantic_score = self._normalize_score(float(raw_score))
            activity_boost = self._activity_match(destination, activity)
            category_boost = self._category_overlap(destination, query_terms)
            retrieval_score = (
                semantic_score * settings.retrieval_semantic_weight
                + activity_boost * settings.retrieval_activity_weight
                + category_boost * settings.retrieval_category_weight
            )

            scored.append(
                {
                    "destination": destination,
                    "semantic_score": round(semantic_score, 4),
                    "retrieval_score": round(float(retrieval_score), 4),
                }
            )

        scored.sort(key=lambda item: item["retrieval_score"], reverse=True)
        return scored[:top_k]

    def similar_to_destination(self, destination_id: str, top_k: int) -> List[Dict]:
        if destination_id not in self._id_to_idx:
            return []

        source_index = self._id_to_idx[destination_id]
        source_vector = self._matrix[source_index].reshape(1, -1).astype("float32")
        source_vector = np.ascontiguousarray(source_vector)
        faiss.normalize_L2(source_vector)
        search_k = min(len(self.destinations), top_k + 1)
        similarities, indices = self._index.search(source_vector, search_k)

        results: List[Dict] = []
        for raw_score, index in zip(similarities[0], indices[0]):
            if index < 0:
                continue

            destination = self.destinations[int(index)]
            if destination.id == destination_id:
                continue

            results.append(
                {
                    "destination": destination,
                    "semantic_score": round(self._normalize_score(float(raw_score)), 4),
                }
            )

            if len(results) >= top_k:
                break

        return results

    def get_all_embeddings(self) -> np.ndarray:
        return self._matrix

    def _query_matrix(self, query_text: str) -> np.ndarray:
        query_vector = self._encoder.encode_text(query_text).astype("float32")
        query_matrix = np.ascontiguousarray(query_vector.reshape(1, -1))
        faiss.normalize_L2(query_matrix)
        return query_matrix

    def _normalize_score(self, value: float) -> float:
        return float(np.clip((value + 1.0) / 2.0, 0.0, 1.0))

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


def rebuild_index() -> dict:
    """
    Rebuild the shared in-memory FAISS candidate retrieval index.

    Admin tasks call this after destination data or SBERT text changes. Existing
    CandidateRetriever instances are refreshed too, so cached services start
    using the new embedding matrix without requiring a process restart.
    """

    from backend.infrastructure.repositories.json_destination_repository import (
        JsonDestinationRepository,
    )

    destinations = JsonDestinationRepository().get_all()
    if not destinations:
        CandidateRetriever._cache = None
        return {
            "status": "empty",
            "destinations": 0,
            "message": "No destinations found; candidate index cleared.",
        }

    instances = list(CandidateRetriever._instances)
    if instances:
        for retriever in instances:
            retriever.rebuild_index(destinations)
    else:
        CandidateRetriever(destinations)

    cache = CandidateRetriever._cache
    return {
        "status": "ok",
        "destinations": len(destinations),
        "dimensions": int(cache.matrix.shape[1]) if cache is not None else 0,
        "index_type": "faiss.IndexFlatIP",
        "message": "Candidate retrieval FAISS index rebuilt.",
    }
