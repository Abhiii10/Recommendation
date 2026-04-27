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


# ── Evaluation DTOs ───────────────────────────────────────────────────────────

class EvalRequest(BaseModel):
    """Request body for POST /evaluate/"""
    n_users: int = Field(50, ge=1, le=500, description="Number of synthetic users to evaluate against")
    k: int       = Field(10, ge=1, le=30,  description="Cutoff rank for P@K, R@K, nDCG@K")


class EvalResponse(BaseModel):
    """Response from POST /evaluate/"""
    precision_at_k: float
    recall_at_k:    float
    ndcg_at_k:      float
    coverage:       float
    diversity:      float
    novelty:        float
    n_users:        int
    k:              int
    message:        Optional[str] = None