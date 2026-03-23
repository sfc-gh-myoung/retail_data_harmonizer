"""Base service class and shared utilities for service layer.

Provides common functionality for all domain services including SQL escaping,
sort validation, and filter clause building.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING, Any, Protocol

if TYPE_CHECKING:
    from backend.services.cache import SyncTTLCache, TTLCache


class SnowflakeClientProtocol(Protocol):
    """Protocol for Snowflake client dependency."""

    async def query(self, sql: str) -> list[dict[str, Any]]:
        """Execute a query and return results."""
        ...

    async def execute(self, sql: str) -> str:
        """Execute a statement and return status."""
        ...


@dataclass
class BaseService:
    """Base class for all domain services.

    Provides shared utilities for SQL operations and caching.
    Services inherit from this to gain access to common helpers.

    Attributes:
        db_name: Database name for fully qualified object references.
        sf: Snowflake client for query execution.
        cache: Optional TTL cache for query results.
    """

    db_name: str
    sf: SnowflakeClientProtocol
    cache: TTLCache | SyncTTLCache | None = None

    def _safe(self, value: str) -> str:
        """Escape single-quotes for safe SQL interpolation.

        Args:
            value: String value to escape.

        Returns:
            Escaped string safe for SQL interpolation.
        """
        return value.replace("'", "''")

    def _validate_sort(
        self,
        sort_col: str,
        sort_dir: str,
        allowed: set[str],
        default_col: str,
    ) -> tuple[str, str]:
        """Validate and return safe sort parameters.

        Args:
            sort_col: Column name from request.
            sort_dir: Sort direction from request (ASC/DESC).
            allowed: Set of allowed column names.
            default_col: Default column if sort_col is invalid.

        Returns:
            Tuple of (validated_col, validated_dir).
        """
        if sort_col not in allowed:
            sort_col = default_col
        sort_dir = "DESC" if sort_dir.upper() == "DESC" else "ASC"
        return sort_col, sort_dir

    def _build_filter_clause(
        self,
        filters: dict[str, str],
        column_map: dict[str, str],
    ) -> str:
        """Build WHERE clause from filters.

        Args:
            filters: Dict of filter param names to their values.
            column_map: Dict mapping param names to SQL column names.

        Returns:
            WHERE clause string (always starts with '1=1').
        """
        clauses = ["1=1"]
        for param, col in column_map.items():
            value = filters.get(param)
            if value and value != "All":
                clauses.append(f"{col} = '{self._safe(value)}'")
        return " AND ".join(clauses)


# ---------------------------------------------------------------------------
# Module-level utility functions (for testing and standalone use)
# ---------------------------------------------------------------------------


def _safe(value: str) -> str:
    """Escape single-quotes for safe SQL interpolation."""
    return value.replace("'", "''")


def _validate_sort(
    sort_col: str,
    sort_dir: str,
    allowed: set[str],
    default_col: str,
) -> tuple[str, str]:
    """Validate and return safe sort parameters."""
    if sort_col not in allowed:
        sort_col = default_col
    sort_dir = "DESC" if sort_dir.upper() == "DESC" else "ASC"
    return sort_col, sort_dir


def _build_filter_clause(
    filters: dict[str, str],
    column_map: dict[str, str],
) -> str:
    """Build WHERE clause from filters."""
    clauses = ["1=1"]
    for param, col in column_map.items():
        value = filters.get(param)
        if value and value != "All":
            clauses.append(f"{col} = '{_safe(value)}'")
    return " AND ".join(clauses)
