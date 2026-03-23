"""Unit tests for comparison API endpoints.

Covers agreement, method-accuracy, source-performance, and algorithms endpoints.
Uses mocked ComparisonService to test each endpoint independently.
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
# GET /api/v2/comparison/algorithms Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestComparisonAlgorithms:
    """Test GET /api/v2/comparison/algorithms endpoint."""

    def test_algorithms_returns_static_data(self) -> None:
        """Test algorithms endpoint returns all algorithm descriptions."""
        resp = client.get("/api/v2/comparison/algorithms")
        assert resp.status_code == 200
        data = resp.json()

        assert len(data["algorithms"]) == 5
        algo_names = [a["name"] for a in data["algorithms"]]
        assert "Search" in algo_names
        assert "Cosine" in algo_names
        assert "Edit Distance" in algo_names
        assert "Jaccard" in algo_names
        assert "Ensemble" in algo_names

    def test_algorithms_have_required_fields(self) -> None:
        """Test each algorithm has name, description, and features."""
        resp = client.get("/api/v2/comparison/algorithms")
        assert resp.status_code == 200
        data = resp.json()

        for algo in data["algorithms"]:
            assert "name" in algo
            assert "description" in algo
            assert "features" in algo
            assert isinstance(algo["features"], list)
            assert len(algo["features"]) > 0


# ---------------------------------------------------------------------------
# GET /api/v2/comparison/agreement Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestComparisonAgreement:
    """Test GET /api/v2/comparison/agreement endpoint."""

    @patch("backend.services.comparison.ComparisonService.get_agreement_analysis", new_callable=AsyncMock)
    def test_agreement_returns_distribution(self, mock_agreement) -> None:
        """Test agreement endpoint returns agreement level distribution."""
        mock_agreement.return_value = [
            {"AGREEMENT_LEVEL": "4 of 4 Agree", "MATCH_COUNT": 500, "AVG_CONFIDENCE": 95.5},
            {"AGREEMENT_LEVEL": "3 of 4 Agree", "MATCH_COUNT": 300, "AVG_CONFIDENCE": 85.2},
            {"AGREEMENT_LEVEL": "2 of 4 Agree", "MATCH_COUNT": 150, "AVG_CONFIDENCE": 72.0},
            {"AGREEMENT_LEVEL": "0 of 4 Agree", "MATCH_COUNT": 50, "AVG_CONFIDENCE": 55.0},
        ]

        resp = client.get("/api/v2/comparison/agreement")
        assert resp.status_code == 200
        data = resp.json()

        assert len(data["agreement"]) == 4
        four_agree = next(a for a in data["agreement"] if a["level"] == "4 of 4 Agree")
        assert four_agree["count"] == 500
        assert four_agree["avgConfidence"] == 95.5

    @patch("backend.services.comparison.ComparisonService.get_agreement_analysis", new_callable=AsyncMock)
    def test_agreement_handles_empty_data(self, mock_agreement) -> None:
        """Test agreement handles empty result."""
        mock_agreement.return_value = []

        resp = client.get("/api/v2/comparison/agreement")
        assert resp.status_code == 200
        data = resp.json()

        assert data["agreement"] == []

    @patch("backend.services.comparison.ComparisonService.get_agreement_analysis", new_callable=AsyncMock)
    def test_agreement_handles_exception(self, mock_agreement) -> None:
        """Test agreement returns empty data on exception."""
        mock_agreement.side_effect = Exception("Query failed")

        resp = client.get("/api/v2/comparison/agreement")
        assert resp.status_code == 200
        data = resp.json()

        assert data["agreement"] == []

    @patch("backend.services.comparison.ComparisonService.get_agreement_analysis", new_callable=AsyncMock)
    def test_agreement_handles_null_values(self, mock_agreement) -> None:
        """Test agreement handles null values in data."""
        mock_agreement.return_value = [
            {"AGREEMENT_LEVEL": "4 of 4 Agree", "MATCH_COUNT": None, "AVG_CONFIDENCE": None},
        ]

        resp = client.get("/api/v2/comparison/agreement")
        assert resp.status_code == 200
        data = resp.json()

        assert data["agreement"][0]["count"] == 0
        assert data["agreement"][0]["avgConfidence"] == 0


# ---------------------------------------------------------------------------
# GET /api/v2/comparison/method-accuracy Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestComparisonMethodAccuracy:
    """Test GET /api/v2/comparison/method-accuracy endpoint."""

    @patch("backend.services.comparison.ComparisonService.get_method_accuracy", new_callable=AsyncMock)
    def test_method_accuracy_returns_all_methods(self, mock_accuracy) -> None:
        """Test method-accuracy returns accuracy for all methods."""
        mock_accuracy.return_value = [
            {
                "TOTAL_CONFIRMED": 1000,
                "SEARCH_CORRECT": 850,
                "SEARCH_ACCURACY_PCT": 85.0,
                "COSINE_CORRECT": 820,
                "COSINE_ACCURACY_PCT": 82.0,
                "EDIT_CORRECT": 750,
                "EDIT_ACCURACY_PCT": 75.0,
                "JACCARD_CORRECT": 700,
                "JACCARD_ACCURACY_PCT": 70.0,
                "LLM_CORRECT": 900,
                "LLM_ACCURACY_PCT": 90.0,
                "ENSEMBLE_CORRECT": 950,
                "ENSEMBLE_ACCURACY_PCT": 95.0,
            }
        ]

        resp = client.get("/api/v2/comparison/method-accuracy")
        assert resp.status_code == 200
        data = resp.json()

        accuracy = data["methodAccuracy"]
        assert accuracy["totalConfirmed"] == 1000
        assert accuracy["searchCorrect"] == 850
        assert accuracy["searchAccuracyPct"] == 85.0
        assert accuracy["cosineCorrect"] == 820
        assert accuracy["ensembleAccuracyPct"] == 95.0

    @patch("backend.services.comparison.ComparisonService.get_method_accuracy", new_callable=AsyncMock)
    def test_method_accuracy_handles_empty_result(self, mock_accuracy) -> None:
        """Test method-accuracy handles empty result."""
        mock_accuracy.return_value = []

        resp = client.get("/api/v2/comparison/method-accuracy")
        assert resp.status_code == 200
        data = resp.json()

        accuracy = data["methodAccuracy"]
        assert accuracy["totalConfirmed"] == 0
        assert accuracy["searchAccuracyPct"] == 0.0

    @patch("backend.services.comparison.ComparisonService.get_method_accuracy", new_callable=AsyncMock)
    def test_method_accuracy_handles_exception(self, mock_accuracy) -> None:
        """Test method-accuracy returns zeros on exception."""
        mock_accuracy.side_effect = Exception("Query failed")

        resp = client.get("/api/v2/comparison/method-accuracy")
        assert resp.status_code == 200
        data = resp.json()

        accuracy = data["methodAccuracy"]
        assert accuracy["totalConfirmed"] == 0

    @patch("backend.services.comparison.ComparisonService.get_method_accuracy", new_callable=AsyncMock)
    def test_method_accuracy_handles_null_values(self, mock_accuracy) -> None:
        """Test method-accuracy handles null values."""
        mock_accuracy.return_value = [
            {
                "TOTAL_CONFIRMED": None,
                "SEARCH_CORRECT": None,
                "SEARCH_ACCURACY_PCT": None,
                "COSINE_CORRECT": None,
                "COSINE_ACCURACY_PCT": None,
                "EDIT_CORRECT": None,
                "EDIT_ACCURACY_PCT": None,
                "JACCARD_CORRECT": None,
                "JACCARD_ACCURACY_PCT": None,
                "LLM_CORRECT": None,
                "LLM_ACCURACY_PCT": None,
                "ENSEMBLE_CORRECT": None,
                "ENSEMBLE_ACCURACY_PCT": None,
            }
        ]

        resp = client.get("/api/v2/comparison/method-accuracy")
        assert resp.status_code == 200
        data = resp.json()

        accuracy = data["methodAccuracy"]
        assert accuracy["totalConfirmed"] == 0
        assert accuracy["searchAccuracyPct"] == 0.0


# ---------------------------------------------------------------------------
# GET /api/v2/comparison/source-performance Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestComparisonSourcePerformance:
    """Test GET /api/v2/comparison/source-performance endpoint."""

    @patch("backend.services.comparison.ComparisonService.get_source_performance", new_callable=AsyncMock)
    def test_source_performance_returns_by_source(self, mock_perf) -> None:
        """Test source-performance returns metrics per source system."""
        mock_perf.return_value = [
            {
                "SOURCE_SYSTEM": "POS_A",
                "ITEM_COUNT": 500,
                "AVG_SEARCH": 0.92,
                "AVG_COSINE": 0.88,
                "AVG_EDIT": 0.75,
                "AVG_JACCARD": 0.70,
                "AVG_LLM": 0.90,
                "AVG_ENSEMBLE": 85.5,
            },
            {
                "SOURCE_SYSTEM": "POS_B",
                "ITEM_COUNT": 300,
                "AVG_SEARCH": 0.85,
                "AVG_COSINE": 0.82,
                "AVG_EDIT": 0.70,
                "AVG_JACCARD": 0.65,
                "AVG_LLM": 0.85,
                "AVG_ENSEMBLE": 80.0,
            },
        ]

        resp = client.get("/api/v2/comparison/source-performance")
        assert resp.status_code == 200
        data = resp.json()

        assert len(data["sourcePerformance"]) == 2
        pos_a = next(s for s in data["sourcePerformance"] if s["source"] == "POS_A")
        assert pos_a["itemCount"] == 500
        assert pos_a["avgSearch"] == 0.92
        assert pos_a["avgEnsemble"] == 85.5

    @patch("backend.services.comparison.ComparisonService.get_source_performance", new_callable=AsyncMock)
    def test_source_performance_handles_empty_data(self, mock_perf) -> None:
        """Test source-performance handles empty result."""
        mock_perf.return_value = []

        resp = client.get("/api/v2/comparison/source-performance")
        assert resp.status_code == 200
        data = resp.json()

        assert data["sourcePerformance"] == []

    @patch("backend.services.comparison.ComparisonService.get_source_performance", new_callable=AsyncMock)
    def test_source_performance_handles_exception(self, mock_perf) -> None:
        """Test source-performance returns empty on exception."""
        mock_perf.side_effect = Exception("Query failed")

        resp = client.get("/api/v2/comparison/source-performance")
        assert resp.status_code == 200
        data = resp.json()

        assert data["sourcePerformance"] == []

    @patch("backend.services.comparison.ComparisonService.get_source_performance", new_callable=AsyncMock)
    def test_source_performance_handles_null_values(self, mock_perf) -> None:
        """Test source-performance handles null values."""
        mock_perf.return_value = [
            {
                "SOURCE_SYSTEM": "POS_A",
                "ITEM_COUNT": None,
                "AVG_SEARCH": None,
                "AVG_COSINE": None,
                "AVG_EDIT": None,
                "AVG_JACCARD": None,
                "AVG_LLM": None,
                "AVG_ENSEMBLE": None,
            },
        ]

        resp = client.get("/api/v2/comparison/source-performance")
        assert resp.status_code == 200
        data = resp.json()

        perf = data["sourcePerformance"][0]
        assert perf["itemCount"] == 0
        assert perf["avgSearch"] == 0


# ---------------------------------------------------------------------------
# GET /api/v2/comparison (Legacy Endpoint) Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestComparisonLegacy:
    """Test GET /api/v2/comparison legacy endpoint."""

    @patch("backend.api.routes.comparison.sf.query", new_callable=AsyncMock)
    def test_legacy_returns_all_data(self, mock_query) -> None:
        """Test legacy endpoint returns combined data."""
        mock_query.side_effect = [
            # Agreement query
            [{"AGREEMENT_LEVEL": "4 of 4 Agree", "MATCH_COUNT": 100, "AVG_CONFIDENCE": 90.0}],
            # Source performance query
            [
                {
                    "SOURCE_SYSTEM": "POS_A",
                    "ITEM_COUNT": 50,
                    "AVG_SEARCH": 0.9,
                    "AVG_COSINE": 0.8,
                    "AVG_EDIT": 0.7,
                    "AVG_JACCARD": 0.6,
                    "AVG_LLM": 0.85,
                    "AVG_ENSEMBLE": 80.0,
                }
            ],
            # Method accuracy query
            [
                {
                    "TOTAL_CONFIRMED": 100,
                    "SEARCH_CORRECT": 80,
                    "SEARCH_ACCURACY_PCT": 80.0,
                    "COSINE_CORRECT": 75,
                    "COSINE_ACCURACY_PCT": 75.0,
                    "EDIT_CORRECT": 70,
                    "EDIT_ACCURACY_PCT": 70.0,
                    "JACCARD_CORRECT": 65,
                    "JACCARD_ACCURACY_PCT": 65.0,
                    "LLM_CORRECT": 85,
                    "LLM_ACCURACY_PCT": 85.0,
                    "ENSEMBLE_CORRECT": 90,
                    "ENSEMBLE_ACCURACY_PCT": 90.0,
                }
            ],
        ]

        resp = client.get("/api/v2/comparison")
        assert resp.status_code == 200
        data = resp.json()

        assert "algorithms" in data
        assert "agreement" in data
        assert "sourcePerformance" in data
        assert "methodAccuracy" in data

    @patch("backend.api.routes.comparison.sf.query", new_callable=AsyncMock)
    def test_legacy_handles_query_exceptions(self, mock_query) -> None:
        """Test legacy endpoint handles exceptions gracefully."""
        mock_query.side_effect = Exception("Query failed")

        resp = client.get("/api/v2/comparison")
        assert resp.status_code == 200
        data = resp.json()

        # Should still return structure with empty data
        assert data["agreement"] == []
        assert data["sourcePerformance"] == []
        assert data["methodAccuracy"]["totalConfirmed"] == 0


# ---------------------------------------------------------------------------
# Caching Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestComparisonCaching:
    """Test comparison endpoint caching behavior."""

    @patch("backend.services.comparison.ComparisonService.get_agreement_analysis", new_callable=AsyncMock)
    def test_agreement_uses_cache(self, mock_agreement) -> None:
        """Test agreement endpoint uses cache on second call."""
        mock_agreement.return_value = [{"AGREEMENT_LEVEL": "4 of 4 Agree", "MATCH_COUNT": 100, "AVG_CONFIDENCE": 90.0}]

        resp1 = client.get("/api/v2/comparison/agreement")
        resp2 = client.get("/api/v2/comparison/agreement")

        assert resp1.status_code == 200
        assert resp2.status_code == 200
        assert mock_agreement.call_count == 1
