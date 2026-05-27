from datetime import datetime, timezone
import logging

from backend.core.constants import EventTypes
from backend.domain.entities.interaction import Interaction
from backend.infrastructure.repositories.interaction_repository_factory import (
    build_interaction_repository,
)
from backend.application.dto.requests import (
    InteractionBatchRequestDto,
    InteractionRequestDto,
)

logger = logging.getLogger(__name__)


class InteractionLoggingService:
    def __init__(self):
        self._repo = build_interaction_repository()

    def log(self, request: InteractionRequestDto) -> bool:
        event_type = request.event_type.strip().lower()

        if event_type not in EventTypes.values():
            logger.warning("Unsupported interaction event type: %s", event_type)
            return False

        timestamp = request.timestamp or datetime.now(timezone.utc).isoformat()

        self._repo.add(Interaction(
            user_id=request.user_id,
            destination_id=request.destination_id,
            event_type=event_type,
            value=request.value,
            timestamp=timestamp,
        ))
        return True

    def log_many(self, request: InteractionBatchRequestDto) -> int:
        logged = 0

        for interaction in request.interactions:
            if self.log(interaction):
                logged += 1

        return logged
