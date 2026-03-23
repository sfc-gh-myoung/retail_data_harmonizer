"""Unit tests for system API endpoints."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

# Patch the snowflake_client module before importing the app
with patch("backend.api.snowflake_client") as mock_sf:
    mock_sf.get_database.return_value = "HARMONIZER_DEMO"
    mock_sf.query = AsyncMock(return_value=[])
    mock_sf.execute = AsyncMock(return_value="OK")
    mock_sf.test_connection = AsyncMock(return_value=True)
    from backend.api import app

client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_cache():
    """Clear cache before each test to ensure isolation."""
    from backend.services.cache import get_async_cache, get_sync_cache

    async_cache = get_async_cache()
    sync_cache = get_sync_cache()
    async_cache.invalidate()
    sync_cache.invalidate()
    yield
    async_cache.invalidate()
    sync_cache.invalidate()


@pytest.mark.unit
class TestHealth:
    """Test GET /api/health endpoint."""

    def test_health_returns_ok(self) -> None:
        """Test health endpoint returns status ok."""
        resp = client.get("/api/v2/health")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"


@pytest.mark.unit
class TestStatus:
    """Test GET /api/v2/status endpoint."""

    @patch("backend.api.routes.system.sf.test_connection", new_callable=AsyncMock)
    @patch("backend.api.routes.system.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.system.sf.get_database")
    def test_status_returns_connected(self, mock_db, mock_query, mock_conn) -> None:
        """Test status endpoint returns connection status and tables."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_conn.return_value = True
        mock_query.return_value = [
            {"TABLE_NAME": "ITEM_MATCHES", "ROW_COUNT": 1000},
            {"TABLE_NAME": "MATCH_CANDIDATES", "ROW_COUNT": 5000},
            {"TABLE_NAME": "RAW_RETAIL_ITEMS", "ROW_COUNT": 2000},
            {"TABLE_NAME": "STANDARD_ITEMS", "ROW_COUNT": 500},
        ]
        resp = client.get("/api/v2/status")
        assert resp.status_code == 200
        data = resp.json()
        assert data["connected"] is True
        assert len(data["tables"]) == 4
        assert data["tables"][0]["TABLE_NAME"] == "ITEM_MATCHES"

    @patch("backend.api.routes.system.sf.test_connection", new_callable=AsyncMock)
    @patch("backend.api.routes.system.sf.get_database")
    def test_status_handles_connection_error(self, mock_db, mock_conn) -> None:
        """Test status endpoint handles connection errors gracefully."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_conn.side_effect = Exception("Connection failed")
        resp = client.get("/api/v2/status")
        assert resp.status_code == 200
        data = resp.json()
        assert data["connected"] is False
        assert "Connection failed" in data["error"]
