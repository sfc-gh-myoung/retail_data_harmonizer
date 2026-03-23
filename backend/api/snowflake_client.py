"""Snowflake query helper for the FastAPI UI.

Thin async wrapper around the dual-mode core client.
Supports both `snow` CLI (local dev) and Snowpark Session (SPCS).
Includes in-memory caching to reduce redundant queries.
"""

from __future__ import annotations

import hashlib
import logging
import time
from typing import Any

from backend.snowflake import get_client

try:
    from snowflake import telemetry

    TELEMETRY_AVAILABLE = hasattr(telemetry, "create_span")
except ImportError:
    TELEMETRY_AVAILABLE = False
    telemetry = None  # type: ignore[assignment]

logger = logging.getLogger("retail_harmonizer.api.snowflake")

# ---------------------------------------------------------------------------
# Simple in-memory cache with TTL
# ---------------------------------------------------------------------------

_cache: dict[str, tuple[float, Any]] = {}
DEFAULT_CACHE_TTL = 5.0  # seconds


def _cache_key(sql: str) -> str:
    """Generate a cache key from SQL (normalized)."""
    normalized = " ".join(sql.split()).strip().upper()
    return hashlib.md5(normalized.encode(), usedforsecurity=False).hexdigest()


def _get_cached(key: str) -> tuple[bool, Any]:
    """Return (hit, value) from cache if not expired."""
    if key in _cache:
        expires, value = _cache[key]
        if time.time() < expires:
            return True, value
        del _cache[key]
    return False, None


def _set_cached(key: str, value: Any, ttl: float = DEFAULT_CACHE_TTL) -> None:
    """Store value in cache with TTL."""
    _cache[key] = (time.time() + ttl, value)


def clear_cache() -> None:
    """Clear all cached query results."""
    _cache.clear()


# Aliases for backward compatibility with tests
def _cache_get(key: str) -> Any | None:
    """Get a value from cache by key (returns None if not found/expired)."""
    hit, value = _get_cached(key)
    return value if hit else None


def _cache_set(key: str, value: Any, ttl: float = DEFAULT_CACHE_TTL) -> None:
    """Store value in cache with TTL (alias for _set_cached)."""
    _set_cached(key, value, ttl)


def cache_invalidate() -> None:
    """Invalidate all cached data (alias for clear_cache)."""
    _cache.clear()


# ---------------------------------------------------------------------------
# Module-level config (kept for backward compat with existing app code)
# ---------------------------------------------------------------------------

_connection: str = "default"
_database: str = "HARMONIZER_DEMO"


def configure(connection: str = "default", database: str = "HARMONIZER_DEMO") -> None:
    """Set the Snowflake connection and database for all queries."""
    global _connection, _database  # noqa: PLW0603
    _connection = connection
    _database = database
    # Reset cached client so it picks up new config
    from backend.snowflake import reset_client

    reset_client()


def get_database() -> str:
    """Return the configured database name."""
    return _database


def _client():
    return get_client(connection=_connection, database=_database)


async def query(sql: str, *, cache_ttl: float | None = DEFAULT_CACHE_TTL) -> list[dict[str, Any]]:
    """Execute a SQL query and return rows as dicts.

    Args:
        sql: The SQL query to execute.
        cache_ttl: Cache TTL in seconds. Set to None or 0 to bypass cache.

    Instrumented with Snowflake native telemetry spans for distributed tracing.
    """
    start = time.perf_counter()
    sql_preview = " ".join(sql.split())[:120]

    # Check cache first (if caching enabled)
    key = _cache_key(sql)
    if cache_ttl:
        hit, cached_rows = _get_cached(key)
        if hit:
            elapsed_ms = (time.perf_counter() - start) * 1000
            logger.debug("QUERY (cached) — %d rows (%.1fms): %s", len(cached_rows), elapsed_ms, sql_preview)
            return cached_rows

    logger.debug("QUERY: %s …", sql_preview)

    rows = await _client().async_query(sql)

    elapsed_ms = (time.perf_counter() - start) * 1000
    logger.debug("QUERY OK — %d rows (%.1fms)", len(rows), elapsed_ms)

    # Cache the result
    if cache_ttl:
        _set_cached(key, rows, cache_ttl)

    return rows


async def fetch_one(sql: str, *, cache_ttl: float | None = DEFAULT_CACHE_TTL) -> dict[str, Any] | None:
    """Execute a SQL query and return the first row as a dict, or None if no results.

    Args:
        sql: The SQL query to execute.
        cache_ttl: Cache TTL in seconds. Set to None or 0 to bypass cache.
    """
    rows = await query(sql, cache_ttl=cache_ttl)
    return rows[0] if rows else None


async def execute(sql: str) -> str:
    """Execute a SQL statement and return raw output.

    Executes DDL/DML statements (INSERT, UPDATE, DELETE, CALL, ALTER, etc.)
    that do not return row data. Not cached.

    Args:
        sql: The SQL statement to execute.

    Returns:
        Raw string output from Snowflake execution (typically status message).

    Side Effects:
        - Executes SQL against Snowflake (network I/O)
        - May modify database state (INSERT, UPDATE, DELETE, ALTER)
        - Emits debug logs with statement preview and timing
    """
    start = time.perf_counter()
    sql_preview = " ".join(sql.split())[:120]
    logger.debug("EXEC: %s …", sql_preview)

    result = await _client().async_execute(sql)

    elapsed_ms = (time.perf_counter() - start) * 1000
    logger.debug("EXEC OK (%.1fms)", elapsed_ms)
    return result


async def test_connection() -> bool:
    """Test the Snowflake connection."""
    try:
        rows = await query("SELECT 'ok' AS status")
        return len(rows) > 0
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Protocol-compliant wrapper for dependency injection
# ---------------------------------------------------------------------------


class SnowflakeClientWrapper:
    """Wrapper class that implements SnowflakeClientProtocol.

    Delegates to module-level functions for use with service layer dependency injection.
    """

    async def query(self, sql: str) -> list[dict[str, Any]]:
        """Execute a query and return results."""
        return await query(sql, cache_ttl=None)

    async def execute(self, sql: str) -> str:
        """Execute a statement and return status."""
        return await execute(sql)


# Singleton instance for dependency injection
_client_wrapper: SnowflakeClientWrapper | None = None


def get_client_wrapper() -> SnowflakeClientWrapper:
    """Get the singleton client wrapper for service injection."""
    global _client_wrapper
    if _client_wrapper is None:
        _client_wrapper = SnowflakeClientWrapper()
    return _client_wrapper
