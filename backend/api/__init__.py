"""Retail Data Harmonizer – FastAPI backend (JSON API v2 only).

REST API backend for the React frontend with Snowflake integration.
Instrumented with Snowflake native telemetry for distributed tracing.
"""

from __future__ import annotations

import asyncio
import logging
import time
import uuid
from contextlib import asynccontextmanager

# Snowflake native telemetry for distributed tracing
from typing import Any

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from backend.api import snowflake_client as sf
from backend.api.config import Settings, get_settings
from backend.api.dev_proxy import ViteDevProxyMiddleware
from backend.api.errors import AppError, ErrorEnvelope, classify_snowflake_error

try:
    from snowflake import telemetry as _telemetry

    telemetry: Any = _telemetry
    TELEMETRY_AVAILABLE = hasattr(telemetry, "create_span")
except ImportError:
    telemetry = None
    TELEMETRY_AVAILABLE = False

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
    """Add request timing, telemetry, and request ID middleware."""

    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        """Log requests and create telemetry spans for distributed tracing."""
        # Generate request ID for correlation
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id

        start = time.perf_counter()

        if TELEMETRY_AVAILABLE and telemetry is not None:
            with telemetry.create_span(f"api_{request.url.path.replace('/', '_')}") as span:  # type: ignore[union-attr]
                span.set_attribute("http.method", request.method)
                span.set_attribute("http.path", request.url.path)
                span.set_attribute("request.id", request_id)
                response = await call_next(request)
                span.set_attribute("http.status_code", response.status_code)
                elapsed_ms = (time.perf_counter() - start) * 1000
                span.set_attribute("duration_ms", elapsed_ms)
        else:
            response = await call_next(request)
            elapsed_ms = (time.perf_counter() - start) * 1000

        # Add request ID to response headers for client correlation
        response.headers["X-Request-ID"] = request_id

        logger.info(
            "%s %s — %d (%.1fms) [%s]",
            request.method,
            request.url.path,
            response.status_code,
            elapsed_ms,
            request_id,
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


def _add_exception_handlers(app: FastAPI) -> None:
    """Register global exception handlers for structured error responses."""

    @app.exception_handler(AppError)
    async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
        """Handle application-level errors with structured envelopes."""
        logger.warning(
            "AppError [%s]: %s (request_id=%s, error_id=%s)",
            exc.envelope.category,
            exc.envelope.message,
            exc.envelope.request_id,
            exc.envelope.error_id,
        )
        return JSONResponse(
            status_code=exc.status_code,
            content=exc.envelope.model_dump(),
        )

    @app.exception_handler(ValidationError)
    async def validation_error_handler(request: Request, exc: ValidationError) -> JSONResponse:
        """Handle Pydantic validation errors."""
        request_id = getattr(request.state, "request_id", "unknown")
        error_id = str(uuid.uuid4())

        envelope = ErrorEnvelope(
            error_id=error_id,
            request_id=request_id,
            category="validation",
            severity="error",
            title="Validation Error",
            message="The request data failed validation checks.",
            actions=[
                "Review the request data format",
                "Check that all required fields are provided",
                "Verify field types match the API schema",
            ],
            retryable=False,
            technical_details=str(exc),
            source="api",
        )

        logger.warning("ValidationError: %s (request_id=%s)", exc, request_id)

        return JSONResponse(status_code=422, content=envelope.model_dump())

    @app.exception_handler(Exception)
    async def unhandled_error_handler(request: Request, exc: Exception) -> JSONResponse:
        """Handle unhandled exceptions with structured envelopes.

        Classifies Snowflake exceptions using the pattern catalog.
        Other exceptions are treated as internal server errors.
        """
        request_id = getattr(request.state, "request_id", "unknown")

        # Check if this is a Snowflake exception
        exc_type_name = type(exc).__module__
        if "snowflake" in exc_type_name.lower():
            # Classify Snowflake error
            envelope = classify_snowflake_error(exc, request_id=request_id)
            status_code = 503  # Service Unavailable for Snowflake connectivity issues
            logger.error(
                "Snowflake error [%s]: %s (request_id=%s, error_id=%s)",
                envelope.category,
                str(exc),
                request_id,
                envelope.error_id,
                exc_info=True,
            )
        else:
            # Generic internal server error
            error_id = str(uuid.uuid4())
            envelope = ErrorEnvelope(
                error_id=error_id,
                request_id=request_id,
                category="server",
                severity="critical",
                title="Internal Server Error",
                message="An unexpected error occurred while processing your request.",
                actions=[
                    "Try the operation again",
                    "Contact support if the issue persists",
                    f"Reference error ID: {error_id}",
                ],
                retryable=True,
                technical_details=f"{type(exc).__name__}: {str(exc)}",
                source="api",
            )
            status_code = 500
            logger.error(
                "Unhandled exception: %s (request_id=%s, error_id=%s)",
                exc,
                request_id,
                error_id,
                exc_info=True,
            )

        return JSONResponse(status_code=status_code, content=envelope.model_dump())


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

    # Register exception handlers
    _add_exception_handlers(app)

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
