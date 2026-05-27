from fastapi import APIRouter, Header
from backend.api.v1.auth_dependencies import optional_authenticated_user_id
from backend.application.dto.requests import (
    InteractionBatchRequestDto,
    InteractionRequestDto,
)
from backend.application.services.interaction_logging_service import InteractionLoggingService

router = APIRouter()
_service = InteractionLoggingService()


@router.post("")
def log_interaction(
    payload: InteractionRequestDto,
    authorization: str | None = Header(default=None),
):
    """Log a user interaction (click, detail_view, save, rating)."""
    authenticated_user_id = optional_authenticated_user_id(authorization)
    if authenticated_user_id is not None:
        payload = payload.model_copy(update={"user_id": authenticated_user_id})

    _service.log(payload)
    return {"status": "ok", "message": "Interaction logged"}


@router.post("/batch")
def log_interaction_batch(
    payload: InteractionBatchRequestDto,
    authorization: str | None = Header(default=None),
):
    """Log multiple user interactions for offline sync."""
    authenticated_user_id = optional_authenticated_user_id(authorization)
    if authenticated_user_id is not None:
        payload = payload.model_copy(
            update={
                "interactions": [
                    interaction.model_copy(
                        update={"user_id": authenticated_user_id}
                    )
                    for interaction in payload.interactions
                ]
            }
        )

    logged = _service.log_many(payload)
    return {
        "status": "ok",
        "message": f"{logged} interactions logged",
        "logged": logged,
    }
