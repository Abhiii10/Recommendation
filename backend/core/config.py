from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    project_name: str = "Nepal Rural Tourism Recommendation API"
    project_version: str = "3.0.0"

    # Testing/development only
    allowed_origins: list[str] = ["*"]

    model_name: str = "all-MiniLM-L6-v2"

    retrieve_top_k: int = 30
    final_top_k: int = 10

    retrieval_semantic_weight: float = 0.72
    retrieval_activity_weight: float = 0.18
    retrieval_category_weight: float = 0.10

    semantic_weight: float = 0.50
    collaborative_weight: float = 0.20
    contextual_weight: float = 0.30

    activity_weight: float = 0.22
    vibe_weight: float = 0.14
    season_weight: float = 0.16
    budget_weight: float = 0.16
    accessibility_weight: float = 0.10
    family_weight: float = 0.08
    accommodation_weight: float = 0.14

    max_results_per_district: int = 2
    max_results_per_category: int = 2

    root_dir: Path = Path(__file__).resolve().parents[2]
    data_dir: Path = root_dir / "data"

    destinations_file: Path = data_dir / "destinations.json"
    accommodations_file: Path = data_dir / "accommodations.json"
    interactions_file: Path = data_dir / "interactions.json"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="",
        extra="ignore",
    )


settings = Settings()