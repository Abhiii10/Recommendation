from fastapi import APIRouter, Header
from backend.api.v1.auth_dependencies import optional_authenticated_user_id
from backend.application.dto.requests import RecommendationRequestDto
from backend.application.dto.responses import RecommendationResponseDto
from backend.application.services.recommendation_service import RecommendationService

router = APIRouter()
_service = RecommendationService()          # singleton — SBERT loaded once


@router.post("", response_model=RecommendationResponseDto)
def recommend(
    payload: RecommendationRequestDto,
    authorization: str | None = Header(default=None),
):
    """
    Main recommendation endpoint.
    Send user preferences → receive ranked destinations with scores and reasons.
    """
    authenticated_user_id = optional_authenticated_user_id(authorization)
    if authenticated_user_id is not None:
        payload = payload.model_copy(update={"user_id": authenticated_user_id})

    return _service.recommend(payload)
