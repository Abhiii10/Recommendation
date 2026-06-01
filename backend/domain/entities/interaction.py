from typing import List, Optional

from pydantic import BaseModel, Field


class Interaction(BaseModel):
    user_id: str
    destination_id: str
    event_type: str
    value: float = 1.0
    timestamp: Optional[str] = None
    recommendation_id: Optional[str] = None
    recommended_destination_ids: List[str] = Field(default_factory=list)
    pipeline_used: Optional[str] = None
