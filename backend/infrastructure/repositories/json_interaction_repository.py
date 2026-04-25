from typing import List
from backend.core.config import settings
from backend.shared.json_storage import JsonStorage
from backend.domain.entities.interaction import Interaction
from backend.domain.repositories.interaction_repository import InteractionRepository


class JsonInteractionRepository(InteractionRepository):
    def __init__(self):
        self._storage = JsonStorage(settings.interactions_file)

    def get_all(self) -> List[Interaction]:
        return [Interaction(**item) for item in self._storage.read()]

    def add(self, interaction: Interaction) -> None:
        current = self._storage.read()
        current.append(interaction.model_dump())
        self._storage.write(current)
