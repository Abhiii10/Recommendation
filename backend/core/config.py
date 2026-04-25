from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    project_name: str = "Nepal Rural Tourism Recommendation API"
    project_version: str = "3.0.0"

    allowed_origins: list[str] = [
        "http://127.0.0.1:8000",
        "http://localhost:8000",
        "http://127.0.0.1:3000",
        "http://localhost:3000",
    ]

    # UPGRADED: all-mpnet-base-v2 has much better semantic quality than
    # all-MiniLM-L6-v2. First run will download ~420MB; cached after that.
    # Alternative for faster inference: "msmarco-distilbert-base-v4"
    model_name: str = "all-mpnet-base-v2"

    # UPGRADED: wider candidate pool gives reranker more to work with
    retrieve_top_k: int = 40
    final_top_k: int = 10

    retrieval_semantic_weight: float = 0.65
    retrieval_activity_weight: float = 0.22
    retrieval_category_weight: float = 0.13

    semantic_weight: float = 0.42
    # UPGRADED: collaborative weight raised — matrix is now cached so scores
    # are reliable and worth more influence in the final blend
    collaborative_weight: float = 0.28
    contextual_weight: float = 0.30

    activity_weight: float = 0.24
    vibe_weight: float = 0.14
    season_weight: float = 0.16
    budget_weight: float = 0.16
    accessibility_weight: float = 0.10
    family_weight: float = 0.08
    accommodation_weight: float = 0.12

    # UPGRADED: 3 per district so small datasets don't get over-cut
    max_results_per_district: int = 3
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