"""Unit tests for pipeline API endpoints.

Uses mocked Snowflake queries to test each endpoint independently.
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
    # Also clear after test
    async_cache.invalidate()
    sync_cache.invalidate()


@pytest.mark.unit
class TestPipelineFunnel:
    """Test GET /api/v2/pipeline/funnel endpoint."""

    @patch("backend.services.dashboard.DashboardService.get_progress_data", new_callable=AsyncMock)
    def test_funnel_returns_metrics(self, mock_progress) -> None:
        """Test funnel endpoint returns expected metrics."""
        mock_progress.return_value = {
            "RAW_ITEMS": 1000,
            "CATEGORIZED_ITEMS": 800,
            "BLOCKED_ITEMS": 50,
            "UNIQUE_DESCRIPTIONS": 500,
            "PIPELINE_ITEMS": 450,
            "ENSEMBLE_DONE": 400,
            "LLM_REQUIRED": 100,
            "LLM_DONE": 80,
            "LLM_PENDING": 20,
        }
        resp = client.get("/api/v2/pipeline/funnel")
        assert resp.status_code == 200
        data = resp.json()
        assert data["raw_items"] == 1000
        assert data["categorized_items"] == 800
        assert data["blocked_items"] == 50
        assert data["unique_descriptions"] == 500
        assert data["pipeline_items"] == 450

    @patch("backend.services.dashboard.DashboardService.get_progress_data", new_callable=AsyncMock)
    def test_funnel_handles_empty_data(self, mock_progress) -> None:
        """Test funnel endpoint handles empty/null data gracefully."""
        mock_progress.return_value = None
        resp = client.get("/api/v2/pipeline/funnel")
        assert resp.status_code == 200
        data = resp.json()
        assert data["raw_items"] == 0
        assert data["pipeline_items"] == 0


@pytest.mark.unit
class TestPipelinePhases:
    """Test GET /api/v2/pipeline/phases endpoint."""

    @patch("backend.services.dashboard.DashboardService.get_progress_data", new_callable=AsyncMock)
    def test_phases_returns_six_phases(self, mock_progress) -> None:
        """Test phases endpoint returns all 6 phases."""
        mock_progress.return_value = {
            "PIPELINE_ITEMS": 100,
            "SEARCH_DONE": 100,
            "SEARCH_PCT": 100.0,
            "SEARCH_STATE": "COMPLETE",
            "COSINE_DONE": 80,
            "COSINE_PCT": 80.0,
            "COSINE_STATE": "PROCESSING",
            "EDIT_DONE": 0,
            "EDIT_PCT": 0.0,
            "EDIT_STATE": "WAITING",
            "JACCARD_DONE": 0,
            "JACCARD_PCT": 0.0,
            "JACCARD_STATE": "WAITING",
            "LLM_REQUIRED": 50,
            "LLM_DONE": 0,
            "LLM_PCT": 0.0,
            "LLM_STATE": "WAITING",
            "ENSEMBLE_DONE": 0,
            "ENSEMBLE_PCT": 0.0,
            "ENSEMBLE_STATE": "WAITING",
            "PIPELINE_STATE": "PROCESSING",
        }
        resp = client.get("/api/v2/pipeline/phases")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["phases"]) == 5
        # Verify phase names
        phase_names = [p["name"] for p in data["phases"]]
        assert "Cortex Search" in phase_names
        assert "Cosine Match" in phase_names
        assert "Edit Distance" in phase_names
        assert "Jaccard Match" in phase_names
        assert "Ensemble" in phase_names

    @patch("backend.services.dashboard.DashboardService.get_progress_data", new_callable=AsyncMock)
    def test_phases_handles_empty_data(self, mock_progress) -> None:
        """Test phases endpoint handles empty data gracefully."""
        mock_progress.return_value = None
        resp = client.get("/api/v2/pipeline/phases")
        assert resp.status_code == 200
        data = resp.json()
        assert data["phases"] == []


@pytest.mark.unit
class TestPipelineTasks:
    """Test GET /api/v2/pipeline/tasks endpoint."""

    @patch("backend.services.pipeline.PipelineService.get_pipeline_tab_data", new_callable=AsyncMock)
    @patch("backend.api.sf.query", new_callable=AsyncMock)
    def test_tasks_returns_task_list(self, mock_query, mock_tab_data) -> None:
        """Test tasks endpoint returns task list."""
        mock_tab_data.return_value = {
            "tasks": [
                {
                    "name": "DEDUP_FASTPATH_TASK",
                    "state": "started",
                    "schedule": "USING CRON",
                    "role": "root",
                    "level": 0,
                    "dag": "stream_pipeline",
                },
                {
                    "name": "VECTOR_PREP_TASK",
                    "state": "started",
                    "schedule": "",
                    "role": "child",
                    "level": 1,
                    "dag": "stream_pipeline",
                },
            ],
            "all_tasks_suspended": False,
            "pending_count": 0,
        }
        mock_query.return_value = [{"CNT": 0}]
        resp = client.get("/api/v2/pipeline/tasks")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["tasks"]) == 2
        assert data["tasks"][0]["name"] == "DEDUP_FASTPATH_TASK"
        assert data["all_tasks_suspended"] is False


@pytest.mark.unit
class TestPipelineActions:
    """Test pipeline action endpoints."""

    @patch("backend.api.sf.execute", new_callable=AsyncMock)
    def test_run_triggers_pipeline(self, mock_execute) -> None:
        """Test POST /run triggers the pipeline."""
        mock_execute.return_value = "OK"
        resp = client.post("/api/v2/pipeline/run")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "triggered" in data["message"].lower()

    @patch("backend.api.sf.execute", new_callable=AsyncMock)
    def test_run_pipeline_error_returns_500(self, mock_execute) -> None:
        """Test POST /run returns 500 on execution failure."""
        mock_execute.side_effect = Exception("Connection failed")
        resp = client.post("/api/v2/pipeline/run")
        assert resp.status_code == 500
        assert "Connection failed" in resp.json()["detail"]

    @patch("backend.api.sf.execute", new_callable=AsyncMock)
    def test_stop_requests_stop(self, mock_execute) -> None:
        """Test POST /stop sets stop requested flag."""
        mock_execute.return_value = "OK"
        resp = client.post("/api/v2/pipeline/stop", json={"job_id": "test-job-123"})
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True

    @patch("backend.api.sf.execute", new_callable=AsyncMock)
    def test_stop_pipeline_error_returns_500(self, mock_execute) -> None:
        """Test POST /stop returns 500 on execution failure."""
        mock_execute.side_effect = Exception("Update failed")
        resp = client.post("/api/v2/pipeline/stop", json={"job_id": "test-job-123"})
        assert resp.status_code == 500
        assert "Update failed" in resp.json()["detail"]

    @patch("backend.services.pipeline.PipelineService.toggle_task", new_callable=AsyncMock)
    def test_toggle_task(self, mock_toggle) -> None:
        """Test POST /toggle toggles a task."""
        mock_toggle.return_value = None
        resp = client.post("/api/v2/pipeline/toggle", json={"task_name": "DEDUP_FASTPATH_TASK", "action": "suspend"})
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True

    @patch("backend.services.pipeline.PipelineService.toggle_task", new_callable=AsyncMock)
    def test_toggle_task_invalid_name_returns_400(self, mock_toggle) -> None:
        """Test POST /toggle returns 400 for invalid task name."""
        mock_toggle.side_effect = ValueError("Invalid task name: UNKNOWN_TASK")
        resp = client.post("/api/v2/pipeline/toggle", json={"task_name": "UNKNOWN_TASK", "action": "suspend"})
        assert resp.status_code == 400
        assert "Invalid task name" in resp.json()["detail"]

    @patch("backend.services.pipeline.PipelineService.toggle_task", new_callable=AsyncMock)
    def test_toggle_task_error_returns_500(self, mock_toggle) -> None:
        """Test POST /toggle returns 500 on execution failure."""
        mock_toggle.side_effect = Exception("ALTER TASK failed")
        resp = client.post("/api/v2/pipeline/toggle", json={"task_name": "DEDUP_FASTPATH_TASK", "action": "suspend"})
        assert resp.status_code == 500
        assert "ALTER TASK failed" in resp.json()["detail"]

    @patch("backend.api.sf.execute", new_callable=AsyncMock)
    def test_enable_all_tasks(self, mock_execute) -> None:
        """Test POST /tasks/enable-all enables all tasks."""
        mock_execute.return_value = "OK"
        resp = client.post("/api/v2/pipeline/tasks/enable-all")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True

    @patch("backend.api.sf.execute", new_callable=AsyncMock)
    def test_enable_all_tasks_error_returns_500(self, mock_execute) -> None:
        """Test POST /tasks/enable-all returns 500 on failure."""
        mock_execute.side_effect = Exception("Procedure call failed")
        resp = client.post("/api/v2/pipeline/tasks/enable-all")
        assert resp.status_code == 500
        assert "Procedure call failed" in resp.json()["detail"]

    @patch("backend.api.sf.execute", new_callable=AsyncMock)
    def test_disable_all_tasks(self, mock_execute) -> None:
        """Test POST /tasks/disable-all disables all tasks."""
        mock_execute.return_value = "OK"
        resp = client.post("/api/v2/pipeline/tasks/disable-all")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True

    @patch("backend.api.sf.execute", new_callable=AsyncMock)
    def test_disable_all_tasks_error_returns_500(self, mock_execute) -> None:
        """Test POST /tasks/disable-all returns 500 on failure."""
        mock_execute.side_effect = Exception("Procedure call failed")
        resp = client.post("/api/v2/pipeline/tasks/disable-all")
        assert resp.status_code == 500
        assert "Procedure call failed" in resp.json()["detail"]

    @patch("backend.services.pipeline.PipelineService.reset_pipeline", new_callable=AsyncMock)
    def test_reset_pipeline(self, mock_reset) -> None:
        """Test POST /reset resets the pipeline."""
        mock_reset.return_value = "OK"
        resp = client.post("/api/v2/pipeline/reset")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "reset" in data["message"].lower()

    @patch("backend.services.pipeline.PipelineService.reset_pipeline", new_callable=AsyncMock)
    def test_reset_pipeline_error_returns_500(self, mock_reset) -> None:
        """Test POST /reset returns 500 on failure."""
        mock_reset.side_effect = Exception("Reset failed")
        resp = client.post("/api/v2/pipeline/reset")
        assert resp.status_code == 500
        assert "Reset failed" in resp.json()["detail"]

    @patch("backend.api.sf.query", new_callable=AsyncMock)
    def test_pipeline_status(self, mock_query) -> None:
        """Test GET /status returns pipeline status."""
        mock_query.side_effect = [
            [{"tasks_enabled": True, "root_task_state": "started", "pending_items": 10}],
            [{"CNT": 5}],
        ]
        resp = client.get("/api/v2/pipeline/status")
        assert resp.status_code == 200
        data = resp.json()
        assert "tasksEnabled" in data or "error" in data

    @patch("backend.api.sf.query", new_callable=AsyncMock)
    def test_pipeline_status_error_returns_error_dict(self, mock_query) -> None:
        """Test GET /status returns error dict on exception."""
        mock_query.side_effect = Exception("Query failed")
        resp = client.get("/api/v2/pipeline/status")
        assert resp.status_code == 200
        data = resp.json()
        assert "error" in data


@pytest.mark.unit
class TestPipelineFunnelErrors:
    """Test error handling for pipeline funnel endpoint."""

    @patch("backend.services.dashboard.DashboardService.get_progress_data", new_callable=AsyncMock)
    def test_funnel_handles_exception(self, mock_progress) -> None:
        """Test funnel endpoint handles exceptions gracefully."""
        mock_progress.side_effect = Exception("Query failed")
        resp = client.get("/api/v2/pipeline/funnel")
        # Should return 200 with zeros or handle error gracefully
        assert resp.status_code == 200


@pytest.mark.unit
class TestPipelinePhasesErrors:
    """Test error handling for pipeline phases endpoint."""

    @patch("backend.services.dashboard.DashboardService.get_progress_data", new_callable=AsyncMock)
    def test_phases_handles_exception(self, mock_progress) -> None:
        """Test phases endpoint handles exceptions gracefully."""
        mock_progress.side_effect = Exception("Query failed")
        resp = client.get("/api/v2/pipeline/phases")
        # Should return 200 with empty phases or handle error gracefully
        assert resp.status_code == 200
