from abc import ABC, abstractmethod
from typing import List
from backend.domain.entities.accommodation import Accommodation


class AccommodationRepository(ABC):
    @abstractmethod
    def get_all(self) -> List[Accommodation]: ...

    @abstractmethod
    def get_by_destination_id(self, destination_id: str) -> List[Accommodation]: ...
