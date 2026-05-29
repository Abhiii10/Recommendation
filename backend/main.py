from argparse import ArgumentParser
import errno
import socket

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.api.v1.analytics import router as analytics_router
from backend.api.v1.auth import router as auth_router
from backend.api.v1.chat import router as chat_router
from backend.api.v1.offline_chat import router as offline_chat_router
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
            destinations_router,
            prefix="/destinations",
            tags=["Destinations"],
        )

        # ── ML evaluation and training endpoints ──────────────────────────────
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


def _is_port_available(host: str, port: int) -> bool:
    probe_host = "0.0.0.0" if host in {"", "0.0.0.0"} else host

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        try:
            sock.bind((probe_host, port))
        except OSError as exc:
            if exc.errno in {errno.EADDRINUSE, 10048}:
                return False
            raise

    return True


def _select_port(host: str, requested_port: int) -> int:
    if _is_port_available(host, requested_port):
        return requested_port

    for candidate in range(8001, 8011):
        if _is_port_available(host, candidate):
            print(
                f"Port {requested_port} in use, starting on port {candidate}",
                flush=True,
            )
            return candidate

    raise RuntimeError(
        f"No free backend port found from {requested_port}, 8001-8010."
    )


def main() -> None:
    parser = ArgumentParser(description="Run the Nepal Tourism FastAPI backend.")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--reload", action="store_true")
    args = parser.parse_args()

    import uvicorn

    port = _select_port(args.host, args.port)
    target = "backend.main:app" if args.reload else app
    uvicorn.run(
        target,
        host=args.host,
        port=port,
        reload=args.reload,
    )


if __name__ == "__main__":
    main()
