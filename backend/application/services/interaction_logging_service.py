from backend.domain.entities.interaction import Interaction
from backend.infrastructure.repositories.json_interaction_repository import JsonInteractionRepository
from backend.application.dto.requests import InteractionRequestDto


class InteractionLoggingService:
    def __init__(self):
        self._repo = JsonInteractionRepository()

    def log(self, request: InteractionRequestDto) -> None:
        self._repo.add(Interaction(
            user_id=request.user_id,
            destination_id=request.destination_id,
            event_type=request.event_type,
            value=request.value,
            timestamp=request.timestamp,
        ))
