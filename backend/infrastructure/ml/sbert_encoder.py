from __future__ import annotations
from typing import List, Optional
import numpy as np
from sentence_transformers import SentenceTransformer
from backend.core.config import settings
from backend.domain.entities.destination import Destination


class DestinationTextBuilder:
    """Converts a Destination into a rich text string for SBERT."""

    def build(self, destination: Destination) -> str:
        parts: List[str] = [
            destination.name,
            destination.district or "",
            destination.province or "",
            destination.municipality or "",
            " ".join(destination.category),
            " ".join(destination.activities),
            " ".join(destination.tags),
            destination.short_description,
            destination.full_description,
            destination.budget_level,
            destination.accessibility,
            " ".join(destination.best_season),
            f"adventure level {destination.adventure_level}" if destination.adventure_level else "",
            f"culture level {destination.culture_level}" if destination.culture_level else "",
            f"nature level {destination.nature_level}" if destination.nature_level else "",
            "family friendly" if destination.family_friendly else "",
        ]
        return " ".join(p for p in parts if p).strip()


class PreferenceQueryBuilder:
    """Converts user preferences into a natural-language query string."""

    def build(
        self,
        activity: str,
        budget: str,
        season: str,
        vibe: str,
        family_friendly: Optional[bool],
        adventure_level: Optional[int] = None,
    ) -> str:
        parts = [
            f"{activity} activities",
            f"{budget} budget",
            f"best in {season}",
            f"{vibe} vibe",
        ]
        if family_friendly is True:
            parts.append("family friendly travel")
        if adventure_level:
            level_map = {1: "easy leisure", 2: "light", 3: "moderate", 4: "challenging", 5: "extreme adventure"}
            parts.append(f"{level_map.get(adventure_level, '')} adventure")
        return " ".join(parts).strip()


class SbertEncoder:
    """Singleton-style SBERT wrapper."""

    _instance: Optional["SbertEncoder"] = None

    def __new__(cls) -> "SbertEncoder":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._model = SentenceTransformer(settings.model_name)
        return cls._instance

    def encode_texts(self, texts: List[str]) -> np.ndarray:
        return self._model.encode(
            texts,
            convert_to_numpy=True,
            normalize_embeddings=True,
            show_progress_bar=False,
        )

    def encode_text(self, text: str) -> np.ndarray:
        return self.encode_texts([text])[0]
