from __future__ import annotations
from typing import Dict, List, Optional

import numpy as np
from sentence_transformers import SentenceTransformer

from backend.core.config import settings
from backend.domain.entities.destination import Destination


class DestinationTextBuilder:
    """
    Converts a Destination into a rich, naturally-phrased text document for SBERT.

    UPGRADED: The old version joined fields as a flat space-separated string
    ("Langtang trekking culture spring medium..."). This performs poorly because
    SBERT embeds meaning, not keyword frequency.

    The new version writes a short natural-language paragraph that mirrors how a
    travel writer would describe the place. This significantly improves cosine
    similarity against conversational user queries like
    "peaceful trek near mountains with low budget in autumn".
    """

    def build(self, destination: Destination) -> str:
        parts: List[str] = []

        # Core identity — name + location as one phrase
        name_line = destination.name
        if destination.district:
            name_line += f", {destination.district}"
        if destination.province:
            name_line += f", {destination.province} Province"
        if destination.municipality:
            name_line += f" ({destination.municipality})"
        parts.append(name_line)

        # Category & activities as sentences (not a word dump)
        if destination.category:
            parts.append(f"Category: {', '.join(destination.category)}.")
        if destination.activities:
            parts.append(f"Activities include {', '.join(destination.activities)}.")
        if destination.tags:
            parts.append(f"Known for: {', '.join(destination.tags)}.")

        # Descriptions — most semantically rich part
        if destination.short_description:
            parts.append(destination.short_description)
        if destination.full_description:
            parts.append(destination.full_description)

        # Practical attributes as readable sentences
        if destination.budget_level:
            parts.append(f"Budget level: {destination.budget_level}.")
        if destination.accessibility:
            parts.append(f"Accessibility: {destination.accessibility}.")
        if destination.best_season:
            parts.append(f"Best visited in {', '.join(destination.best_season)}.")

        # Numeric signals described in plain English
        levels: List[str] = []
        if destination.adventure_level:
            levels.append(f"adventure level {destination.adventure_level} out of 5")
        if destination.culture_level:
            levels.append(f"culture level {destination.culture_level} out of 5")
        if destination.nature_level:
            levels.append(f"nature level {destination.nature_level} out of 5")
        if levels:
            parts.append(f"Rated: {', '.join(levels)}.")

        if destination.family_friendly:
            parts.append("Suitable for families with children.")

        return " ".join(p for p in parts if p).strip()


class PreferenceQueryBuilder:
    """
    Converts user preferences into a natural-language query sentence.

    UPGRADED: The old version produced keyword dumps like:
        "trekking activities medium budget best in spring cultural vibe"
    This does not match the SBERT embedding space of natural-language destination
    documents, so cosine similarity was weaker than it should be.

    The new version builds a real sentence that mirrors how a traveller would
    describe what they want, matching the style of DestinationTextBuilder output.
    """

    _ADVENTURE_LABELS: Dict[int, str] = {
        1: "easy and leisurely",
        2: "light",
        3: "moderate",
        4: "challenging",
        5: "extreme",
    }

    def build(
        self,
        activity: str,
        budget: str,
        season: str,
        vibe: str,
        family_friendly: Optional[bool],
        adventure_level: Optional[int] = None,
    ) -> str:
        parts: List[str] = []

        # Opening sentence — what the user wants to do and feel
        if activity and vibe:
            parts.append(
                f"I am looking for a {vibe} destination in Nepal for {activity}."
            )
        elif activity:
            parts.append(f"I want to go {activity} in Nepal.")
        elif vibe:
            parts.append(f"I want a {vibe} travel experience in Nepal.")

        if season:
            parts.append(f"I plan to visit in {season}.")
        if budget:
            parts.append(f"My budget is {budget}.")
        if adventure_level:
            label = self._ADVENTURE_LABELS.get(adventure_level, "moderate")
            parts.append(f"I prefer a {label} adventure level.")
        if family_friendly is True:
            parts.append(
                "The destination should be family friendly and suitable for children."
            )

        return " ".join(parts).strip()


class SbertEncoder:
    """
    Singleton-style SBERT wrapper.

    UPGRADED: Added explicit batch_size=64 for faster encoding of large
    destination sets at startup. The model itself is set in config.py —
    change model_name there to switch between models.
    """

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
            normalize_embeddings=True,  # required for cosine via dot-product
            show_progress_bar=False,
            batch_size=64,              # explicit batch size for large sets
        )

    def encode_text(self, text: str) -> np.ndarray:
        return self.encode_texts([text])[0]