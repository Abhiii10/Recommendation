from typing import List
from backend.core.config import settings
from backend.shared.json_storage import JsonStorage
from backend.domain.entities.accommodation import Accommodation
from backend.domain.repositories.accommodation_repository import AccommodationRepository


class JsonAccommodationRepository(AccommodationRepository):
    def __init__(self):
        self._storage = JsonStorage(settings.accommodations_file)

    def get_all(self) -> List[Accommodation]:
        raw = self._storage.read()
        items = []
        for item in raw:
            # normalise the JSON field name differences
            if "type" in item and "accommodation_type" not in item:
                item["accommodation_type"] = item.pop("type")
            if "destination_name" in item:
                item.pop("destination_name", None)
            if "phone" in item:
                item.pop("phone", None)
            items.append(Accommodation(**item))
        return items

    def get_by_destination_id(self, destination_id: str) -> List[Accommodation]:
        return [a for a in self.get_all() if a.destination_id == destination_id]
