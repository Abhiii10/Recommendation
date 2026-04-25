from fastapi import APIRouter
from backend.application.dto.responses import SimilarResponseDto
from backend.application.services.similar_destination_service import SimilarDestinationService

router = APIRouter()
_service = SimilarDestinationService()


@router.get("/{destination_id}", response_model=SimilarResponseDto)
def similar_destinations(destination_id: str, top_k: int = 5):
    """Return destinations semantically similar to a given destination."""
    return _service.get_similar(destination_id, top_k)
