from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


ROOT_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    project_name: str    = "Nepal Rural Tourism Recommendation API"
    project_version: str = "3.3.0"

    allowed_origins: list[str] = ["*"]

    model_name: str = "all-MiniLM-L6-v2"

    retrieve_top_k: int = 30
    final_top_k:    int = 10

    retrieval_semantic_weight:  float = 0.72
    retrieval_activity_weight:  float = 0.18
    retrieval_category_weight:  float = 0.10

    # ── Final score weights (FIXED) ───────────────────────────────────────────
    # Old:  semantic=0.50, collaborative=0.20, contextual=0.30
    # Problem: collaborative component was carrying 100% popularity in cold-start,
    # giving a blanket +0.20 boost to the most-interacted destination (Bandipur)
    # regardless of query intent.
    # Fix: raise semantic weight so SBERT meaning drives ranking, shrink collab
    # so the popularity residual has less room to override semantic signal.
    semantic_weight:      float = 0.60   # was 0.50
    collaborative_weight: float = 0.10   # was 0.20
    contextual_weight:    float = 0.30   # unchanged

    # ── Contextual sub-weights (sum should equal 1.0) ─────────────────────────
    activity_weight:      float = 0.22
    vibe_weight:          float = 0.14
    season_weight:        float = 0.16
    budget_weight:        float = 0.16
    accessibility_weight: float = 0.10
    family_weight:        float = 0.08
    accommodation_weight: float = 0.14

    max_results_per_district: int = 2
    max_results_per_category: int = 2

    # ── Gemini Flash chatbot ──────────────────────────────────────────────────
    gemini_api_key:            str = ""
    gemini_model:              str = "gemini-2.0-flash"
    gemini_max_output_tokens:  int = 600
    gemini_temperature:        float = 0.4

    root_dir: Path = ROOT_DIR
    data_dir: Path = ROOT_DIR / "data"

    destinations_file:    Path = data_dir / "destinations.json"
    accommodations_file:  Path = data_dir / "accommodations.json"
    interactions_file:    Path = data_dir / "interactions.json"

    model_config = SettingsConfigDict(
        env_file=ROOT_DIR / ".env",
        env_prefix="",
        extra="ignore",
    )


settings = Settings()