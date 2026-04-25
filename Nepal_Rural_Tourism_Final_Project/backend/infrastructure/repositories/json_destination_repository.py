from typing import List, Optional
from backend.core.config import settings
from backend.shared.json_storage import JsonStorage
from backend.domain.entities.destination import Destination
from backend.domain.repositories.destination_repository import DestinationRepository


class JsonDestinationRepository(DestinationRepository):
    def __init__(self):
        self._storage = JsonStorage(settings.destinations_file)

    def get_all(self) -> List[Destination]:
        return [Destination(**item) for item in self._storage.read()]

    def get_by_id(self, destination_id: str) -> Optional[Destination]:
        for d in self.get_all():
            if d.id == destination_id:
                return d
        return None
