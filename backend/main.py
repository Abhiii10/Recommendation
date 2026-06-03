from argparse import ArgumentParser
import logging
import sqlite3

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.api.v1.admin import router as admin_router
from backend.api.v1.analytics import router as analytics_router
from backend.api.v1.auth import router as auth_router
from backend.api.v1.chat import router as chat_router
from backend.api.v1.offline_chat import router as offline_chat_router
from backend.api.v1.destinations import router as destinations_router
from backend.api.v1.evaluate import router as evaluate_router
from backend.api.v1.interactions import router as interactions_router
from backend.api.v1.recommend import router as recommend_router
from backend.api.v1.similar import router as similar_router
from backend.api.v1.translate import router as translate_router
from backend.core.config import settings
from backend.infrastructure.ml.ranker import get_ranking_model

logger = logging.getLogger(__name__)


def _sbert_loaded_in_memory() -> bool:
    try:
        from backend.infrastructure.ml.sbert_encoder import SbertEncoder

        instance = getattr(SbertEncoder, "_instance", None)
        return instance is not None and getattr(instance, "_model", None) is not None
    except Exception as exc:
        logger.debug("SBERT health probe skipped: %s", exc)
        return False


def _database_reachable() -> bool:
    backend = settings.interaction_storage_backend.lower()

    if backend == "postgres":
        if not settings.database_url:
            return False
        try:
            import psycopg

            with psycopg.connect(settings.database_url, connect_timeout=2) as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT 1")
                    cur.fetchone()
            return True
        except Exception as exc:
            logger.debug("PostgreSQL health probe failed: %s", exc)
            return False

    if backend == "sqlite":
        try:
            settings.app_db_file.parent.mkdir(parents=True, exist_ok=True)
            with sqlite3.connect(settings.app_db_file, timeout=2) as conn:
                conn.execute("SELECT 1").fetchone()
            return True
        except Exception as exc:
            logger.debug("SQLite health probe failed: %s", exc)
            return False

    return True


class ApplicationFactory:
    def create(self) -> FastAPI:
        application = FastAPI(
            title=settings.project_name,
            version=settings.project_version,
            description=(
                "AI-powered recommendation backend for Nepal Rural Tourism app. "
                "Uses SBERT semantic retrieval, contextual reranking, "
                "collaborative filtering, Groq chatbot, "
                "and ML-based ranking with offline evaluation."
            ),
        )

        application.add_middleware(
            CORSMiddleware,
            allow_origins=settings.allowed_origins,
            allow_credentials=False,
            allow_methods=["*"],
            allow_headers=["*"],
        )

        try:
            ranker = get_ranking_model()
            ranker.ensure_loaded()
            logger.info("Recommendation ranker startup mode: %s", ranker.mode)
        except Exception as exc:
            logger.warning(
                "Recommendation ranker startup check failed; fallback mode will be used: %s",
                exc,
            )

        application.include_router(
            recommend_router,
            prefix="/recommend",
            tags=["Recommendations"],
        )

        application.include_router(
            auth_router,
            prefix="/auth",
            tags=["Auth"],
        )

        application.include_router(
            chat_router,
            prefix="/chat",
            tags=["Groq Chatbot"],
        )

        application.include_router(
            offline_chat_router,
            prefix="/chat/offline",
            tags=["Offline Chat"],
        )

        application.include_router(
            interactions_router,
            prefix="/interactions",
            tags=["Interactions"],
        )

        application.include_router(
            similar_router,
            prefix="/similar",
            tags=["Similar"],
        )

        application.include_router(
            translate_router,
            tags=["Translator"],
        )

        application.include_router(
            destinations_router,
            prefix="/destinations",
            tags=["Destinations"],
        )

        # ML evaluation and training endpoints.
        application.include_router(
            analytics_router,
            prefix="/analytics",
            tags=["Analytics"],
        )

        application.include_router(
            evaluate_router,
            prefix="/evaluate",
            tags=["Evaluation & Training"],
        )

        application.include_router(
            admin_router,
            prefix="/admin",
            tags=["Admin"],
        )

        @application.get("/", tags=["Health"])
        def root() -> dict[str, str]:
            return {
                "project": settings.project_name,
                "version": settings.project_version,
                "status": "running",
                "docs": "/docs",
            }

        @application.get("/health", tags=["Health"])
        def health() -> dict[str, str]:
            # Health checks are intentionally local-only. Do not add outbound
            # HTTP calls here; Docker and offline demos must stay fast.
            _sbert_loaded_in_memory()
            _database_reachable()
            return {"status": "ok"}

        return application


app = ApplicationFactory().create()


def main() -> None:
    parser = ArgumentParser(description="Run the Nepal Tourism FastAPI backend.")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--reload", action="store_true")
    args = parser.parse_args()

    import uvicorn

    target = "backend.main:app" if args.reload else app
    uvicorn.run(
        target,
        host=args.host,
        port=args.port,
        reload=args.reload,
    )


if __name__ == "__main__":
    main()
