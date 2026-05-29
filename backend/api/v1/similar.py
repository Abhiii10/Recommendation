from functools import lru_cache

from fastapi import APIRouter

from backend.application.dto.responses import SimilarResponseDto

router = APIRouter()


@lru_cache(maxsize=1)
def _get_service():
    from backend.application.services.similar_destination_service import (
        SimilarDestinationService,
    )

    return SimilarDestinationService()


@router.get("/{destination_id}", response_model=SimilarResponseDto)
def similar_destinations(destination_id: str, top_k: int = 5):
    """Return destinations semantically similar to a given destination."""
    return _get_service().get_similar(destination_id, top_k)
