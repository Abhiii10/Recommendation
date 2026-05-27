from __future__ import annotations

from datetime import datetime, timezone

from pydantic import BaseModel, Field


class AuthUser(BaseModel):
    id: str
    username: str
    email: str
    password_hash: str
    created_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
