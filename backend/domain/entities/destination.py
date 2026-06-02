from typing import List, Optional

from pydantic import BaseModel, Field


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
    images: List[str] = Field(default_factory=list)
    image: str = ""
    confidence: str = ""
    highlights: List[str] = Field(default_factory=list)
    how_to_reach: str = ""
    accommodation_types: List[str] = Field(default_factory=list)
    elevation_m: Optional[int] = None
    typical_duration: str = ""
    nearby_destinations: List[str] = Field(default_factory=list)
    sbert_text: str = ""

    # ── ML ranking fields (added for synthetic data + ranker) ─────────────────
    popularity_score: float = 0.5
    avg_rating: float = 0.0
    total_interactions: int = 0
