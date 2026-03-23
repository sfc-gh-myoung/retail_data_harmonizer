"""Unit tests for logs API endpoints.

Covers errors, audit, and pagination for log endpoints.
Uses mocked LogsService to test each endpoint independently.
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
# GET /api/v2/logs/errors Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestLogsErrors:
    """Test GET /api/v2/logs/errors endpoint."""

    @patch("backend.services.logs.LogsService.get_recent_errors_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_recent_errors", new_callable=AsyncMock)
    def test_errors_returns_paginated_errors(self, mock_errors, mock_count) -> None:
        """Test errors endpoint returns paginated error logs."""
        mock_errors.return_value = [
            {
                "LOG_ID": "log-001",
                "RUN_ID": "run-001",
                "STEP_NAME": "COSINE_MATCHING",
                "CATEGORY": "PROCESSING",
                "ERROR_MESSAGE": "Embedding service timeout",
                "ITEMS_FAILED": 50,
                "QUERY_ID": "qid-123",
                "CREATED_AT": "2024-01-15T10:00:00",
            },
        ]
        mock_count.return_value = 100

        resp = client.get("/api/v2/logs/errors?page=1&page_size=25")
        assert resp.status_code == 200
        data = resp.json()

        errors = data["recentErrors"]
        assert errors["total"] == 100
        assert errors["page"] == 1
        assert errors["pageSize"] == 25
        assert errors["totalPages"] == 4
        assert len(errors["entries"]) == 1
        assert errors["entries"][0]["stepName"] == "COSINE_MATCHING"

    @patch("backend.services.logs.LogsService.get_recent_errors_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_recent_errors", new_callable=AsyncMock)
    def test_errors_handles_empty_data(self, mock_errors, mock_count) -> None:
        """Test errors handles no errors."""
        mock_errors.return_value = []
        mock_count.return_value = 0

        resp = client.get("/api/v2/logs/errors")
        assert resp.status_code == 200
        data = resp.json()

        assert data["recentErrors"]["total"] == 0
        assert data["recentErrors"]["entries"] == []

    @patch("backend.services.logs.LogsService.get_recent_errors_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_recent_errors", new_callable=AsyncMock)
    def test_errors_handles_exception(self, mock_errors, mock_count) -> None:
        """Test errors returns empty on exception."""
        mock_errors.side_effect = Exception("Query failed")

        resp = client.get("/api/v2/logs/errors")
        assert resp.status_code == 200
        data = resp.json()

        assert data["recentErrors"]["entries"] == []
        assert data["recentErrors"]["totalPages"] == 1


# ---------------------------------------------------------------------------
# GET /api/v2/logs/audit Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestLogsAudit:
    """Test GET /api/v2/logs/audit endpoint."""

    @patch("backend.services.logs.LogsService.get_audit_logs_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_audit_logs", new_callable=AsyncMock)
    def test_audit_returns_paginated_logs(self, mock_audit, mock_count) -> None:
        """Test audit endpoint returns paginated audit logs."""
        mock_audit.return_value = [
            {
                "AUDIT_ID": "audit-001",
                "ACTION": "STATUS_CHANGE",
                "MATCH_ID": "match-001",
                "OLD_STATUS": "PENDING",
                "NEW_STATUS": "CONFIRMED",
                "REVIEWED_BY": "user@example.com",
                "CREATED_AT": "2024-01-15T10:00:00",
                "NOTES": "Verified correct match",
            },
        ]
        mock_count.return_value = 50

        resp = client.get("/api/v2/logs/audit?page=1&page_size=25")
        assert resp.status_code == 200
        data = resp.json()

        audit = data["auditLogs"]
        assert audit["total"] == 50
        assert audit["page"] == 1
        assert audit["totalPages"] == 2
        assert len(audit["entries"]) == 1
        assert audit["entries"][0]["actionType"] == "STATUS_CHANGE"
        assert audit["entries"][0]["changedBy"] == "user@example.com"

    @patch("backend.services.logs.LogsService.get_audit_logs_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_audit_logs", new_callable=AsyncMock)
    def test_audit_handles_empty_data(self, mock_audit, mock_count) -> None:
        """Test audit handles no audit logs."""
        mock_audit.return_value = []
        mock_count.return_value = 0

        resp = client.get("/api/v2/logs/audit")
        assert resp.status_code == 200
        data = resp.json()

        assert data["auditLogs"]["total"] == 0
        assert data["auditLogs"]["entries"] == []

    @patch("backend.services.logs.LogsService.get_audit_logs_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_audit_logs", new_callable=AsyncMock)
    def test_audit_handles_exception(self, mock_audit, mock_count) -> None:
        """Test audit returns empty on exception."""
        mock_audit.side_effect = Exception("Query failed")

        resp = client.get("/api/v2/logs/audit")
        assert resp.status_code == 200
        data = resp.json()

        assert data["auditLogs"]["entries"] == []


# ---------------------------------------------------------------------------
# Pagination Tests
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# GET /api/v2/logs/task-history Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestLogsTaskHistory:
    """Test GET /api/v2/logs/task-history endpoint."""

    @patch("backend.services.logs.LogsService.get_task_history_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_task_history", new_callable=AsyncMock)
    def test_task_history_returns_paginated_data(self, mock_history, mock_count) -> None:
        """Test task history endpoint returns paginated task execution history."""
        mock_history.return_value = [
            {
                "TASK_NAME": "EMBEDDING_TASK",
                "STATE": "SUCCEEDED",
                "SCHEDULED_TIME": "2024-01-15T10:00:00",
                "QUERY_START_TIME": "2024-01-15T10:00:01",
                "DURATION_SECONDS": 45.5,
                "ERROR_MESSAGE": None,
            },
            {
                "TASK_NAME": "SCORING_TASK",
                "STATE": "FAILED",
                "SCHEDULED_TIME": "2024-01-15T09:00:00",
                "QUERY_START_TIME": "2024-01-15T09:00:01",
                "DURATION_SECONDS": 10.2,
                "ERROR_MESSAGE": "Query timeout",
            },
        ]
        mock_count.return_value = 100

        resp = client.get("/api/v2/logs/task-history?page=1&page_size=10")
        assert resp.status_code == 200
        data = resp.json()

        history = data["taskHistory"]
        assert history["total"] == 100
        assert history["page"] == 1
        assert history["pageSize"] == 10
        assert history["totalPages"] == 10
        assert len(history["entries"]) == 2
        assert history["entries"][0]["taskName"] == "EMBEDDING_TASK"
        assert history["entries"][0]["state"] == "SUCCEEDED"
        assert history["entries"][0]["durationSeconds"] == 45.5
        assert history["entries"][1]["errorMessage"] == "Query timeout"

    @patch("backend.services.logs.LogsService.get_task_history_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_task_history", new_callable=AsyncMock)
    def test_task_history_handles_empty_data(self, mock_history, mock_count) -> None:
        """Test task history handles no task history entries."""
        mock_history.return_value = []
        mock_count.return_value = 0

        resp = client.get("/api/v2/logs/task-history")
        assert resp.status_code == 200
        data = resp.json()

        assert data["taskHistory"]["total"] == 0
        assert data["taskHistory"]["entries"] == []
        assert data["taskHistory"]["totalPages"] == 1

    @patch("backend.services.logs.LogsService.get_task_history_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_task_history", new_callable=AsyncMock)
    def test_task_history_handles_exception(self, mock_history, mock_count) -> None:
        """Test task history returns empty on exception."""
        mock_history.side_effect = Exception("Database connection failed")

        resp = client.get("/api/v2/logs/task-history")
        assert resp.status_code == 200
        data = resp.json()

        assert data["taskHistory"]["entries"] == []
        assert data["taskHistory"]["totalPages"] == 1

    @patch("backend.services.logs.LogsService.get_task_history_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_task_history", new_callable=AsyncMock)
    def test_task_history_handles_null_values(self, mock_history, mock_count) -> None:
        """Test task history handles null/None values in response."""
        mock_history.return_value = [
            {
                "TASK_NAME": "TEST_TASK",
                "STATE": "RUNNING",
                "SCHEDULED_TIME": None,
                "QUERY_START_TIME": None,
                "DURATION_SECONDS": None,
                "ERROR_MESSAGE": None,
            },
        ]
        mock_count.return_value = 1

        resp = client.get("/api/v2/logs/task-history")
        assert resp.status_code == 200
        data = resp.json()

        entry = data["taskHistory"]["entries"][0]
        assert entry["taskName"] == "TEST_TASK"
        assert entry["scheduledTime"] is None
        assert entry["queryStartTime"] is None
        assert entry["durationSeconds"] is None

    @patch("backend.services.logs.LogsService.get_task_history_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_task_history", new_callable=AsyncMock)
    def test_task_history_with_task_name_filter(self, mock_history, mock_count) -> None:
        """Test task history endpoint filters by task name."""
        mock_history.return_value = [
            {
                "TASK_NAME": "EMBEDDING_TASK",
                "STATE": "SUCCEEDED",
                "SCHEDULED_TIME": "2024-01-15T10:00:00",
                "QUERY_START_TIME": "2024-01-15T10:00:01",
                "DURATION_SECONDS": 45.5,
                "ERROR_MESSAGE": None,
            },
        ]
        mock_count.return_value = 1

        resp = client.get("/api/v2/logs/task-history?task_name=EMBEDDING")
        assert resp.status_code == 200
        data = resp.json()

        assert data["taskHistory"]["total"] == 1
        assert len(data["taskHistory"]["entries"]) == 1
        mock_history.assert_called_once_with(1, 10, "EMBEDDING", "")

    @patch("backend.services.logs.LogsService.get_task_history_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_task_history", new_callable=AsyncMock)
    def test_task_history_with_state_filter(self, mock_history, mock_count) -> None:
        """Test task history endpoint filters by state."""
        mock_history.return_value = [
            {
                "TASK_NAME": "EMBEDDING_TASK",
                "STATE": "FAILED",
                "SCHEDULED_TIME": "2024-01-15T10:00:00",
                "QUERY_START_TIME": "2024-01-15T10:00:01",
                "DURATION_SECONDS": 10.2,
                "ERROR_MESSAGE": "Query timeout",
            },
        ]
        mock_count.return_value = 5

        resp = client.get("/api/v2/logs/task-history?state=FAILED")
        assert resp.status_code == 200
        data = resp.json()

        assert data["taskHistory"]["total"] == 5
        mock_history.assert_called_once_with(1, 10, "", "FAILED")

    @patch("backend.services.logs.LogsService.get_task_history_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_task_history", new_callable=AsyncMock)
    def test_task_history_with_combined_filters(self, mock_history, mock_count) -> None:
        """Test task history endpoint with both task name and state filters."""
        mock_history.return_value = []
        mock_count.return_value = 0

        resp = client.get("/api/v2/logs/task-history?task_name=SCORING&state=SUCCEEDED")
        assert resp.status_code == 200
        data = resp.json()

        assert data["taskHistory"]["total"] == 0
        mock_history.assert_called_once_with(1, 10, "SCORING", "SUCCEEDED")


# ---------------------------------------------------------------------------
# GET /api/v2/logs/task-history/filter-options Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestTaskFilterOptions:
    """Test GET /api/v2/logs/task-history/filter-options endpoint."""

    @patch("backend.services.logs.LogsService.get_task_filter_options", new_callable=AsyncMock)
    def test_filter_options_returns_task_names_and_states(self, mock_options) -> None:
        """Test filter options endpoint returns distinct task names and states."""
        mock_options.return_value = {
            "taskNames": ["EMBEDDING_TASK", "SCORING_TASK", "MATCHING_TASK"],
            "states": ["SUCCEEDED", "FAILED", "EXECUTING", "SCHEDULED"],
        }

        resp = client.get("/api/v2/logs/task-history/filter-options")
        assert resp.status_code == 200
        data = resp.json()

        assert data["taskNames"] == ["EMBEDDING_TASK", "SCORING_TASK", "MATCHING_TASK"]
        assert data["states"] == ["SUCCEEDED", "FAILED", "EXECUTING", "SCHEDULED"]

    @patch("backend.services.logs.LogsService.get_task_filter_options", new_callable=AsyncMock)
    def test_filter_options_handles_empty_data(self, mock_options) -> None:
        """Test filter options handles no task history."""
        mock_options.return_value = {"taskNames": [], "states": []}

        resp = client.get("/api/v2/logs/task-history/filter-options")
        assert resp.status_code == 200
        data = resp.json()

        assert data["taskNames"] == []
        assert data["states"] == []

    @patch("backend.services.logs.LogsService.get_task_filter_options", new_callable=AsyncMock)
    def test_filter_options_handles_exception(self, mock_options) -> None:
        """Test filter options returns empty on exception."""
        mock_options.side_effect = Exception("Database error")

        resp = client.get("/api/v2/logs/task-history/filter-options")
        assert resp.status_code == 200
        data = resp.json()

        assert data["taskNames"] == []
        assert data["states"] == []


@pytest.mark.unit
class TestLogsPagination:
    """Test pagination parameters for logs endpoints."""

    @patch("backend.services.logs.LogsService.get_recent_errors_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_recent_errors", new_callable=AsyncMock)
    def test_errors_pagination_params(self, mock_errors, mock_count) -> None:
        """Test errors endpoint accepts pagination params."""
        mock_errors.return_value = []
        mock_count.return_value = 0

        resp = client.get("/api/v2/logs/errors?page=2&page_size=50")
        assert resp.status_code == 200
        data = resp.json()

        assert data["recentErrors"]["page"] == 2
        assert data["recentErrors"]["pageSize"] == 50

    @patch("backend.services.logs.LogsService.get_audit_logs_count", new_callable=AsyncMock)
    @patch("backend.services.logs.LogsService.get_audit_logs", new_callable=AsyncMock)
    def test_audit_pagination_params(self, mock_audit, mock_count) -> None:
        """Test audit endpoint accepts pagination params."""
        mock_audit.return_value = []
        mock_count.return_value = 0

        resp = client.get("/api/v2/logs/audit?page=3&page_size=10")
        assert resp.status_code == 200
        data = resp.json()

        assert data["auditLogs"]["page"] == 3
        assert data["auditLogs"]["pageSize"] == 10
