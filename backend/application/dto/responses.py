from typing import Dict, List, Optional

from pydantic import BaseModel, Field


class RecommendationResponseItemDto(BaseModel):
    id: str
    name: str
    district: Optional[str] = None
    province: Optional[str] = None
    score: float
    components: Dict[str, float]
    reasons: List[str]
    metadata: Dict[str, str] = Field(default_factory=dict)


class RecommendationResponseDto(BaseModel):
    results: List[RecommendationResponseItemDto]
    total: int


class SimilarResponseDto(BaseModel):
    results: List[RecommendationResponseItemDto]


class ChatResponseDto(BaseModel):
    answer: str
    source: str = "groq"
    used_context: List[str] = Field(default_factory=list)
