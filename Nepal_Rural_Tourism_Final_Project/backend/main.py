from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.api.v1.destinations import router as destinations_router
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
                "Uses SBERT semantic retrieval, contextual reranking, and "
                "collaborative filtering."
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
            return {"status": "healthy"}

        return application


app = ApplicationFactory().create()