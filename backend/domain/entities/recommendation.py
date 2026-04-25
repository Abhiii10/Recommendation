from typing import List, Dict, Optional
from pydantic import BaseModel


class RecommendationComponents(BaseModel):
    semantic: float
    collaborative: float
    activity_match: float
    vibe_match: float
    season_match: float
    budget_match: float
    accessibility_fit: float
    family_fit: float
    accommodation_fit: float


class Recommendation(BaseModel):
    id: str
    name: str
    district: Optional[str] = None
    province: Optional[str] = None
    score: float
    components: RecommendationComponents
    reasons: List[str] = []
    metadata: Dict[str, str] = {}
