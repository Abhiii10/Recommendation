from typing import Optional
from pydantic import BaseModel, Field


class RecommendationRequestDto(BaseModel):
    activity: str = Field(..., examples=["trekking"])
    budget: str   = Field(..., examples=["medium"])
    season: str   = Field(..., examples=["spring"])
    vibe: str     = Field(..., examples=["cultural"])
    family_friendly: Optional[bool] = None
    adventure_level: Optional[int]  = Field(None, ge=1, le=5)
    seed_destination_id: Optional[str] = None
    user_id: Optional[str] = None
    top_k: int = Field(10, ge=1, le=30)


class InteractionRequestDto(BaseModel):
    user_id: str
    destination_id: str
    event_type: str
    value: float = 1.0
    timestamp: Optional[str] = None
