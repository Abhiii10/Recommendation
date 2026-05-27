from fastapi import APIRouter, Query

from backend.application.dto.responses import RecommenderAnalyticsDto
from backend.application.services.analytics_service import AnalyticsService

router = APIRouter()
_service = AnalyticsService()


@router.get("/recommender", response_model=RecommenderAnalyticsDto)
def recommender_analytics(
    top_k: int = Query(10, ge=1, le=50),
) -> RecommenderAnalyticsDto:
    """
    Summarise recommendation engagement from interaction logs.

    Useful production metrics:
    - impressions
    - click-through rate
    - detail-view rate
    - save rate
    - rating rate
    - top destinations by weighted engagement
    """
    return _service.recommender_summary(top_k=top_k)
