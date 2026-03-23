"""Unit tests for testing API endpoints.

Covers dashboard, failures, run, status, and cancel endpoints.
Uses mocked TestingService to test each endpoint independently.
"""

from __future__ import annotations

from datetime import datetime
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
# GET /api/v2/testing/dashboard Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestTestingDashboard:
    """Test GET /api/v2/testing/dashboard endpoint."""

    @patch("backend.services.testing.TestingService.get_failure_count", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.get_accuracy_by_difficulty", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.get_accuracy_summary", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.get_test_stats", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.get_latest_test_run", new_callable=AsyncMock)
    def test_dashboard_returns_all_data(
        self, mock_test_run, mock_stats, mock_accuracy, mock_difficulty, mock_failures
    ) -> None:
        """Test dashboard endpoint returns complete data."""
        mock_test_run.return_value = {
            "RUN_ID": "run-001",
            "RUN_TIMESTAMP": datetime(2024, 1, 15, 10, 0, 0),
            "TOTAL_TESTS": 1000,
            "METHODS_TESTED": "cortex_search,cosine,edit_distance,jaccard",
        }
        mock_stats.return_value = {
            "TOTAL_CASES": 1000,
            "EASY_COUNT": 400,
            "MEDIUM_COUNT": 350,
            "HARD_COUNT": 250,
            "EASY_PCT": 40.0,
            "MEDIUM_PCT": 35.0,
            "HARD_PCT": 25.0,
        }
        mock_accuracy.return_value = [
            {
                "METHOD": "cortex_search",
                "TOP1_ACCURACY_PCT": 85.0,
                "TOP3_ACCURACY_PCT": 92.0,
                "TOP5_ACCURACY_PCT": 95.0,
            },
            {"METHOD": "cosine", "TOP1_ACCURACY_PCT": 82.0, "TOP3_ACCURACY_PCT": 90.0, "TOP5_ACCURACY_PCT": 93.0},
        ]
        mock_difficulty.return_value = [
            {"METHOD": "cortex_search", "DIFFICULTY": "easy", "TESTS": 400, "TOP1_PCT": 95.0},
            {"METHOD": "cortex_search", "DIFFICULTY": "hard", "TESTS": 250, "TOP1_PCT": 70.0},
        ]
        mock_failures.return_value = 150

        resp = client.get("/api/v2/testing/dashboard")
        assert resp.status_code == 200
        data = resp.json()

        # Test run data
        assert data["testRun"]["runId"] == "run-001"
        assert data["testRun"]["totalTests"] == 1000

        # Test stats
        assert data["testStats"]["totalCases"] == 1000
        assert data["testStats"]["easyCount"] == 400
        assert data["testStats"]["easyPct"] == 40.0

        # Accuracy summary
        assert len(data["accuracySummary"]) == 2
        assert data["accuracySummary"][0]["method"] == "cortex_search"
        assert data["accuracySummary"][0]["top1AccuracyPct"] == 85.0

        # Accuracy by difficulty
        assert len(data["accuracyByDifficulty"]) == 2

        # Failures
        assert data["totalFailures"] == 150

    @patch("backend.services.testing.TestingService.get_failure_count", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.get_accuracy_by_difficulty", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.get_accuracy_summary", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.get_test_stats", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.get_latest_test_run", new_callable=AsyncMock)
    def test_dashboard_handles_no_test_run(
        self, mock_test_run, mock_stats, mock_accuracy, mock_difficulty, mock_failures
    ) -> None:
        """Test dashboard handles no test run data."""
        mock_test_run.return_value = None
        mock_stats.return_value = {"TOTAL_CASES": 0}
        mock_accuracy.return_value = []
        mock_difficulty.return_value = []
        mock_failures.return_value = 0

        resp = client.get("/api/v2/testing/dashboard")
        assert resp.status_code == 200
        data = resp.json()

        assert data["testRun"] is None
        assert data["accuracySummary"] == []


# ---------------------------------------------------------------------------
# GET /api/v2/testing/failures Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestTestingFailures:
    """Test GET /api/v2/testing/failures endpoint."""

    @patch("backend.services.testing.TestingService.get_filter_options", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.get_failures", new_callable=AsyncMock)
    def test_failures_returns_paginated_data(self, mock_failures, mock_filter) -> None:
        """Test failures endpoint returns paginated failure data."""
        mock_failures.return_value = {
            "failures": [
                {
                    "METHOD": "cortex_search",
                    "TEST_INPUT": "organic apples",
                    "EXPECTED_MATCH": "Organic Gala Apples",
                    "ACTUAL_MATCH": "Regular Apples",
                    "SCORE": 0.75,
                    "DIFFICULTY": "hard",
                },
            ],
            "total_failures": 150,
            "total_pages": 15,
            "page": 1,
        }
        mock_filter.return_value = {
            "methods": ["cortex_search", "cosine", "edit_distance"],
            "difficulties": ["easy", "medium", "hard"],
        }

        resp = client.get("/api/v2/testing/failures?page=1&page_size=10")
        assert resp.status_code == 200
        data = resp.json()

        assert data["totalFailures"] == 150
        assert data["totalPages"] == 15
        assert data["currentPage"] == 1
        assert len(data["failures"]) == 1
        assert data["failures"][0]["method"] == "cortex_search"
        assert data["failures"][0]["testInput"] == "organic apples"
        assert data["filterOptions"]["methods"] == ["cortex_search", "cosine", "edit_distance"]

    @patch("backend.services.testing.TestingService.get_filter_options", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.get_failures", new_callable=AsyncMock)
    def test_failures_handles_null_score(self, mock_failures, mock_filter) -> None:
        """Test failures handles null score values."""
        mock_failures.return_value = {
            "failures": [
                {
                    "METHOD": "cortex_search",
                    "TEST_INPUT": "test",
                    "EXPECTED_MATCH": "Test",
                    "ACTUAL_MATCH": "Other",
                    "SCORE": None,
                    "DIFFICULTY": "medium",
                },
            ],
            "total_failures": 1,
            "total_pages": 1,
            "page": 1,
        }
        mock_filter.return_value = {"methods": [], "difficulties": []}

        resp = client.get("/api/v2/testing/failures")
        assert resp.status_code == 200
        data = resp.json()

        assert data["failures"][0]["score"] is None

    @patch("backend.services.testing.TestingService.get_filter_options", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.get_failures", new_callable=AsyncMock)
    def test_failures_pagination_info(self, mock_failures, mock_filter) -> None:
        """Test failures returns correct pagination info."""
        mock_failures.return_value = {
            "failures": [],
            "total_failures": 100,
            "total_pages": 10,
            "page": 5,
        }
        mock_filter.return_value = {"methods": [], "difficulties": []}

        resp = client.get("/api/v2/testing/failures?page=5&page_size=10")
        assert resp.status_code == 200
        data = resp.json()

        assert data["currentPage"] == 5
        assert data["hasPrev"] is True
        assert data["hasNext"] is True


# ---------------------------------------------------------------------------
# POST /api/v2/testing/run Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestTestingRun:
    """Test POST /api/v2/testing/run endpoint."""

    @patch("backend.services.testing.TestingService.run_test_procedure", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.create_test_run", new_callable=AsyncMock)
    def test_run_starts_tests(self, mock_create, mock_run_proc) -> None:
        """Test run endpoint starts test execution."""
        mock_create.return_value = None
        mock_run_proc.return_value = None

        resp = client.post(
            "/api/v2/testing/run",
            json={"methods": ["cortex_search", "cosine"]},
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["status"] == "started"
        assert "runId" in data
        assert data["methods"] == ["cortex_search", "cosine"]

    def test_run_rejects_invalid_methods(self) -> None:
        """Test run rejects invalid method names."""
        resp = client.post(
            "/api/v2/testing/run",
            json={"methods": ["invalid_method"]},
        )
        assert resp.status_code == 400
        data = resp.json()

        assert "error" in data
        assert "valid methods" in data["error"].lower()

    def test_run_rejects_empty_methods(self) -> None:
        """Test run rejects empty methods list."""
        resp = client.post(
            "/api/v2/testing/run",
            json={"methods": []},
        )
        assert resp.status_code == 400

    @patch("backend.services.testing.TestingService.run_test_procedure", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.create_test_run", new_callable=AsyncMock)
    def test_run_filters_valid_methods(self, mock_create, mock_run_proc) -> None:
        """Test run filters out invalid methods from mixed list."""
        mock_create.return_value = None
        mock_run_proc.return_value = None

        resp = client.post(
            "/api/v2/testing/run",
            json={"methods": ["cortex_search", "invalid", "cosine"]},
        )
        assert resp.status_code == 200
        data = resp.json()

        assert "cortex_search" in data["methods"]
        assert "cosine" in data["methods"]
        assert "invalid" not in data["methods"]

    @patch("backend.services.testing.TestingService.create_test_run", new_callable=AsyncMock)
    def test_run_handles_exception(self, mock_create) -> None:
        """Test run returns error on exception."""
        mock_create.side_effect = Exception("Database error")

        resp = client.post(
            "/api/v2/testing/run",
            json={"methods": ["cortex_search"]},
        )
        assert resp.status_code == 500
        data = resp.json()

        assert "error" in data


# ---------------------------------------------------------------------------
# GET /api/v2/testing/status/{run_id} Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestTestingStatus:
    """Test GET /api/v2/testing/status/{run_id} endpoint."""

    @patch("backend.services.testing.TestingService.check_running_tests", new_callable=AsyncMock)
    def test_status_running(self, mock_check) -> None:
        """Test status returns running when tests are active."""
        mock_check.return_value = 3

        resp = client.get("/api/v2/testing/status/run-001?expected_methods=4")
        assert resp.status_code == 200
        data = resp.json()

        assert data["status"] == "running"
        assert data["runningCount"] == 3

    @patch("backend.services.testing.TestingService.finalize_test_run", new_callable=AsyncMock)
    @patch("backend.services.testing.TestingService.check_running_tests", new_callable=AsyncMock)
    def test_status_completed(self, mock_check, mock_finalize) -> None:
        """Test status returns completed when all tests done."""
        mock_check.return_value = 0
        mock_finalize.return_value = None

        resp = client.get("/api/v2/testing/status/run-001")
        assert resp.status_code == 200
        data = resp.json()

        assert data["status"] == "completed"
        assert data["runningCount"] == 0
        mock_finalize.assert_called_once()

    @patch("backend.services.testing.TestingService.check_running_tests", new_callable=AsyncMock)
    def test_status_handles_exception(self, mock_check) -> None:
        """Test status returns error on exception."""
        mock_check.side_effect = Exception("Check failed")

        resp = client.get("/api/v2/testing/status/run-001")
        assert resp.status_code == 500
        data = resp.json()

        assert "error" in data


# ---------------------------------------------------------------------------
# POST /api/v2/testing/cancel Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestTestingCancel:
    """Test POST /api/v2/testing/cancel endpoint."""

    @patch("backend.services.testing.TestingService.mark_run_cancelled", new_callable=AsyncMock)
    def test_cancel_with_run_id(self, mock_cancel) -> None:
        """Test cancel endpoint with specific run_id."""
        mock_cancel.return_value = None

        resp = client.post("/api/v2/testing/cancel?run_id=run-001")
        assert resp.status_code == 200
        data = resp.json()

        assert data["status"] == "cancelled"
        assert data["runId"] == "run-001"

    @patch("backend.services.testing.TestingService.mark_run_cancelled", new_callable=AsyncMock)
    def test_cancel_no_active_run(self, mock_cancel) -> None:
        """Test cancel returns no_active_run when nothing to cancel."""
        # Clear active runs
        from backend.api.routes.testing import _active_runs

        _active_runs.clear()

        resp = client.post("/api/v2/testing/cancel")
        assert resp.status_code == 200
        data = resp.json()

        assert data["status"] == "no_active_run"


# ---------------------------------------------------------------------------
# Schema Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestTestingSchemas:
    """Test testing endpoint schema models."""

    def test_run_tests_request(self) -> None:
        """Test RunTestsRequest schema."""
        from backend.api.routes.testing import RunTestsRequest

        request = RunTestsRequest(methods=["cortex_search", "cosine"])
        assert request.methods == ["cortex_search", "cosine"]

    def test_run_tests_response(self) -> None:
        """Test RunTestsResponse schema."""
        from backend.api.routes.testing import RunTestsResponse

        response = RunTestsResponse(runId="run-001", status="started", methods=["cosine"])
        assert response.runId == "run-001"
        assert response.status == "started"

    def test_test_status_response(self) -> None:
        """Test TestStatusResponse schema."""
        from backend.api.routes.testing import TestStatusResponse

        response = TestStatusResponse(status="running", runningCount=3)
        assert response.status == "running"
        assert response.runningCount == 3

    def test_cancel_tests_response(self) -> None:
        """Test CancelTestsResponse schema."""
        from backend.api.routes.testing import CancelTestsResponse

        response = CancelTestsResponse(runId="run-001", status="cancelled", message="Test cancelled")
        assert response.status == "cancelled"
