from typing import List, Optional

from backend.core.config import settings
from backend.domain.entities.user import User
from backend.shared.json_storage import JsonStorage


class JsonUserRepository:
    """
    Stores and retrieves User objects from users.json.
    Used exclusively for synthetic users created during ML training.
    """

    def __init__(self):
        self._storage = JsonStorage(settings.users_file)

    def get_all(self) -> List[User]:
        return [User(**item) for item in self._storage.read()]

    def get_synthetic(self) -> List[User]:
        return [u for u in self.get_all() if u.is_synthetic]

    def add(self, user: User) -> None:
        current = self._storage.read()
        current.append(user.model_dump())
        self._storage.write(current)

    def add_many(self, users: List[User]) -> None:
        current = self._storage.read()
        current.extend([u.model_dump() for u in users])
        self._storage.write(current)

    def get_by_id(self, user_id: str) -> Optional[User]:
        for u in self.get_all():
            if u.id == user_id:
                return u
        return None

    def clear_synthetic(self) -> int:
        """Removes all synthetic users. Returns count deleted."""
        all_users = self.get_all()
        real_users = [u for u in all_users if not u.is_synthetic]
        deleted = len(all_users) - len(real_users)
        self._storage.write([u.model_dump() for u in real_users])
        return deleted