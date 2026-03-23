"""Unit tests for settings API endpoints."""

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
class TestSettingsV2:
    """Test GET /api/v2/settings endpoint."""

    @patch("backend.api.routes.settings.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.get_database")
    def test_settings_returns_defaults(self, mock_db, mock_query) -> None:
        """Test settings endpoint returns default values when config is empty."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.return_value = []
        resp = client.get("/api/v2/settings")
        assert resp.status_code == 200
        data = resp.json()

        # Check structure
        assert "weights" in data
        assert "thresholds" in data
        assert "performance" in data
        assert "cost" in data
        assert "automation" in data

        # Check default values
        assert data["weights"]["cortexSearch"] == 0.3
        assert data["weights"]["cosine"] == 0.3
        assert data["thresholds"]["autoAccept"] == 0.85
        assert data["performance"]["batchSize"] == 1000
        assert data["automation"]["autoAcceptEnabled"] is True

    @patch("backend.api.routes.settings.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.get_database")
    def test_settings_uses_config_values(self, mock_db, mock_query) -> None:
        """Test settings endpoint uses values from CONFIG table."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.return_value = [
            {"CONFIG_KEY": "ENSEMBLE_WEIGHT_SEARCH", "CONFIG_VALUE": "0.4"},
            {"CONFIG_KEY": "ENSEMBLE_WEIGHT_COSINE", "CONFIG_VALUE": "0.35"},
            {"CONFIG_KEY": "AUTO_ACCEPT_THRESHOLD", "CONFIG_VALUE": "0.9"},
            {"CONFIG_KEY": "DEFAULT_BATCH_SIZE", "CONFIG_VALUE": "500"},
            {"CONFIG_KEY": "AGENTIC_ENABLED", "CONFIG_VALUE": "false"},
        ]
        resp = client.get("/api/v2/settings")
        assert resp.status_code == 200
        data = resp.json()

        assert data["weights"]["cortexSearch"] == 0.4
        assert data["weights"]["cosine"] == 0.35
        assert data["thresholds"]["autoAccept"] == 0.9
        assert data["performance"]["batchSize"] == 500
        assert data["automation"]["autoAcceptEnabled"] is False

    @patch("backend.api.routes.settings.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.get_database")
    def test_settings_handles_query_error(self, mock_db, mock_query) -> None:
        """Test settings endpoint handles query errors gracefully."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = Exception("Query failed")
        resp = client.get("/api/v2/settings")
        assert resp.status_code == 200
        data = resp.json()
        # Should return defaults when query fails
        assert data["weights"]["cortexSearch"] == 0.3
