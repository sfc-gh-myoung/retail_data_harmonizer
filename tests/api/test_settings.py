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
        assert data["thresholds"]["autoAccept"] == 0.75
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
            {"CONFIG_KEY": "AUTO_ACCEPT_ENABLED", "CONFIG_VALUE": "false"},
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


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_VALID_PAYLOAD: dict = {
    "weights": {
        "cortexSearch": 0.4,
        "cosine": 0.3,
        "editDistance": 0.2,
        "jaccard": 0.1,
    },
    "thresholds": {
        "autoAccept": 0.75,
        "reject": 0.45,
        "reviewMin": 0.45,  # derived; sent for completeness
        "reviewMax": 0.75,
    },
    "performance": {"batchSize": 1000, "parallelism": 4, "cacheEnabled": True},
    "automation": {
        "autoAcceptEnabled": True,
        "autoRejectEnabled": False,
        "minAgreementLevel": 2,
    },
}

# What the DB returns after persist (mirrors the payload values).
_PERSISTED_ROWS: list[dict] = [
    {"CONFIG_KEY": "AUTO_ACCEPT_THRESHOLD", "CONFIG_VALUE": "0.75"},
    {"CONFIG_KEY": "AUTO_REJECT_THRESHOLD", "CONFIG_VALUE": "0.45"},
    {"CONFIG_KEY": "ENSEMBLE_WEIGHT_SEARCH", "CONFIG_VALUE": "0.4"},
    {"CONFIG_KEY": "ENSEMBLE_WEIGHT_COSINE", "CONFIG_VALUE": "0.3"},
    {"CONFIG_KEY": "ENSEMBLE_WEIGHT_EDIT", "CONFIG_VALUE": "0.2"},
    {"CONFIG_KEY": "ENSEMBLE_WEIGHT_JACCARD", "CONFIG_VALUE": "0.1"},
    {"CONFIG_KEY": "DEFAULT_BATCH_SIZE", "CONFIG_VALUE": "1000"},
    {"CONFIG_KEY": "CORTEX_PARALLEL_THREADS", "CONFIG_VALUE": "4"},
    {"CONFIG_KEY": "CACHE_ENABLED", "CONFIG_VALUE": "true"},
    {"CONFIG_KEY": "AUTO_ACCEPT_ENABLED", "CONFIG_VALUE": "true"},
    {"CONFIG_KEY": "AUTO_REJECT_ENABLED", "CONFIG_VALUE": "false"},
    {"CONFIG_KEY": "MIN_AGREEMENT_LEVEL", "CONFIG_VALUE": "2"},
]


def _invalid_payload(**overrides) -> dict:
    """Return a deep-copy of _VALID_PAYLOAD with the given nested overrides applied."""
    import copy

    p = copy.deepcopy(_VALID_PAYLOAD)
    for dotted_key, value in overrides.items():
        section, field = dotted_key.split(".", 1)
        p[section][field] = value
    return p


# ---------------------------------------------------------------------------
# POST /api/v2/settings tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestSettingsV2Post:
    """Test POST /api/v2/settings endpoint."""

    @patch("backend.api.routes.settings.sf.execute", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.get_database")
    def test_happy_path_returns_200_with_persisted_values(self, mock_db, mock_query, mock_execute) -> None:
        """Valid body -> 200; response echoes the saved thresholds, weights, and automation."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_execute.return_value = "Statement executed successfully."
        mock_query.return_value = _PERSISTED_ROWS

        resp = client.post("/api/v2/settings", json=_VALID_PAYLOAD)

        assert resp.status_code == 200
        data = resp.json()

        # Thresholds echoed back
        assert data["thresholds"]["autoAccept"] == 0.75
        assert data["thresholds"]["reject"] == 0.45
        # Review band is always derived (reject == reviewMin, accept == reviewMax)
        assert data["thresholds"]["reviewMin"] == 0.45
        assert data["thresholds"]["reviewMax"] == 0.75

        # Weights echoed back
        assert data["weights"]["cortexSearch"] == 0.4
        assert data["weights"]["cosine"] == 0.3
        assert data["weights"]["editDistance"] == 0.2
        assert data["weights"]["jaccard"] == 0.1

        # Automation echoed back
        assert data["automation"]["autoAcceptEnabled"] is True
        assert data["automation"]["autoRejectEnabled"] is False
        assert data["automation"]["minAgreementLevel"] == 2

        # UPDATE_CONFIG must have been called exactly once
        mock_execute.assert_called_once()
        call_sql: str = mock_execute.call_args[0][0]
        assert "UPDATE_CONFIG" in call_sql

    # ------------------------------------------------------------------
    # 422: threshold ordering violations
    # ------------------------------------------------------------------

    @patch("backend.api.routes.settings.sf.execute", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.get_database")
    def test_422_when_reject_equals_autoaccept(self, mock_db, mock_query, mock_execute) -> None:
        """Reject == autoAccept violates strict ordering; must return 422."""
        mock_db.return_value = "HARMONIZER_DEMO"
        payload = _invalid_payload(**{"thresholds.reject": 0.75, "thresholds.reviewMin": 0.75})

        resp = client.post("/api/v2/settings", json=payload)

        assert resp.status_code == 422
        mock_execute.assert_not_called()

    @patch("backend.api.routes.settings.sf.execute", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.get_database")
    def test_422_when_reject_above_autoaccept(self, mock_db, mock_query, mock_execute) -> None:
        """Reject > autoAccept must return 422."""
        mock_db.return_value = "HARMONIZER_DEMO"
        payload = _invalid_payload(**{"thresholds.reject": 0.80, "thresholds.reviewMin": 0.80})

        resp = client.post("/api/v2/settings", json=payload)

        assert resp.status_code == 422
        mock_execute.assert_not_called()

    # ------------------------------------------------------------------
    # 422: minAgreementLevel out of [1, 4]
    # ------------------------------------------------------------------

    @patch("backend.api.routes.settings.sf.execute", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.get_database")
    def test_422_when_min_agreement_level_is_zero(self, mock_db, mock_query, mock_execute) -> None:
        """MinAgreementLevel = 0 is below the minimum of 1; must return 422."""
        mock_db.return_value = "HARMONIZER_DEMO"
        payload = _invalid_payload(**{"automation.minAgreementLevel": 0})

        resp = client.post("/api/v2/settings", json=payload)

        assert resp.status_code == 422
        mock_execute.assert_not_called()

    @patch("backend.api.routes.settings.sf.execute", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.get_database")
    def test_422_when_min_agreement_level_is_five(self, mock_db, mock_query, mock_execute) -> None:
        """MinAgreementLevel = 5 exceeds the maximum of 4; must return 422."""
        mock_db.return_value = "HARMONIZER_DEMO"
        payload = _invalid_payload(**{"automation.minAgreementLevel": 5})

        resp = client.post("/api/v2/settings", json=payload)

        assert resp.status_code == 422
        mock_execute.assert_not_called()

    # ------------------------------------------------------------------
    # 422: weight outside [0, 1]
    # ------------------------------------------------------------------

    @patch("backend.api.routes.settings.sf.execute", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.get_database")
    def test_422_when_weight_exceeds_one(self, mock_db, mock_query, mock_execute) -> None:
        """A weight > 1.0 violates the [0, 1] constraint; must return 422."""
        mock_db.return_value = "HARMONIZER_DEMO"
        payload = _invalid_payload(**{"weights.cortexSearch": 1.5})

        resp = client.post("/api/v2/settings", json=payload)

        assert resp.status_code == 422
        mock_execute.assert_not_called()

    @patch("backend.api.routes.settings.sf.execute", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.get_database")
    def test_422_when_weight_is_negative(self, mock_db, mock_query, mock_execute) -> None:
        """A weight < 0 violates the [0, 1] constraint; must return 422."""
        mock_db.return_value = "HARMONIZER_DEMO"
        payload = _invalid_payload(**{"weights.jaccard": -0.1})

        resp = client.post("/api/v2/settings", json=payload)

        assert resp.status_code == 422
        mock_execute.assert_not_called()

    # ------------------------------------------------------------------
    # Boundary: minAgreementLevel at valid edges (1 and 4)
    # ------------------------------------------------------------------

    @patch("backend.api.routes.settings.sf.execute", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.get_database")
    def test_min_agreement_level_boundary_values_accepted(self, mock_db, mock_query, mock_execute) -> None:
        """MinAgreementLevel = 1 and = 4 are both valid; both must return 200."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_execute.return_value = "Statement executed successfully."

        for level in (1, 4):
            mock_query.return_value = [
                *_PERSISTED_ROWS,
                {"CONFIG_KEY": "MIN_AGREEMENT_LEVEL", "CONFIG_VALUE": str(level)},
            ]
            payload = _invalid_payload(**{"automation.minAgreementLevel": level})
            resp = client.post("/api/v2/settings", json=payload)
            assert resp.status_code == 200, f"Expected 200 for minAgreementLevel={level}"

    @patch("backend.api.routes.settings.sf.execute", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.settings.sf.get_database")
    def test_500_when_update_config_returns_error_status(self, mock_db, mock_query, mock_execute) -> None:
        """UPDATE_CONFIG returning error-status JSON must surface as 500, not 200."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_execute.return_value = '{"status": "error", "message": "MERGE failed: table locked"}'

        resp = client.post("/api/v2/settings", json=_VALID_PAYLOAD)

        assert resp.status_code == 500
        assert "MERGE failed" in resp.json()["detail"]
        # Re-read must be skipped when the procedure signals an error.
        mock_query.assert_not_called()
