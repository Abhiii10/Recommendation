from typing import List, Dict, Optional
from pydantic import BaseModel


class RecommendationResponseItemDto(BaseModel):
    id: str
    name: str
    district: Optional[str] = None
    province: Optional[str] = None
    score: float
    components: Dict[str, float]
    reasons: List[str]
    metadata: Dict[str, str] = {}


class RecommendationResponseDto(BaseModel):
    results: List[RecommendationResponseItemDto]
    total: int


class SimilarResponseDto(BaseModel):
    results: List[RecommendationResponseItemDto]
