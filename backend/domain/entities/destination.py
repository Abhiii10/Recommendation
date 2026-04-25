from typing import List, Optional
from pydantic import BaseModel


class Destination(BaseModel):
    id: str
    name: str
    province: Optional[str] = None
    district: Optional[str] = None
    municipality: Optional[str] = None
    category: List[str] = []
    activities: List[str] = []
    best_season: List[str] = []
    budget_level: str = ""
    accessibility: str = ""
    family_friendly: bool = False
    adventure_level: Optional[int] = None
    culture_level: Optional[int] = None
    nature_level: Optional[int] = None
    short_description: str = ""
    full_description: str = ""
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    tags: List[str] = []
    confidence: str = ""
