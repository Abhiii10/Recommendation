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
    semantic_weight:      float = 0.60
    collaborative_weight: float = 0.10
    contextual_weight:    float = 0.30

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

    # ── Groq chatbot ──────────────────────────────────────────────────────────
    groq_api_key:            str = ""
    groq_model:              str = "llama-3.1-8b-instant"
    groq_base_url:           str = "https://api.groq.com/openai/v1"
    groq_max_output_tokens:  int = 600
    groq_temperature:        float = 0.4

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
    app_db_file:          Path = data_dir / "app.sqlite3"
    interaction_storage_backend: str = "sqlite"

    # ── ML ranker settings ────────────────────────────────────────────────────
    # users_file stores synthetic users generated for ML training
    users_file:    Path = data_dir / "users.json"
    # MODEL_DIR is where the trained ranking model is saved
    MODEL_DIR:     str  = str(ROOT_DIR / "models")
    # RANDOM_SEED ensures reproducible ML training runs
    RANDOM_SEED:   int  = 42

    model_config = SettingsConfigDict(
        env_file=ROOT_DIR / ".env",
        env_prefix="",
        extra="ignore",
    )


settings = Settings()
