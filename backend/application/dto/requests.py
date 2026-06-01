from typing import List, Optional

from pydantic import BaseModel, Field, model_validator


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
    user_id: Optional[str] = None
    destination_id: str
    event_type: Optional[str] = None
    action: Optional[str] = None
    value: float = 1.0
    timestamp: Optional[str] = None
    recommendation_id: Optional[str] = None
    recommended_destination_ids: List[str] = Field(default_factory=list)
    pipeline_used: Optional[str] = None

    @model_validator(mode="after")
    def sync_action_event_type(self) -> "InteractionRequestDto":
        if not self.event_type and self.action:
            self.event_type = self.action
        return self


class InteractionBatchRequestDto(BaseModel):
    interactions: List[InteractionRequestDto] = Field(default_factory=list)


class AuthRegisterRequestDto(BaseModel):
    username: str = Field(..., min_length=2, max_length=80)
    email: str = Field(..., min_length=5, max_length=254)
    password: str = Field(..., min_length=8, max_length=128)


class AuthLoginRequestDto(BaseModel):
    email: str = Field(..., min_length=5, max_length=254)
    password: str = Field(..., min_length=8, max_length=128)


class ChatHistoryItem(BaseModel):
    role: str
    text: str


class ChatRequestDto(BaseModel):
    question: str = Field(..., min_length=1, examples=["Tell me about Ghandruk"])
    language: str = Field("en", examples=["en"])
    top_k: int = Field(5, ge=1, le=10)
    history: List[ChatHistoryItem] = Field(default_factory=list)


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
