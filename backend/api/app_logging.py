"""Application logging with in-memory circular buffer for API observability.

Provides structured logging with fixed-size buffer for runtime diagnostics,
request correlation, and client error reporting.
"""

from __future__ import annotations

import logging
from collections import deque
from datetime import UTC, datetime
from threading import Lock
from typing import Any, Literal

from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

# Default buffer size (matches prompt_forge_v2 DEFAULT_LOG_BUFFER_SIZE)
DEFAULT_LOG_BUFFER_SIZE = 1000

LogLevel = Literal["debug", "info", "warn", "error"]


# ---------------------------------------------------------------------------
# Log Entry Models
# ---------------------------------------------------------------------------


class AppLogEntry(BaseModel):
    """Structured log entry for application events.

    Captures timestamp, level, message, and optional structured metadata
    for debugging and observability.
    """

    timestamp: str = Field(description="ISO 8601 timestamp with timezone")
    level: LogLevel = Field(description="Log severity level")
    message: str = Field(description="Human-readable log message")
    data: dict[str, Any] | None = Field(default=None, description="Optional structured metadata")


class ClientErrorReport(BaseModel):
    """Client-side error report submitted to backend for centralized logging.

    Allows frontend to report render errors, validation failures, and
    unexpected client-side exceptions for debugging.
    """

    error_type: str = Field(description="Error type or name")
    message: str = Field(description="Error message")
    stack: str | None = Field(default=None, description="Stack trace if available")
    user_agent: str | None = Field(default=None, description="Browser user agent string")
    url: str | None = Field(default=None, description="URL where error occurred")
    context: dict[str, Any] | None = Field(default=None, description="Additional error context")


# ---------------------------------------------------------------------------
# Circular Log Buffer
# ---------------------------------------------------------------------------


class LogBuffer:
    """Thread-safe circular buffer for application logs.

    Maintains a fixed-size buffer of log entries with automatic eviction
    of oldest entries when capacity is reached. Supports filtering by level
    and time range for API access.

    Adapted from prompt_forge_v2/src/lib/log-buffer.ts for Python/FastAPI.
    """

    def __init__(self, max_size: int = DEFAULT_LOG_BUFFER_SIZE):
        """Initialize log buffer with specified capacity.

        Args:
            max_size: Maximum number of log entries to retain
        """
        self._buffer: deque[AppLogEntry] = deque(maxlen=max_size)
        self._lock = Lock()
        self._max_size = max_size

    def log(self, level: LogLevel, message: str, data: dict[str, Any] | None = None) -> None:
        """Add a log entry to the buffer.

        Thread-safe. Automatically evicts oldest entry if buffer is full.

        Args:
            level: Log severity level
            message: Human-readable message
            data: Optional structured metadata
        """
        entry = AppLogEntry(
            timestamp=datetime.now(UTC).isoformat(),
            level=level,
            message=message,
            data=data,
        )

        with self._lock:
            self._buffer.append(entry)

        # Also emit to Python logger for backend observability
        python_level = "warning" if level == "warn" else level
        log_fn = getattr(logging.getLogger("retail_harmonizer.app"), python_level)
        if data:
            log_fn("%s — %s", message, data)
        else:
            log_fn("%s", message)

    def debug(self, message: str, data: dict[str, Any] | None = None) -> None:
        """Log at debug level."""
        self.log("debug", message, data)

    def info(self, message: str, data: dict[str, Any] | None = None) -> None:
        """Log at info level."""
        self.log("info", message, data)

    def warn(self, message: str, data: dict[str, Any] | None = None) -> None:
        """Log at warn level."""
        self.log("warn", message, data)

    def error(self, message: str, data: dict[str, Any] | None = None) -> None:
        """Log at error level."""
        self.log("error", message, data)

    def get_recent(
        self,
        limit: int = 100,
        level: LogLevel | None = None,
        since: str | None = None,
    ) -> list[AppLogEntry]:
        """Retrieve recent log entries with optional filtering.

        Thread-safe.

        Args:
            limit: Maximum number of entries to return
            level: Optional level filter (exact match)
            since: Optional ISO timestamp - return entries after this time

        Returns:
            List of log entries in chronological order (oldest first)
        """
        with self._lock:
            entries = list(self._buffer)

        # Apply filters
        if level:
            entries = [e for e in entries if e.level == level]

        if since:
            entries = [e for e in entries if e.timestamp > since]

        # Return most recent entries up to limit
        return entries[-limit:]

    def clear(self) -> None:
        """Clear all log entries from the buffer.

        Thread-safe. Use for testing or administrative operations only.
        """
        with self._lock:
            self._buffer.clear()

    def size(self) -> int:
        """Return current number of entries in the buffer.

        Thread-safe.
        """
        with self._lock:
            return len(self._buffer)


# ---------------------------------------------------------------------------
# Global Log Buffer Instance
# ---------------------------------------------------------------------------

# Singleton buffer instance for application-wide logging
_app_log_buffer = LogBuffer(max_size=DEFAULT_LOG_BUFFER_SIZE)


def get_app_log_buffer() -> LogBuffer:
    """Get the global application log buffer instance.

    Returns:
        Singleton LogBuffer instance
    """
    return _app_log_buffer


# ---------------------------------------------------------------------------
# Convenience Logger Functions
# ---------------------------------------------------------------------------


def log_request_error(request_id: str, endpoint: str, error_category: str, message: str) -> None:
    """Log an API request error with structured context.

    Args:
        request_id: Request correlation ID
        endpoint: API endpoint path
        error_category: Classified error category
        message: Error message
    """
    _app_log_buffer.error(
        f"Request failed: {endpoint}",
        data={
            "request_id": request_id,
            "endpoint": endpoint,
            "category": error_category,
            "message": message,
        },
    )


def log_client_error(report: ClientErrorReport, request_id: str) -> None:
    """Log a client-side error report with structured context.

    Args:
        report: Client error report from frontend
        request_id: Request correlation ID from the report submission
    """
    _app_log_buffer.error(
        f"Client error: {report.error_type}",
        data={
            "request_id": request_id,
            "error_type": report.error_type,
            "message": report.message,
            "url": report.url,
            "user_agent": report.user_agent,
            "context": report.context,
            # Omit stack from structured data to keep buffer size manageable
            # Stack is available in the report object for detailed inspection
        },
    )
