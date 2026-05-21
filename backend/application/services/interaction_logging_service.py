from backend.domain.entities.interaction import Interaction
from backend.infrastructure.repositories.interaction_repository_factory import (
    build_interaction_repository,
)
from backend.application.dto.requests import InteractionRequestDto


class InteractionLoggingService:
    def __init__(self):
        self._repo = build_interaction_repository()

    def log(self, request: InteractionRequestDto) -> None:
        self._repo.add(Interaction(
            user_id=request.user_id,
            destination_id=request.destination_id,
            event_type=request.event_type,
            value=request.value,
            timestamp=request.timestamp,
        ))
