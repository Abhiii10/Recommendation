from fastapi import APIRouter
from backend.application.dto.requests import InteractionRequestDto
from backend.application.services.interaction_logging_service import InteractionLoggingService

router = APIRouter()
_service = InteractionLoggingService()


@router.post("")
def log_interaction(payload: InteractionRequestDto):
    """Log a user interaction (click, detail_view, save, rating)."""
    _service.log(payload)
    return {"status": "ok", "message": "Interaction logged"}
