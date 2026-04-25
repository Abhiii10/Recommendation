from typing import List, Optional
from pydantic import BaseModel


class Accommodation(BaseModel):
    id: str
    destination_id: str
    name: str
    accommodation_type: Optional[str] = None
    price_range: Optional[str] = None
    amenities: List[str] = []
    location_note: Optional[str] = None
    source: Optional[str] = None
    confidence: Optional[str] = None
