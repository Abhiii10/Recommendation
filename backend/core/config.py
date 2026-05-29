import secrets
import sys
from pathlib import Path

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


ROOT_DIR = Path(__file__).resolve().parents[2]
BACKEND_DIR = Path(__file__).resolve().parents[1]
AUTH_SECRET_PLACEHOLDER = "change-this-auth-secret-in-production"


class Settings(BaseSettings):
    project_name: str    = "Nepal Rural Tourism Recommendation API"
    project_version: str = "3.3.0"

    allowed_origins_raw: str = Field("*", validation_alias="ALLOWED_ORIGINS")
    environment: str = Field("development", validation_alias="ENVIRONMENT")

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

    # Premium translator fallback. Disabled when ANTHROPIC_API_KEY is blank.
    anthropic_api_key: str = ""
    anthropic_model:   str = "claude-3-5-haiku-latest"

    root_dir: Path = ROOT_DIR
    data_dir: Path = ROOT_DIR / "data"

    destinations_file:    Path = data_dir / "destinations.json"
    accommodations_file:  Path = data_dir / "accommodations.json"
    interactions_file:    Path = data_dir / "interactions.json"
    app_db_file:          Path = data_dir / "app.sqlite3"
    interaction_storage_backend: str = "sqlite"
    database_url: str = ""
    auth_users_file: Path = data_dir / "auth_users.json"
    auth_secret_key: str = AUTH_SECRET_PLACEHOLDER
    auth_access_token_expire_minutes: int = 60 * 24 * 30

    # ── ML ranker settings ────────────────────────────────────────────────────
    # users_file stores synthetic users generated for ML training
    users_file:    Path = data_dir / "users.json"
    # MODEL_DIR is where the trained ranking model is saved
    MODEL_DIR:     str  = str(ROOT_DIR / "models")
    # RANDOM_SEED ensures reproducible ML training runs
    RANDOM_SEED:   int  = 42

    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        env_prefix="",
        extra="ignore",
    )

    @model_validator(mode="after")
    def validate_auth_secret(self) -> "Settings":
        secret = self.auth_secret_key.strip()
        is_placeholder = not secret or secret == AUTH_SECRET_PLACEHOLDER

        if is_placeholder:
            if self.environment == "production":
                raise ValueError(
                    "AUTH_SECRET_KEY must be set in production. "
                    "Run scripts/setup_env.py to generate one."
                )

            self.auth_secret_key = secrets.token_hex(32)
            print(
                "WARNING: AUTH_SECRET_KEY not set. "
                "A temporary key has been generated for this session. "
                "Set AUTH_SECRET_KEY in backend/.env for persistence.",
                file=sys.stderr,
                flush=True,
            )
        else:
            self.auth_secret_key = secret

        return self

    @property
    def allowed_origins(self) -> list[str]:
        if self.allowed_origins_raw.strip() == "*":
            return ["*"]
        return [
            origin.strip()
            for origin in self.allowed_origins_raw.split(",")
            if origin.strip()
        ]


settings = Settings()
