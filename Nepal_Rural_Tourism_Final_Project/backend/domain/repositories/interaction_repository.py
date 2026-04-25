from abc import ABC, abstractmethod
from typing import List
from backend.domain.entities.interaction import Interaction


class InteractionRepository(ABC):
    @abstractmethod
    def get_all(self) -> List[Interaction]: ...

    @abstractmethod
    def add(self, interaction: Interaction) -> None: ...
