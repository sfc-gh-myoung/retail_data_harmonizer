"""Retail Data Harmonizer – FastAPI backend (JSON API v2 only).

REST API backend for the React frontend with Snowflake integration.
Instrumented with Snowflake native telemetry for distributed tracing.
"""

from __future__ import annotations

import asyncio
import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from backend.api import snowflake_client as sf
from backend.api.config import Settings, get_settings
from backend.api.dev_proxy import ViteDevProxyMiddleware

# Snowflake native telemetry for distributed tracing
try:
    from snowflake import telemetry

    TELEMETRY_AVAILABLE = hasattr(telemetry, "create_span")
except ImportError:
    TELEMETRY_AVAILABLE = False
    telemetry = None  # type: ignore[assignment]

logger = logging.getLogger("retail_harmonizer.api")

# Track background tasks for graceful shutdown
_background_tasks: set[asyncio.Task] = set()


# ---------------------------------------------------------------------------
# Lifespan context manager
# ---------------------------------------------------------------------------


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup/shutdown events."""
    # Startup: Pre-warm warehouse to avoid cold start on first request
    try:
        logger.info("Pre-warming Snowflake warehouse...")
        await sf.query("SELECT 1")
        logger.info("Warehouse warm and ready")
    except Exception as e:
        logger.warning(f"Failed to pre-warm warehouse: {e}")

    yield  # App runs here

    # Shutdown: cancel any pending background tasks
    from backend.api.routes import testing as _testing_mod

    all_bg = _background_tasks | _testing_mod._background_tasks
    if all_bg:
        logger.info(f"Cancelling {len(all_bg)} background task(s)...")
        for task in all_bg:
            task.cancel()
        await asyncio.gather(*all_bg, return_exceptions=True)
        logger.info("Background tasks cancelled")


# ---------------------------------------------------------------------------
# Application factory
# ---------------------------------------------------------------------------


def _configure_middleware(app: FastAPI, settings: Settings) -> None:
    """Configure CORS and other middleware."""
    app.add_middleware(
        CORSMiddleware,  # type: ignore[arg-type]  # Starlette typing limitation
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["*"],
    )


def _add_request_logging(app: FastAPI) -> None:
    """Add request timing and telemetry middleware."""

    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        """Log requests and create telemetry spans for distributed tracing."""
        start = time.perf_counter()

        if TELEMETRY_AVAILABLE and telemetry is not None:
            with telemetry.create_span(f"api_{request.url.path.replace('/', '_')}") as span:  # type: ignore[union-attr]
                span.set_attribute("http.method", request.method)
                span.set_attribute("http.path", request.url.path)
                response = await call_next(request)
                span.set_attribute("http.status_code", response.status_code)
                elapsed_ms = (time.perf_counter() - start) * 1000
                span.set_attribute("duration_ms", elapsed_ms)
        else:
            response = await call_next(request)
            elapsed_ms = (time.perf_counter() - start) * 1000

        logger.info(
            "%s %s — %d (%.1fms)",
            request.method,
            request.url.path,
            response.status_code,
            elapsed_ms,
        )
        return response


def _register_routers(app: FastAPI) -> None:
    """Register all API routers."""
    from backend.api.auth import router as auth_router
    from backend.api.routes import (
        comparison,
        dashboard,
        logs,
        matches,
        settings,
        system,
        testing,
    )
    from backend.api.routes.pipeline import router as pipeline_router

    # Auth router
    app.include_router(auth_router)

    # v2 JSON API routers
    app.include_router(system.router)  # /api/v2/health, /api/v2/status
    app.include_router(dashboard.router)  # /api/v2/dashboard/*
    app.include_router(settings.router)  # /api/v2/settings
    app.include_router(pipeline_router)  # /api/v2/pipeline/*
    app.include_router(matches.router)  # /api/v2/matches/*
    app.include_router(comparison.router)  # /api/v2/comparison
    app.include_router(testing.router)  # /api/v2/testing/*
    app.include_router(logs.router)  # /api/v2/logs


def create_app() -> FastAPI:
    """Create and configure the FastAPI application.

    Returns:
        Configured FastAPI application instance.
    """
    settings = get_settings()

    app = FastAPI(
        title=settings.app_name,
        docs_url="/docs" if settings.debug else "/docs",  # Always expose docs for API-only backend
        lifespan=lifespan,
    )

    # Configure middleware (order matters: CORS must be first)
    _configure_middleware(app, settings)
    _add_request_logging(app)

    # Register routes
    _register_routers(app)

    if settings.dev_proxy:
        logger.info("Dev proxy enabled — proxying non-API requests to Vite dev server")
        app.add_middleware(ViteDevProxyMiddleware)

    return app


# Create the application instance for uvicorn
app = create_app()


# ---------------------------------------------------------------------------
# Helpers (used by deps.py)
# ---------------------------------------------------------------------------


def cache_invalidate() -> None:
    """Invalidate all cached query results.

    Called by routes after data modifications to ensure fresh data.
    """
    from backend.services.cache import get_async_cache

    get_async_cache().invalidate()
