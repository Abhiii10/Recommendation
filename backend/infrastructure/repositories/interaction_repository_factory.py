from backend.core.config import settings
from backend.domain.repositories.interaction_repository import InteractionRepository
from backend.infrastructure.repositories.json_interaction_repository import (
    JsonInteractionRepository,
)
from backend.infrastructure.repositories.sqlite_interaction_repository import (
    SqliteInteractionRepository,
)


def build_interaction_repository() -> InteractionRepository:
    backend = settings.interaction_storage_backend.lower()

    if backend == "json":
        return JsonInteractionRepository()

    if backend == "postgres":
        from backend.infrastructure.repositories.postgres_interaction_repository import (
            PostgresInteractionRepository,
        )

        return PostgresInteractionRepository()

    return SqliteInteractionRepository()
