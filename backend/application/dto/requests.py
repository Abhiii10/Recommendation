from typing import Optional

from pydantic import BaseModel, Field


class RecommendationRequestDto(BaseModel):
    activity: str = Field(..., examples=["trekking"])
    budget: str = Field(..., examples=["medium"])
    season: str = Field(..., examples=["spring"])
    vibe: str = Field(..., examples=["cultural"])
    family_friendly: Optional[bool] = None
    adventure_level: Optional[int] = Field(None, ge=1, le=5)
    seed_destination_id: Optional[str] = None
    user_id: Optional[str] = None
    top_k: int = Field(10, ge=1, le=30)

    # ── Evaluation flag ───────────────────────────────────────────────────────
    # When True, the pipeline skips collaborative filtering and contextual
    # reranking entirely, returning candidates ranked purely by SBERT semantic
    # score. Used by evaluation/benchmark.py to produce a clean baseline for
    # A/B comparison. Has no effect on normal app usage.
    semantic_only: bool = Field(False, exclude=True)


class InteractionRequestDto(BaseModel):
    user_id: str
    destination_id: str
    event_type: str
    value: float = 1.0
    timestamp: Optional[str] = None


class ChatRequestDto(BaseModel):
    question: str = Field(..., min_length=1, examples=["Tell me about Ghandruk"])
    language: str = Field("en", examples=["en"])
    top_k: int = Field(5, ge=1, le=10)