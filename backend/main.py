from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.api.v1.chat import router as chat_router
from backend.api.v1.destinations import router as destinations_router
from backend.api.v1.evaluate import router as evaluate_router
from backend.api.v1.interactions import router as interactions_router
from backend.api.v1.recommend import router as recommend_router
from backend.api.v1.similar import router as similar_router
from backend.core.config import settings


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
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

        application.include_router(
            recommend_router,
            prefix="/recommend",
            tags=["Recommendations"],
        )

        application.include_router(
            chat_router,
            prefix="/chat",
            tags=["Groq Chatbot"],
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
            destinations_router,
            prefix="/destinations",
            tags=["Destinations"],
        )

        # ── ML evaluation and training endpoints ──────────────────────────────
        application.include_router(
            evaluate_router,
            prefix="/evaluate",
            tags=["Evaluation & Training"],
        )

        @application.get("/", tags=["Health"])
        def root() -> dict[str, str]:
            return {
                "project": settings.project_name,
                "version": settings.project_version,
                "status":  "running",
                "docs":    "/docs",
            }

        @application.get("/health", tags=["Health"])
        def health() -> dict[str, str]:
            return {"status": "healthy"}

        return application


app = ApplicationFactory().create()
