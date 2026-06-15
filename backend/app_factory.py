from __future__ import annotations

from typing import Any

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from ai_proxy import router as ai_router
from auth import router as auth_router
from database import initialize_database
from recommendation_routes import router as recommendation_router
from settings import UPLOAD_DIR


def create_app() -> FastAPI:
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    app = FastAPI(title="今天吃什么 联网推荐服务", version="1.0.0")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.mount("/media", StaticFiles(directory=str(UPLOAD_DIR)), name="media")

    @app.on_event("startup")
    def on_startup() -> None:
        initialize_database()

    @app.get("/")
    def root() -> dict[str, Any]:
        return {
            "success": True,
            "message": "today-eat-api",
            "data": {"service": "recommendations", "status": "ok"},
        }

    @app.get("/health")
    def health() -> dict[str, Any]:
        return {"success": True, "message": "ok", "data": {"status": "healthy"}}

    app.include_router(recommendation_router)
    app.include_router(auth_router)
    app.include_router(ai_router)
    return app
