"""App-level logging endpoints for runtime diagnostics and client error reporting.

Provides REST API access to the in-memory application log buffer for debugging,
monitoring, and client-side error collection.
"""

from __future__ import annotations

import logging
from typing import Annotated

from fastapi import APIRouter, Body, Query, Request

from backend.api.app_logging import (
    AppLogEntry,
    ClientErrorReport,
    LogLevel,
    get_app_log_buffer,
    log_client_error,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# App Log Retrieval Endpoints
# ---------------------------------------------------------------------------


@router.get("/app", response_model=list[AppLogEntry])
async def get_app_logs(
    limit: Annotated[int, Query(ge=1, le=1000, description="Maximum entries to return")] = 100,
    level: Annotated[LogLevel | None, Query(description="Filter by log level")] = None,
    since: Annotated[
        str | None,
        Query(description="ISO timestamp - return entries after this time"),
    ] = None,
) -> list[AppLogEntry]:
    """Get recent application log entries with optional filtering.

    Returns logs from the in-memory circular buffer for debugging and monitoring.
    Logs are automatically evicted after buffer capacity (1000 entries) is reached.

    Args:
        limit: Maximum number of entries to return (default: 100, max: 1000)
        level: Optional level filter (debug, info, warn, error)
        since: Optional ISO timestamp for time-based filtering

    Returns:
        List of log entries in chronological order (oldest first)
    """
    buffer = get_app_log_buffer()
    entries = buffer.get_recent(limit=limit, level=level, since=since)

    logger.debug(
        "App logs retrieved: %d entries (limit=%d, level=%s, since=%s)",
        len(entries),
        limit,
        level,
        since,
    )

    return entries


# ---------------------------------------------------------------------------
# Client Error Reporting Endpoint
# ---------------------------------------------------------------------------


@router.post("/app/client-error", status_code=202)
async def report_client_error(
    request: Request,
    report: Annotated[ClientErrorReport, Body()],
) -> dict[str, str]:
    """Accept client-side error reports for centralized logging.

    Allows frontend to submit render errors, validation failures, and
    unexpected exceptions for backend debugging. Reports are added to the
    app log buffer with 'error' level.

    Args:
        request: FastAPI request (provides request_id from middleware)
        report: Client error report with type, message, stack, and context

    Returns:
        Acknowledgment with request ID
    """
    request_id = getattr(request.state, "request_id", "unknown")

    # Log to app buffer
    log_client_error(report, request_id)

    logger.info(
        "Client error reported: %s (request_id=%s, url=%s)",
        report.error_type,
        request_id,
        report.url,
    )

    return {"status": "accepted", "request_id": request_id}
