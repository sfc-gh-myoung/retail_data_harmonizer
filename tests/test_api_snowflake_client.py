"""Tests for api/snowflake_client.py — FastAPI Snowflake helper.

Tests the async query wrapper with mocked core client.
"""

from __future__ import annotations

import time
from unittest.mock import AsyncMock, patch

import pytest

from backend.api import snowflake_client as sf

# ---------------------------------------------------------------------------
# Cache Tests
# ---------------------------------------------------------------------------


class TestCache:
    """Test in-memory cache functionality."""

    def setup_method(self) -> None:
        """Clear cache before each test."""
        sf.clear_cache()

    def teardown_method(self) -> None:
        """Clear cache after each test."""
        sf.clear_cache()

    def test_cache_key_normalization(self) -> None:
        """Cache keys are normalized (whitespace, case)."""
        key1 = sf._cache_key("SELECT   1")
        key2 = sf._cache_key("select 1")
        assert key1 == key2

    def test_get_cached_miss(self) -> None:
        """Returns (False, None) for cache miss."""
        hit, value = sf._get_cached("nonexistent_key")
        assert hit is False
        assert value is None

    def test_set_and_get_cached(self) -> None:
        """Can store and retrieve cached values."""
        sf._set_cached("test_key", [{"data": "value"}], ttl=10.0)
        hit, value = sf._get_cached("test_key")
        assert hit is True
        assert value == [{"data": "value"}]

    def test_cache_expiry(self) -> None:
        """Cached values expire after TTL."""
        sf._set_cached("expire_key", "test_value", ttl=0.01)
        time.sleep(0.02)
        hit, value = sf._get_cached("expire_key")
        assert hit is False

    def test_clear_cache(self) -> None:
        """clear_cache removes all cached values."""
        sf._set_cached("key1", "value1")
        sf._set_cached("key2", "value2")
        sf.clear_cache()
        hit1, _ = sf._get_cached("key1")
        hit2, _ = sf._get_cached("key2")
        assert hit1 is False
        assert hit2 is False


# ---------------------------------------------------------------------------
# Configuration Tests
# ---------------------------------------------------------------------------


class TestConfigure:
    """Test module configuration."""

    def test_configure_sets_values(self) -> None:
        """configure() sets connection and database."""
        with patch("backend.snowflake.reset_client"):
            sf.configure(connection="test_conn", database="TEST_DB")
            assert sf._connection == "test_conn"
            assert sf._database == "TEST_DB"
            # Reset to defaults
            sf.configure()

    def test_get_database(self) -> None:
        """get_database() returns configured database."""
        with patch("backend.snowflake.reset_client"):
            sf.configure(database="MY_DB")
            assert sf.get_database() == "MY_DB"
            sf.configure()


# ---------------------------------------------------------------------------
# Query Tests
# ---------------------------------------------------------------------------


class TestQuery:
    """Test async query function."""

    def setup_method(self) -> None:
        """Clear cache before each test."""
        sf.clear_cache()

    @pytest.mark.asyncio
    @patch("backend.api.snowflake_client._client")
    async def test_query_success(self, mock_client) -> None:
        """Query returns results from client."""
        mock_client.return_value.async_query = AsyncMock(return_value=[{"COL1": "value1"}])
        result = await sf.query("SELECT 1", cache_ttl=None)
        assert result == [{"COL1": "value1"}]

    @pytest.mark.asyncio
    @patch("backend.api.snowflake_client._client")
    async def test_query_caches_result(self, mock_client) -> None:
        """Query caches results for subsequent calls."""
        mock_client.return_value.async_query = AsyncMock(return_value=[{"COL1": "value1"}])
        # First call - hits database
        result1 = await sf.query("SELECT 1", cache_ttl=10.0)
        # Second call - should hit cache
        result2 = await sf.query("SELECT 1", cache_ttl=10.0)

        assert result1 == result2
        # Should only call database once
        assert mock_client.return_value.async_query.call_count == 1

    @pytest.mark.asyncio
    @patch("backend.api.snowflake_client._client")
    async def test_query_bypasses_cache_when_disabled(self, mock_client) -> None:
        """Query bypasses cache when cache_ttl=None."""
        mock_client.return_value.async_query = AsyncMock(return_value=[{"COL1": "value1"}])
        # Call twice with cache disabled
        await sf.query("SELECT 1", cache_ttl=None)
        await sf.query("SELECT 1", cache_ttl=None)

        # Should call database twice
        assert mock_client.return_value.async_query.call_count == 2


# ---------------------------------------------------------------------------
# FetchOne Tests
# ---------------------------------------------------------------------------


class TestFetchOne:
    """Test fetch_one helper function."""

    def setup_method(self) -> None:
        """Clear cache before each test."""
        sf.clear_cache()

    @pytest.mark.asyncio
    @patch("backend.api.snowflake_client._client")
    async def test_fetch_one_returns_first_row(self, mock_client) -> None:
        """fetch_one returns the first row."""
        mock_client.return_value.async_query = AsyncMock(return_value=[{"COL1": "first"}, {"COL1": "second"}])
        result = await sf.fetch_one("SELECT 1", cache_ttl=None)
        assert result == {"COL1": "first"}

    @pytest.mark.asyncio
    @patch("backend.api.snowflake_client._client")
    async def test_fetch_one_returns_none_for_empty(self, mock_client) -> None:
        """fetch_one returns None for empty result."""
        mock_client.return_value.async_query = AsyncMock(return_value=[])
        result = await sf.fetch_one("SELECT 1", cache_ttl=None)
        assert result is None


# ---------------------------------------------------------------------------
# Execute Tests
# ---------------------------------------------------------------------------


class TestExecute:
    """Test async execute function."""

    @pytest.mark.asyncio
    @patch("backend.api.snowflake_client._client")
    async def test_execute_success(self, mock_client) -> None:
        """Execute returns result from client."""
        mock_client.return_value.async_execute = AsyncMock(return_value="OK")
        result = await sf.execute("CALL proc()")
        assert result == "OK"


# ---------------------------------------------------------------------------
# Test Connection Tests
# ---------------------------------------------------------------------------


class TestTestConnection:
    """Test connection testing function."""

    def setup_method(self) -> None:
        """Clear cache before each test."""
        sf.clear_cache()

    @pytest.mark.asyncio
    @patch("backend.api.snowflake_client._client")
    async def test_test_connection_success(self, mock_client) -> None:
        """test_connection returns True when query succeeds."""
        mock_client.return_value.async_query = AsyncMock(return_value=[{"status": "ok"}])
        result = await sf.test_connection()
        assert result is True

    @pytest.mark.asyncio
    @patch("backend.api.snowflake_client._client")
    async def test_test_connection_failure(self, mock_client) -> None:
        """test_connection returns False on exception."""
        mock_client.return_value.async_query = AsyncMock(side_effect=Exception("Connection failed"))
        result = await sf.test_connection()
        assert result is False
