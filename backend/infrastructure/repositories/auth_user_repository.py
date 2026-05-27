from __future__ import annotations

from pathlib import Path
from typing import List, Optional

from backend.core.config import settings
from backend.domain.entities.auth_user import AuthUser
from backend.shared.json_storage import JsonStorage


class AuthUserRepository:
    def __init__(self, path: Path | None = None):
        self._storage = JsonStorage(path or settings.auth_users_file)

    def get_all(self) -> List[AuthUser]:
        return [AuthUser(**item) for item in self._storage.read()]

    def get_by_id(self, user_id: str) -> Optional[AuthUser]:
        for user in self.get_all():
            if user.id == user_id:
                return user
        return None

    def get_by_email(self, email: str) -> Optional[AuthUser]:
        normalized_email = email.strip().lower()
        for user in self.get_all():
            if user.email.lower() == normalized_email:
                return user
        return None

    def add(self, user: AuthUser) -> None:
        users = self.get_all()
        users.append(user)
        self._storage.write([item.model_dump() for item in users])
