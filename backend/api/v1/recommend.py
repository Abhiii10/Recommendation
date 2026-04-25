from fastapi import APIRouter
from backend.application.dto.requests import RecommendationRequestDto
from backend.application.dto.responses import RecommendationResponseDto
from backend.application.services.recommendation_service import RecommendationService

router = APIRouter()
_service = RecommendationService()          # singleton — SBERT loaded once


@router.post("", response_model=RecommendationResponseDto)
def recommend(payload: RecommendationRequestDto):
    """
    Main recommendation endpoint.
    Send user preferences → receive ranked destinations with scores and reasons.
    """
    return _service.recommend(payload)
