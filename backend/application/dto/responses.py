from typing import Dict, List, Optional

from pydantic import BaseModel, Field, model_validator


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
    recommendation_id: Optional[str] = None
    pipeline_used: Optional[str] = None


class SimilarResponseDto(BaseModel):
    results: List[RecommendationResponseItemDto]


class ChatResponseDto(BaseModel):
    answer: str
    reply: Optional[str] = None
    source: str = "groq"
    used_context: List[str] = Field(default_factory=list)
    offline: bool = False
    fallback: Optional[str] = None

    @model_validator(mode="after")
    def sync_reply(self) -> "ChatResponseDto":
        if not self.reply:
            self.reply = self.answer
        return self


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


class RecommendationQualityDto(BaseModel):
    window_days: int = 7
    recommendations_shown: int = 0
    clicks: int = 0
    saves: int = 0
    click_through_rate: float = 0.0
    save_rate: float = 0.0
    average_clicked_position: float = 0.0
    pipeline_breakdown: Dict[str, float] = Field(default_factory=dict)


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
    recommendation_quality_last_7_days: RecommendationQualityDto = Field(
        default_factory=RecommendationQualityDto
    )
    event_counts: List[InteractionEventCountDto] = Field(default_factory=list)
    top_destinations: List[DestinationAnalyticsDto] = Field(default_factory=list)
