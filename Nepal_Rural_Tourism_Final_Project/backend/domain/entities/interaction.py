from typing import Optional
from pydantic import BaseModel


class Interaction(BaseModel):
    user_id: str
    destination_id: str
    event_type: str
    value: float = 1.0
    timestamp: Optional[str] = None
