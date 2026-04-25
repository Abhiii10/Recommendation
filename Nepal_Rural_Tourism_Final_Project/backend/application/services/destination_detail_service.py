from __future__ import annotations
from typing import Optional

from backend.infrastructure.repositories.json_destination_repository import JsonDestinationRepository
from backend.infrastructure.repositories.json_accommodation_repository import JsonAccommodationRepository
from backend.domain.entities.destination import Destination
from backend.domain.entities.accommodation import Accommodation
from typing import List


class DestinationDetailService:
    def __init__(self):
        self._dest_repo = JsonDestinationRepository()
        self._acc_repo  = JsonAccommodationRepository()

    def get_destination(self, destination_id: str) -> Optional[Destination]:
        return self._dest_repo.get_by_id(destination_id)

    def get_all_destinations(self) -> List[Destination]:
        return self._dest_repo.get_all()

    def get_accommodations(self, destination_id: str) -> List[Accommodation]:
        return self._acc_repo.get_by_destination_id(destination_id)
