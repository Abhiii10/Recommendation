import logging
from functools import lru_cache
from uuid import uuid4

from fastapi import APIRouter, Header, Response

from backend.api.v1.auth_dependencies import optional_authenticated_user_id
from backend.application.dto.requests import RecommendationRequestDto
from backend.application.dto.responses import RecommendationResponseDto
from backend.application.services.interaction_logging_service import (
    InteractionLoggingService,
)
from backend.cache import get_cache, make_cache_key, set_cache
from backend.core.config import settings

router = APIRouter()
logger = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def _get_service():
    from backend.application.services.recommendation_service import (
        RecommendationService,
    )

    return RecommendationService()


@lru_cache(maxsize=1)
def _get_interaction_logger() -> InteractionLoggingService:
    return InteractionLoggingService()


@router.post("", response_model=RecommendationResponseDto)
def recommend(
    payload: RecommendationRequestDto,
    response: Response,
    authorization: str | None = Header(default=None),
):
    """
    Main recommendation endpoint.
    Send user preferences and receive ranked destinations with scores and reasons.
    """
    authenticated_user_id = optional_authenticated_user_id(authorization)
    if authenticated_user_id is not None:
        payload = payload.model_copy(update={"user_id": authenticated_user_id})

    preferences = _cache_preferences(payload)
    cache_key = make_cache_key(payload.user_id, preferences)
    cached = get_cache(cache_key)
    recommendation_id = str(uuid4())
    user_id = payload.user_id or "anonymous"

    if cached is not None:
        response.headers["X-Cache"] = "HIT"
        result = RecommendationResponseDto.model_validate(cached).model_copy(
            update={
                "recommendation_id": recommendation_id,
                "pipeline_used": "cached",
            }
        )
        _log_recommendation_response(
            user_id=user_id,
            recommendation_id=recommendation_id,
            result=result,
            pipeline_used="cached",
        )
        response.headers["X-Recommendation-ID"] = recommendation_id
        return result

    result = _get_service().recommend(payload)
    set_cache(
        cache_key,
        result.model_dump(mode="json"),
        settings.redis_cache_ttl_seconds,
    )
    pipeline_used = "offline" if settings.offline_mode else "online"
    result = result.model_copy(
        update={
            "recommendation_id": recommendation_id,
            "pipeline_used": pipeline_used,
        }
    )
    _log_recommendation_response(
        user_id=user_id,
        recommendation_id=recommendation_id,
        result=result,
        pipeline_used=pipeline_used,
    )
    response.headers["X-Cache"] = "MISS"
    response.headers["X-Recommendation-ID"] = recommendation_id
    return result


def _cache_preferences(payload: RecommendationRequestDto) -> dict:
    return {
        "activity": payload.activity,
        "budget": payload.budget,
        "season": payload.season,
        "vibe": payload.vibe,
        "family_friendly": payload.family_friendly,
        "adventure_level": payload.adventure_level,
        "seed_destination_id": payload.seed_destination_id,
        "top_k": payload.top_k,
        "semantic_only": payload.semantic_only,
    }


def _log_recommendation_response(
    *,
    user_id: str,
    recommendation_id: str,
    result: RecommendationResponseDto,
    pipeline_used: str,
) -> None:
    try:
        _get_interaction_logger().log_recommendation_response(
            user_id=user_id,
            recommendation_id=recommendation_id,
            recommended_destination_ids=[item.id for item in result.results],
            pipeline_used=pipeline_used,
        )
    except Exception as exc:
        logger.warning(
            "Failed to log recommendation response %s: %s",
            recommendation_id,
            exc,
        )
