"""FastAPI utility tests — TTLCache, helper functions, and cache utilities.

Route tests have been moved to:
- tests/api/test_system.py (health, status)
- tests/api/test_pipeline.py (pipeline endpoints)
- tests/api/test_settings.py (settings endpoints)

This file contains only utility/infrastructure tests.
"""

from __future__ import annotations

import asyncio

import pytest

# ---------------------------------------------------------------------------
# TTL Cache Tests
# ---------------------------------------------------------------------------


class TestTTLCache:
    """Test the TTLCache utility class."""

    @pytest.mark.asyncio
    async def test_cache_miss_then_hit(self) -> None:
        """First call is a miss, second is a hit."""
        from backend.services.cache import TTLCache

        cache = TTLCache()
        call_count = 0

        async def fetch_fn():
            nonlocal call_count
            call_count += 1
            return "result"

        # First call - miss
        result1 = await cache.get_or_fetch("key1", 60.0, fetch_fn)
        assert result1 == "result"
        assert call_count == 1

        # Second call - hit (should not call fetch_fn again)
        result2 = await cache.get_or_fetch("key1", 60.0, fetch_fn)
        assert result2 == "result"
        assert call_count == 1  # Still 1, no new fetch

    @pytest.mark.asyncio
    async def test_cache_expiry(self) -> None:
        """Expired cache entries trigger new fetch."""
        from backend.services.cache import TTLCache

        cache = TTLCache()
        call_count = 0

        async def fetch_fn():
            nonlocal call_count
            call_count += 1
            return f"result_{call_count}"

        # First call with very short TTL
        result1 = await cache.get_or_fetch("key1", 0.001, fetch_fn)
        assert result1 == "result_1"

        # Wait for expiry
        await asyncio.sleep(0.01)

        # Second call should fetch again (expired)
        result2 = await cache.get_or_fetch("key1", 60.0, fetch_fn)
        assert result2 == "result_2"
        assert call_count == 2

    def test_cache_invalidate_key(self) -> None:
        """Invalidate specific key."""
        from backend.services.cache import TTLCache

        cache = TTLCache()
        cache._cache["key1"] = (float("inf"), "value1")
        cache._cache["key2"] = (float("inf"), "value2")

        cache.invalidate("key1")

        assert "key1" not in cache._cache
        assert "key2" in cache._cache

    def test_cache_invalidate_all(self) -> None:
        """Invalidate entire cache."""
        from backend.services.cache import TTLCache

        cache = TTLCache()
        cache._cache["key1"] = (float("inf"), "value1")
        cache._cache["key2"] = (float("inf"), "value2")

        cache.invalidate()  # No key = clear all

        assert len(cache._cache) == 0


# ---------------------------------------------------------------------------
# Helper Function Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestHelperFunctions:
    """Test helper functions for SQL safety and validation."""

    def test_safe_escapes_single_quotes(self) -> None:
        """Test _safe escapes single quotes."""
        from backend.services.base import _safe

        assert _safe("O'Brien") == "O''Brien"
        assert _safe("test") == "test"
        assert _safe("it's a test's test") == "it''s a test''s test"

    def test_validate_sort_valid_column(self) -> None:
        """Test _validate_sort with valid column."""
        from backend.services.base import _validate_sort

        col, dir = _validate_sort("name", "ASC", {"name", "date"}, "name")
        assert col == "name"
        assert dir == "ASC"

    def test_validate_sort_invalid_column_uses_default(self) -> None:
        """Test _validate_sort falls back to default for invalid column."""
        from backend.services.base import _validate_sort

        col, dir = _validate_sort("invalid", "ASC", {"name", "date"}, "name")
        assert col == "name"

    def test_validate_sort_normalizes_direction(self) -> None:
        """Test _validate_sort normalizes direction to ASC/DESC."""
        from backend.services.base import _validate_sort

        col, dir = _validate_sort("name", "desc", {"name"}, "name")
        assert dir == "DESC"
        col, dir = _validate_sort("name", "invalid", {"name"}, "name")
        assert dir == "ASC"

    def test_build_filter_clause_with_filters(self) -> None:
        """Test _build_filter_clause builds WHERE clause."""
        from backend.services.base import _build_filter_clause

        result = _build_filter_clause(
            {"status": "CONFIRMED", "source": "All"},
            {"status": "STATUS_COL", "source": "SOURCE_COL"},
        )
        assert "1=1" in result
        assert "STATUS_COL = 'CONFIRMED'" in result
        assert "SOURCE_COL" not in result  # 'All' is skipped

    def test_build_filter_clause_empty_filters(self) -> None:
        """Test _build_filter_clause with no active filters."""
        from backend.services.base import _build_filter_clause

        result = _build_filter_clause({}, {})
        assert result == "1=1"


# ---------------------------------------------------------------------------
# Simple Cache Tests
# ---------------------------------------------------------------------------


class TestSimpleCache:
    """Test the simple module-level cache functions."""

    def test_cache_get_set(self) -> None:
        """Test _cache_get and _cache_set."""
        from backend.api.snowflake_client import _cache, _cache_get, _cache_set

        # Clear cache first
        _cache.clear()

        # Test cache miss
        assert _cache_get("test_key") is None

        # Test cache set and hit
        _cache_set("test_key", {"data": "test"})
        result = _cache_get("test_key")
        assert result == {"data": "test"}

    def test_cache_invalidate(self) -> None:
        """Test cache_invalidate clears cache."""
        from backend.api.snowflake_client import _cache, _cache_set, cache_invalidate

        _cache_set("key1", "value1")
        _cache_set("key2", "value2")

        cache_invalidate()
        assert len(_cache) == 0
