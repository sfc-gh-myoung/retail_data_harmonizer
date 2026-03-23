"""Unit tests for dashboard API endpoints.

Covers kpis, sources, categories, signals, llm, and cost endpoints.
Uses mocked DashboardService to test each endpoint independently.
"""

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


# ---------------------------------------------------------------------------
# GET /api/v2/dashboard/kpis Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestDashboardKpis:
    """Test GET /api/v2/dashboard/kpis endpoint."""

    @patch("backend.services.dashboard.DashboardService.get_scale_data", new_callable=AsyncMock)
    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_kpis_returns_all_metrics(self, mock_combined, mock_scale) -> None:
        """Test kpis endpoint returns complete KPI data."""
        mock_combined.return_value = {
            "kpi": {
                "TOTAL_ITEMS": 1000,
                "AUTO_ACCEPTED": 700,
                "CONFIRMED": 100,
                "PENDING_REVIEW": 50,
                "PENDING": 100,
                "REJECTED": 50,
                "NEEDS_CATEGORIZED": 25,
            }
        }
        mock_scale.return_value = {"unique_count": 800}

        resp = client.get("/api/v2/dashboard/kpis")
        assert resp.status_code == 200
        data = resp.json()

        assert data["stats"]["totalRaw"] == 1000
        assert data["stats"]["totalUnique"] == 800
        assert data["stats"]["autoAccepted"] == 700
        assert data["stats"]["confirmed"] == 100
        assert data["stats"]["pendingReview"] == 50
        assert data["stats"]["rejected"] == 50
        assert data["stats"]["needsCategorized"] == 25
        assert data["stats"]["matchRate"] == 70.0  # 700/1000 * 100
        assert len(data["statuses"]) == 5
        assert "status_colors_map" in data

    @patch("backend.services.dashboard.DashboardService.get_scale_data", new_callable=AsyncMock)
    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_kpis_handles_zero_total(self, mock_combined, mock_scale) -> None:
        """Test kpis handles zero total items gracefully."""
        mock_combined.return_value = {
            "kpi": {
                "TOTAL_ITEMS": 0,
                "AUTO_ACCEPTED": 0,
                "CONFIRMED": 0,
                "PENDING_REVIEW": 0,
                "PENDING": 0,
                "REJECTED": 0,
                "NEEDS_CATEGORIZED": 0,
            }
        }
        mock_scale.return_value = {"unique_count": 0}

        resp = client.get("/api/v2/dashboard/kpis")
        assert resp.status_code == 200
        data = resp.json()

        assert data["stats"]["totalRaw"] == 0
        assert data["stats"]["matchRate"] == 0.0

    @patch("backend.services.dashboard.DashboardService.get_scale_data", new_callable=AsyncMock)
    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_kpis_handles_null_values(self, mock_combined, mock_scale) -> None:
        """Test kpis handles null values in data."""
        mock_combined.return_value = {
            "kpi": {
                "TOTAL_ITEMS": None,
                "AUTO_ACCEPTED": None,
                "CONFIRMED": None,
                "PENDING_REVIEW": None,
                "PENDING": None,
                "REJECTED": None,
                "NEEDS_CATEGORIZED": None,
            }
        }
        mock_scale.return_value = {"unique_count": None}

        resp = client.get("/api/v2/dashboard/kpis")
        assert resp.status_code == 200
        data = resp.json()

        assert data["stats"]["totalRaw"] == 0
        assert data["stats"]["autoAccepted"] == 0

    @patch("backend.services.dashboard.DashboardService.get_scale_data", new_callable=AsyncMock)
    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_kpis_handles_exception(self, mock_combined, mock_scale) -> None:
        """Test kpis returns empty data on exception."""
        mock_combined.side_effect = Exception("Database error")

        resp = client.get("/api/v2/dashboard/kpis")
        assert resp.status_code == 200
        data = resp.json()

        assert data["stats"]["totalRaw"] == 0
        assert data["statuses"] == []


# ---------------------------------------------------------------------------
# GET /api/v2/dashboard/sources Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestDashboardSources:
    """Test GET /api/v2/dashboard/sources endpoint."""

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_sources_returns_source_breakdown(self, mock_combined) -> None:
        """Test sources endpoint returns source system breakdown."""
        mock_combined.return_value = {
            "source_status_rows": [
                {"SOURCE_SYSTEM": "POS_A", "MATCH_STATUS": "AUTO_ACCEPTED", "CNT": 500},
                {"SOURCE_SYSTEM": "POS_A", "MATCH_STATUS": "PENDING", "CNT": 100},
                {"SOURCE_SYSTEM": "POS_B", "MATCH_STATUS": "AUTO_ACCEPTED", "CNT": 300},
                {"SOURCE_SYSTEM": "POS_B", "MATCH_STATUS": "REJECTED", "CNT": 50},
            ]
        }

        resp = client.get("/api/v2/dashboard/sources")
        assert resp.status_code == 200
        data = resp.json()

        assert "POS_A" in data["source_systems"]
        assert "POS_B" in data["source_systems"]
        assert data["source_systems"]["POS_A"]["AUTO_ACCEPTED"] == 500
        assert len(data["source_rates"]) == 2
        # Verify rates are calculated correctly
        pos_a_rate = next(r for r in data["source_rates"] if r["source"] == "POS_A")
        assert pos_a_rate["total"] == 600
        assert pos_a_rate["matched"] == 500
        assert pos_a_rate["rate"] == 83.3  # 500/600 * 100

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_sources_filters_unknown(self, mock_combined) -> None:
        """Test sources filters out UNKNOWN source systems."""
        mock_combined.return_value = {
            "source_status_rows": [
                {"SOURCE_SYSTEM": "POS_A", "MATCH_STATUS": "AUTO_ACCEPTED", "CNT": 100},
                {"SOURCE_SYSTEM": "UNKNOWN", "MATCH_STATUS": "PENDING", "CNT": 50},
                {"SOURCE_SYSTEM": "", "MATCH_STATUS": "PENDING", "CNT": 25},
            ]
        }

        resp = client.get("/api/v2/dashboard/sources")
        assert resp.status_code == 200
        data = resp.json()

        assert "POS_A" in data["source_systems"]
        assert "UNKNOWN" not in data["source_systems"]
        assert "" not in data["source_systems"]

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_sources_handles_empty_data(self, mock_combined) -> None:
        """Test sources handles empty source data."""
        mock_combined.return_value = {"source_status_rows": []}

        resp = client.get("/api/v2/dashboard/sources")
        assert resp.status_code == 200
        data = resp.json()

        assert data["source_systems"] == {}
        assert data["source_rates"] == []
        assert data["source_max"] == 1

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_sources_handles_exception(self, mock_combined) -> None:
        """Test sources returns empty data on exception."""
        mock_combined.side_effect = Exception("Query failed")

        resp = client.get("/api/v2/dashboard/sources")
        assert resp.status_code == 200
        data = resp.json()

        assert data["source_systems"] == {}
        assert data["source_rates"] == []

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_sources_sorts_by_rate(self, mock_combined) -> None:
        """Test sources sorts source_rates by rate descending."""
        mock_combined.return_value = {
            "source_status_rows": [
                {"SOURCE_SYSTEM": "LOW_RATE", "MATCH_STATUS": "AUTO_ACCEPTED", "CNT": 10},
                {"SOURCE_SYSTEM": "LOW_RATE", "MATCH_STATUS": "PENDING", "CNT": 90},
                {"SOURCE_SYSTEM": "HIGH_RATE", "MATCH_STATUS": "AUTO_ACCEPTED", "CNT": 90},
                {"SOURCE_SYSTEM": "HIGH_RATE", "MATCH_STATUS": "PENDING", "CNT": 10},
            ]
        }

        resp = client.get("/api/v2/dashboard/sources")
        assert resp.status_code == 200
        data = resp.json()

        # HIGH_RATE (90%) should come before LOW_RATE (10%)
        assert data["source_rates"][0]["source"] == "HIGH_RATE"
        assert data["source_rates"][1]["source"] == "LOW_RATE"


# ---------------------------------------------------------------------------
# GET /api/v2/dashboard/categories Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestDashboardCategories:
    """Test GET /api/v2/dashboard/categories endpoint."""

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_categories_returns_category_rates(self, mock_combined) -> None:
        """Test categories endpoint returns category breakdown."""
        mock_combined.return_value = {
            "category_rate_rows": [
                {"CATEGORY": "Produce", "TOTAL": 500, "MATCHED": 450},
                {"CATEGORY": "Dairy", "TOTAL": 300, "MATCHED": 240},
                {"CATEGORY": "Beverages", "TOTAL": 200, "MATCHED": 180},
            ]
        }

        resp = client.get("/api/v2/dashboard/categories")
        assert resp.status_code == 200
        data = resp.json()

        assert len(data["category_rates"]) == 3
        produce = next(c for c in data["category_rates"] if c["category"] == "Produce")
        assert produce["total"] == 500
        assert produce["matched"] == 450
        assert produce["rate"] == 90.0

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_categories_filters_unknown(self, mock_combined) -> None:
        """Test categories filters out UNKNOWN category."""
        mock_combined.return_value = {
            "category_rate_rows": [
                {"CATEGORY": "Produce", "TOTAL": 100, "MATCHED": 80},
                {"CATEGORY": "UNKNOWN", "TOTAL": 50, "MATCHED": 10},
                {"CATEGORY": "", "TOTAL": 25, "MATCHED": 5},
            ]
        }

        resp = client.get("/api/v2/dashboard/categories")
        assert resp.status_code == 200
        data = resp.json()

        assert len(data["category_rates"]) == 1
        assert data["category_rates"][0]["category"] == "Produce"

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_categories_handles_zero_total(self, mock_combined) -> None:
        """Test categories handles zero total gracefully."""
        mock_combined.return_value = {
            "category_rate_rows": [
                {"CATEGORY": "Produce", "TOTAL": 0, "MATCHED": 0},
            ]
        }

        resp = client.get("/api/v2/dashboard/categories")
        assert resp.status_code == 200
        data = resp.json()

        assert data["category_rates"][0]["rate"] == 0.0

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_categories_handles_exception(self, mock_combined) -> None:
        """Test categories returns empty data on exception."""
        mock_combined.side_effect = Exception("Query failed")

        resp = client.get("/api/v2/dashboard/categories")
        assert resp.status_code == 200
        data = resp.json()

        assert data["category_rates"] == []


# ---------------------------------------------------------------------------
# GET /api/v2/dashboard/signals Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestDashboardSignals:
    """Test GET /api/v2/dashboard/signals endpoint."""

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_signals_returns_all_metrics(self, mock_combined) -> None:
        """Test signals endpoint returns dominance, alignment, and agreement."""
        mock_combined.return_value = {
            "signal_dominance_rows": [
                {"METHOD": "SEARCH", "COUNT": 400},
                {"METHOD": "COSINE", "COUNT": 300},
                {"METHOD": "EDIT", "COUNT": 200},
                {"METHOD": "JACCARD", "COUNT": 100},
            ],
            "signal_alignment_rows": [
                {"METHOD": "SEARCH", "MATCHES": 350},
                {"METHOD": "COSINE", "MATCHES": 280},
            ],
            "agreement_rows": [
                {"AGREEMENT_LEVEL": "4-Way", "COUNT": 500},
                {"AGREEMENT_LEVEL": "3-Way", "COUNT": 300},
                {"AGREEMENT_LEVEL": "2-Way", "COUNT": 150},
                {"AGREEMENT_LEVEL": "1-Way", "COUNT": 50},
            ],
        }

        resp = client.get("/api/v2/dashboard/signals")
        assert resp.status_code == 200
        data = resp.json()

        # Signal dominance
        assert len(data["signal_dominance"]) == 4
        search_dom = next(s for s in data["signal_dominance"] if s["method"] == "SEARCH")
        assert search_dom["count"] == 400
        assert search_dom["pct"] == 40.0  # 400/1000 * 100
        assert search_dom["color"] == "#29B5E8"

        # Signal alignment
        assert len(data["signal_alignment"]) == 2

        # Agreement levels
        assert len(data["agreements"]) == 4
        four_way = next(a for a in data["agreements"] if a["level"] == "4-Way")
        assert four_way["count"] == 500
        assert four_way["pct"] == 50.0

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_signals_handles_empty_data(self, mock_combined) -> None:
        """Test signals handles empty data."""
        mock_combined.return_value = {
            "signal_dominance_rows": [],
            "signal_alignment_rows": [],
            "agreement_rows": [],
        }

        resp = client.get("/api/v2/dashboard/signals")
        assert resp.status_code == 200
        data = resp.json()

        assert data["signal_dominance"] == []
        assert data["signal_alignment"] == []
        assert data["agreements"] == []

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_signals_handles_exception(self, mock_combined) -> None:
        """Test signals returns empty data on exception."""
        mock_combined.side_effect = Exception("Query failed")

        resp = client.get("/api/v2/dashboard/signals")
        assert resp.status_code == 200
        data = resp.json()

        assert data["signal_dominance"] == []
        assert data["signal_alignment"] == []
        assert data["agreements"] == []

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_signals_handles_missing_keys(self, mock_combined) -> None:
        """Test signals handles missing keys in response."""
        mock_combined.return_value = {}  # Empty dict, missing expected keys

        resp = client.get("/api/v2/dashboard/signals")
        assert resp.status_code == 200
        data = resp.json()

        # Should use empty defaults from .get()
        assert data["signal_dominance"] == []


# ---------------------------------------------------------------------------
# GET /api/v2/dashboard/cost Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestDashboardCost:
    """Test GET /api/v2/dashboard/cost endpoint."""

    @patch("backend.services.dashboard.DashboardService.get_scale_data", new_callable=AsyncMock)
    @patch("backend.services.dashboard.DashboardService.get_cost_data", new_callable=AsyncMock)
    def test_cost_returns_all_metrics(self, mock_cost, mock_scale) -> None:
        """Test cost endpoint returns cost and scale metrics."""
        mock_cost.return_value = {
            "TOTAL_RUNS": 10,
            "TOTAL_ESTIMATED_USD": 50.00,
            "TOTAL_CREDITS_USED": 16.67,
            "TOTAL_ITEMS": 10000,
            "COST_PER_ITEM": 0.005,
            "BASELINE_WEEKLY_COST": 2500.00,
            "HOURS_SAVED": 500.0,
            "ROI_PERCENTAGE": 4900.0,
            "CREDIT_RATE_USD": 3.00,
            "MANUAL_HOURLY_RATE": 50.00,
            "MANUAL_MINUTES_PER_ITEM": 3.0,
        }
        mock_scale.return_value = {
            "total": 10000,
            "unique_count": 5000,
            "dedup_ratio": 2.0,
            "fast_path_count": 3000,
            "fast_path_rate": 30.0,
        }

        resp = client.get("/api/v2/dashboard/cost")
        assert resp.status_code == 200
        data = resp.json()

        # Cost metrics
        assert data["cost_data"]["totalRuns"] == 10
        assert data["cost_data"]["totalUsd"] == 50.00
        assert data["cost_data"]["totalCredits"] == 16.67
        assert data["cost_data"]["roiPercentage"] == 4900.0

        # Scale metrics
        assert data["scale_data"]["total"] == 10000
        assert data["scale_data"]["uniqueCount"] == 5000
        assert data["scale_data"]["dedupRatio"] == 2.0
        assert data["scale_data"]["fastPathCount"] == 3000

    @patch("backend.services.dashboard.DashboardService.get_scale_data", new_callable=AsyncMock)
    @patch("backend.services.dashboard.DashboardService.get_cost_data", new_callable=AsyncMock)
    def test_cost_handles_null_cost_data(self, mock_cost, mock_scale) -> None:
        """Test cost handles null cost data."""
        mock_cost.return_value = None
        mock_scale.return_value = {
            "total": 100,
            "unique_count": 50,
            "dedup_ratio": 2.0,
            "fast_path_count": 10,
            "fast_path_rate": 10.0,
        }

        resp = client.get("/api/v2/dashboard/cost")
        assert resp.status_code == 200
        data = resp.json()

        assert data["cost_data"] is None
        assert data["scale_data"]["total"] == 100

    @patch("backend.services.dashboard.DashboardService.get_scale_data", new_callable=AsyncMock)
    @patch("backend.services.dashboard.DashboardService.get_cost_data", new_callable=AsyncMock)
    def test_cost_handles_null_values_in_cost(self, mock_cost, mock_scale) -> None:
        """Test cost handles null values within cost data."""
        mock_cost.return_value = {
            "TOTAL_RUNS": None,
            "TOTAL_ESTIMATED_USD": None,
            "TOTAL_CREDITS_USED": None,
            "TOTAL_ITEMS": None,
            "COST_PER_ITEM": None,
            "BASELINE_WEEKLY_COST": None,
            "HOURS_SAVED": None,
            "ROI_PERCENTAGE": None,
            "CREDIT_RATE_USD": None,
            "MANUAL_HOURLY_RATE": None,
            "MANUAL_MINUTES_PER_ITEM": None,
        }
        mock_scale.return_value = {
            "total": 0,
            "unique_count": 0,
            "dedup_ratio": 1.0,
            "fast_path_count": 0,
            "fast_path_rate": 0.0,
        }

        resp = client.get("/api/v2/dashboard/cost")
        assert resp.status_code == 200
        data = resp.json()

        assert data["cost_data"]["totalRuns"] == 0
        assert data["cost_data"]["totalUsd"] == 0
        assert data["cost_data"]["creditRateUsd"] == 3.00  # Default

    @patch("backend.services.dashboard.DashboardService.get_scale_data", new_callable=AsyncMock)
    @patch("backend.services.dashboard.DashboardService.get_cost_data", new_callable=AsyncMock)
    def test_cost_handles_exception(self, mock_cost, mock_scale) -> None:
        """Test cost returns defaults on exception."""
        mock_cost.side_effect = Exception("Query failed")

        resp = client.get("/api/v2/dashboard/cost")
        assert resp.status_code == 200
        data = resp.json()

        assert data["cost_data"] is None
        assert data["scale_data"]["total"] == 0
        assert data["scale_data"]["dedupRatio"] == 1.0


# ---------------------------------------------------------------------------
# Caching Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestDashboardCaching:
    """Test dashboard endpoint caching behavior."""

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_categories_uses_cache(self, mock_combined) -> None:
        """Test categories endpoint uses cache on second call."""
        mock_combined.return_value = {"category_rate_rows": [{"CATEGORY": "Test", "TOTAL": 100, "MATCHED": 80}]}

        # First call
        resp1 = client.get("/api/v2/dashboard/categories")
        assert resp1.status_code == 200

        # Second call - should use cache
        resp2 = client.get("/api/v2/dashboard/categories")
        assert resp2.status_code == 200

        # Service should only be called once due to caching
        assert mock_combined.call_count == 1

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_signals_uses_cache(self, mock_combined) -> None:
        """Test signals endpoint uses cache."""
        mock_combined.return_value = {
            "signal_dominance_rows": [],
            "signal_alignment_rows": [],
            "agreement_rows": [],
        }

        resp1 = client.get("/api/v2/dashboard/signals")
        resp2 = client.get("/api/v2/dashboard/signals")

        assert resp1.status_code == 200
        assert resp2.status_code == 200
        assert mock_combined.call_count == 1


# ---------------------------------------------------------------------------
# Edge Cases
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestDashboardEdgeCases:
    """Test edge cases for dashboard endpoints."""

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_signals_with_zero_totals(self, mock_combined) -> None:
        """Test signals handles zero totals without division error."""
        mock_combined.return_value = {
            "signal_dominance_rows": [{"METHOD": "SEARCH", "COUNT": 0}],
            "signal_alignment_rows": [{"METHOD": "SEARCH", "MATCHES": 0}],
            "agreement_rows": [{"AGREEMENT_LEVEL": "4-Way", "COUNT": 0}],
        }

        resp = client.get("/api/v2/dashboard/signals")
        assert resp.status_code == 200
        data = resp.json()

        # Should not crash with zero totals
        assert data["signal_dominance"][0]["pct"] == 0.0

    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_categories_with_special_characters(self, mock_combined) -> None:
        """Test categories handles special characters in names."""
        mock_combined.return_value = {
            "category_rate_rows": [
                {"CATEGORY": "Snacks & Candy", "TOTAL": 100, "MATCHED": 80},
                {"CATEGORY": "Health/Beauty", "TOTAL": 50, "MATCHED": 40},
            ]
        }

        resp = client.get("/api/v2/dashboard/categories")
        assert resp.status_code == 200
        data = resp.json()

        assert len(data["category_rates"]) == 2
        assert any(c["category"] == "Snacks & Candy" for c in data["category_rates"])

    @patch("backend.services.dashboard.DashboardService.get_scale_data", new_callable=AsyncMock)
    @patch("backend.services.dashboard.DashboardService.get_combined_data", new_callable=AsyncMock)
    def test_kpis_calculates_total_processed(self, mock_combined, mock_scale) -> None:
        """Test kpis correctly calculates totalProcessed."""
        mock_combined.return_value = {
            "kpi": {
                "TOTAL_ITEMS": 1000,
                "AUTO_ACCEPTED": 400,
                "CONFIRMED": 200,
                "PENDING_REVIEW": 100,
                "PENDING": 250,
                "REJECTED": 50,
                "NEEDS_CATEGORIZED": 0,
            }
        }
        mock_scale.return_value = {"unique_count": 800}

        resp = client.get("/api/v2/dashboard/kpis")
        assert resp.status_code == 200
        data = resp.json()

        # totalProcessed = auto + confirmed + pending_review + rejected
        assert data["stats"]["totalProcessed"] == 750  # 400 + 200 + 100 + 50
