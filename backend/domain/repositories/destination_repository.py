from abc import ABC, abstractmethod
from typing import List, Optional
from backend.domain.entities.destination import Destination


class DestinationRepository(ABC):
    @abstractmethod
    def get_all(self) -> List[Destination]: ...

    @abstractmethod
    def get_by_id(self, destination_id: str) -> Optional[Destination]: ...
