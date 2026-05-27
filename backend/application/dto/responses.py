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


class AuthUserDto(BaseModel):
    id: str
    username: str
    email: str


class AuthTokenResponseDto(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: AuthUserDto


class InteractionEventCountDto(BaseModel):
    event_type: str
    count: int
    total_value: float = 0.0


class DestinationAnalyticsDto(BaseModel):
    id: str
    name: str
    district: Optional[str] = None
    province: Optional[str] = None
    impressions: int = 0
    clicks: int = 0
    detail_views: int = 0
    saves: int = 0
    unsaves: int = 0
    ratings: int = 0
    average_rating: float = 0.0
    click_through_rate: float = 0.0
    save_rate: float = 0.0


class RecommenderAnalyticsDto(BaseModel):
    total_interactions: int
    unique_users: int
    unique_destinations: int
    impressions: int
    clicks: int
    detail_views: int
    saves: int
    ratings: int
    click_through_rate: float
    detail_view_rate: float
    save_rate: float
    rating_rate: float
    event_counts: List[InteractionEventCountDto] = Field(default_factory=list)
    top_destinations: List[DestinationAnalyticsDto] = Field(default_factory=list)
