"""Unit tests for the service layer.

Tests business logic, data transformations, and SQL generation in service classes.
Uses AsyncMock to isolate services from actual Snowflake queries.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

import pytest

from backend.services.base import BaseService
from backend.services.comparison import ComparisonService
from backend.services.dashboard import DashboardService
from backend.services.logs import LogsService
from backend.services.pipeline import PipelineService
from backend.services.testing import TestingService

# ---------------------------------------------------------------------------
# BaseService Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestBaseService:
    """Tests for BaseService helper methods."""

    def test_safe_escapes_single_quotes(self, mock_sf: AsyncMock) -> None:
        """Test that _safe escapes single quotes for SQL injection prevention."""
        service = BaseService(db_name="TEST_DB", sf=mock_sf)

        assert service._safe("normal") == "normal"
        assert service._safe("it's") == "it''s"
        assert service._safe("O'Brien's") == "O''Brien''s"
        assert service._safe("") == ""

    @pytest.mark.parametrize(
        "col,direction,expected_col,expected_dir",
        [
            ("NAME", "ASC", "NAME", "ASC"),
            ("SCORE", "DESC", "SCORE", "DESC"),
            ("INVALID", "ASC", "NAME", "ASC"),  # Invalid col -> default
            ("NAME", "desc", "NAME", "DESC"),  # Normalized direction
            ("NAME", "asc", "NAME", "ASC"),  # Normalized direction
            ("NAME", "invalid", "NAME", "ASC"),  # Invalid dir -> ASC
        ],
        ids=["valid-asc", "valid-desc", "invalid-col", "normalize-desc", "normalize-asc", "invalid-dir"],
    )
    def test_validate_sort(
        self, mock_sf: AsyncMock, col: str, direction: str, expected_col: str, expected_dir: str
    ) -> None:
        """Test _validate_sort handles columns and directions correctly."""
        service = BaseService(db_name="TEST_DB", sf=mock_sf)
        allowed = {"NAME", "SCORE", "DATE"}

        result_col, result_dir = service._validate_sort(col, direction, allowed, "NAME")
        assert result_col == expected_col
        assert result_dir == expected_dir

    @pytest.mark.parametrize(
        "filters,expected_fragments",
        [
            ({}, ["1=1"]),
            ({"status": "All"}, ["1=1"]),
            ({"status": "ACTIVE"}, ["STATUS = 'ACTIVE'"]),
            ({"status": "PENDING", "source": "POS_A"}, ["STATUS = 'PENDING'", "SOURCE = 'POS_A'"]),
            ({"name": "O'Reilly"}, ["NAME = 'O''Reilly'"]),  # SQL injection prevention
        ],
        ids=["empty", "all-filter", "single", "multiple", "escape-quotes"],
    )
    def test_build_filter_clause(self, mock_sf: AsyncMock, filters: dict, expected_fragments: list[str]) -> None:
        """Test _build_filter_clause builds proper WHERE conditions."""
        service = BaseService(db_name="TEST_DB", sf=mock_sf)
        column_map = {"status": "STATUS", "source": "SOURCE", "name": "NAME"}

        clause = service._build_filter_clause(filters, column_map)
        for fragment in expected_fragments:
            assert fragment in clause


# ---------------------------------------------------------------------------
# DashboardService Tests
# ---------------------------------------------------------------------------


class TestDashboardService:
    """Tests for DashboardService."""

    @pytest.mark.asyncio
    async def test_get_scale_data_computes_ratios(self, mock_sf: AsyncMock) -> None:
        """Test get_scale_data correctly computes dedup ratio and fast path rate."""
        mock_sf.query.return_value = [{"TOTAL_ITEMS": 1000, "UNIQUE_COUNT": 250, "FAST_PATH_COUNT": 100}]
        service = DashboardService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_scale_data()

        assert result["total"] == 1000
        assert result["unique_count"] == 250
        assert result["dedup_ratio"] == 0.25  # 250/1000
        assert result["fast_path_count"] == 100
        assert result["fast_path_rate"] == 10.0  # 100/1000 * 100

    @pytest.mark.asyncio
    async def test_get_scale_data_handles_empty_results(self, mock_sf: AsyncMock) -> None:
        """Test get_scale_data returns safe defaults when no data."""
        mock_sf.query.return_value = []
        service = DashboardService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_scale_data()

        assert result["total"] == 0
        assert result["dedup_ratio"] == 1.0  # Default when total is 0
        assert result["fast_path_rate"] == 0.0

    @pytest.mark.asyncio
    async def test_get_scale_data_handles_null_values(self, mock_sf: AsyncMock) -> None:
        """Test get_scale_data handles NULL values from Snowflake."""
        mock_sf.query.return_value = [{"TOTAL_ITEMS": None, "UNIQUE_COUNT": None, "FAST_PATH_COUNT": None}]
        service = DashboardService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_scale_data()

        assert result["total"] == 0
        assert result["unique_count"] == 0
        assert result["fast_path_count"] == 0

    @pytest.mark.asyncio
    async def test_get_scale_data_with_cache(self, mock_sf: AsyncMock, mock_cache: MagicMock) -> None:
        """Test get_scale_data uses cache when available."""
        cached_data = {
            "total": 500,
            "unique_count": 100,
            "dedup_ratio": 0.2,
            "fast_path_count": 50,
            "fast_path_rate": 10.0,
        }
        mock_cache.get.return_value = cached_data
        service = DashboardService(db_name="TEST_DB", sf=mock_sf, cache=mock_cache)

        result = await service.get_scale_data()

        assert result == cached_data
        mock_sf.query.assert_not_called()

    @pytest.mark.asyncio
    @pytest.mark.asyncio
    @pytest.mark.asyncio
    async def test_get_cost_data_returns_row_or_empty(self, mock_sf: AsyncMock) -> None:
        """Test get_cost_data returns first row or empty dict."""
        mock_sf.query.return_value = [{"TOTAL_COST": 100.50, "SAVINGS": 25.00}]
        service = DashboardService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_cost_data()
        assert result["TOTAL_COST"] == 100.50

        mock_sf.query.return_value = []
        result = await service.get_cost_data()
        assert result == {}

    @pytest.mark.asyncio
    async def test_get_cost_data_with_cache(self, mock_sf: AsyncMock, mock_cache: MagicMock) -> None:
        """Test get_cost_data uses cache."""
        cached_data = {"TOTAL_COST": 200.00}
        mock_cache.get.return_value = cached_data
        service = DashboardService(db_name="TEST_DB", sf=mock_sf, cache=mock_cache)

        result = await service.get_cost_data()

        assert result == cached_data
        mock_sf.query.assert_not_called()

    @pytest.mark.asyncio
    async def test_get_activity_data_returns_list(self, mock_sf: AsyncMock) -> None:
        """Test get_activity_data returns activity log entries."""
        mock_sf.query.return_value = [{"timestamp": "2024-01-15 10:00", "action": "PIPELINE_RUN", "details": ""}]
        service = DashboardService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_activity_data()

        assert len(result) == 1
        assert result[0]["action"] == "PIPELINE_RUN"

    @pytest.mark.asyncio
    async def test_get_activity_data_with_cache(self, mock_sf: AsyncMock, mock_cache: MagicMock) -> None:
        """Test get_activity_data uses cache."""
        cached_data = [{"timestamp": "2024-01-15", "action": "PIPELINE_RUN"}]
        mock_cache.get.return_value = cached_data
        service = DashboardService(db_name="TEST_DB", sf=mock_sf, cache=mock_cache)

        result = await service.get_activity_data()

        assert result == cached_data
        mock_sf.query.assert_not_called()

    @pytest.mark.asyncio
    async def test_get_progress_data_returns_row(self, mock_sf: AsyncMock) -> None:
        """Test get_progress_data returns phase status."""
        mock_sf.query.return_value = [{"RAW_ITEMS": 1000, "SEARCH_DONE": 800}]
        service = DashboardService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_progress_data()

        assert result["RAW_ITEMS"] == 1000
        assert result["SEARCH_DONE"] == 800

    @pytest.mark.asyncio
    async def test_get_progress_data_handles_empty(self, mock_sf: AsyncMock) -> None:
        """Test get_progress_data returns empty dict on no data."""
        mock_sf.query.return_value = []
        service = DashboardService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_progress_data()

        assert result == {}

    @pytest.mark.asyncio
    async def test_get_combined_data_returns_all_sections(self, mock_sf: AsyncMock) -> None:
        """Test get_combined_data returns all dashboard sections."""
        mock_sf.query.side_effect = [
            [{"TOTAL": 1000}],  # kpi
            [{"SOURCE_SYSTEM": "POS_A", "MATCH_STATUS": "CONFIRMED"}],  # source_status
            [{"CATEGORY": "Beverages", "TOTAL": 100}],  # category
            [{"METHOD": "SEARCH", "COUNT": 500}],  # signal_dominance
            [{"METHOD": "SEARCH", "MATCHES": 400}],  # signal_alignment
            [{"AGREEMENT_LEVEL": "4-Way", "COUNT": 300}],  # agreement
        ]
        service = DashboardService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_combined_data()

        assert "kpi" in result
        assert "source_status_rows" in result
        assert "category_rate_rows" in result
        assert "signal_dominance_rows" in result
        assert "signal_alignment_rows" in result
        assert "agreement_rows" in result

    @pytest.mark.asyncio
    async def test_get_combined_data_with_cache(self, mock_sf: AsyncMock, mock_cache: MagicMock) -> None:
        """Test get_combined_data uses cache."""
        cached_data = {"kpi": {"TOTAL": 500}, "source_status_rows": []}
        mock_cache.get.return_value = cached_data
        service = DashboardService(db_name="TEST_DB", sf=mock_sf, cache=mock_cache)

        result = await service.get_combined_data()

        assert result == cached_data
        mock_sf.query.assert_not_called()


# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# PipelineService Tests
# ---------------------------------------------------------------------------


class TestPipelineService:
    """Tests for PipelineService."""

    @pytest.mark.asyncio
    @pytest.mark.asyncio
    @pytest.mark.asyncio
    @pytest.mark.asyncio
    @pytest.mark.asyncio
    @pytest.mark.asyncio
    @pytest.mark.asyncio
    @pytest.mark.asyncio
    @pytest.mark.asyncio
    async def test_toggle_task_resume_root(self, mock_sf: AsyncMock) -> None:
        """Test toggle_task resumes root task directly."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        await service.toggle_task("DEDUP_FASTPATH_TASK", "resume")

        # Should have 2 calls: resume task + refresh cache
        assert mock_sf.execute.call_count == 2
        first_call = mock_sf.execute.call_args_list[0][0][0]
        assert "RESUME" in first_call
        assert "DEDUP_FASTPATH_TASK" in first_call
        second_call = mock_sf.execute.call_args_list[1][0][0]
        assert "REFRESH_TASK_STATE_CACHE_PROC" in second_call

    @pytest.mark.asyncio
    async def test_toggle_task_suspend_root(self, mock_sf: AsyncMock) -> None:
        """Test toggle_task suspends root task."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        await service.toggle_task("DEDUP_FASTPATH_TASK", "suspend")

        # Should have 2 calls: suspend task + refresh cache
        assert mock_sf.execute.call_count == 2
        first_call = mock_sf.execute.call_args_list[0][0][0]
        assert "SUSPEND" in first_call

    @pytest.mark.asyncio
    async def test_toggle_task_resume_child_suspends_root_first(self, mock_sf: AsyncMock) -> None:
        """Test toggle_task for child task suspends root, resumes child, resumes root."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        await service.toggle_task("VECTOR_PREP_TASK", "resume")

        # Should have 4 calls: suspend root, resume child, resume root, refresh cache
        assert mock_sf.execute.call_count == 4

    @pytest.mark.asyncio
    async def test_toggle_task_suspend_child(self, mock_sf: AsyncMock) -> None:
        """Test toggle_task suspending a child task suspends via root."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        await service.toggle_task("VECTOR_PREP_TASK", "suspend")

        # Should have 2 calls: suspend root + refresh cache
        assert mock_sf.execute.call_count == 2
        first_call = mock_sf.execute.call_args_list[0][0][0]
        assert "SUSPEND" in first_call
        assert "DEDUP_FASTPATH_TASK" in first_call  # Root task

    @pytest.mark.asyncio
    async def test_toggle_task_decoupled_resume(self, mock_sf: AsyncMock) -> None:
        """Test toggle_task for decoupled tasks toggles directly."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        await service.toggle_task("ENSEMBLE_SCORING_TASK", "resume")

        # Should have 2 calls: resume task + refresh cache
        assert mock_sf.execute.call_count == 2
        first_call = mock_sf.execute.call_args_list[0][0][0]
        assert "RESUME" in first_call
        assert "ENSEMBLE_SCORING_TASK" in first_call

    @pytest.mark.asyncio
    async def test_toggle_task_decoupled_suspend(self, mock_sf: AsyncMock) -> None:
        """Test toggle_task for decoupled tasks suspends directly."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        await service.toggle_task("ENSEMBLE_SCORING_TASK", "suspend")

        # Should have 2 calls: suspend task + refresh cache
        assert mock_sf.execute.call_count == 2
        first_call = mock_sf.execute.call_args_list[0][0][0]
        assert "SUSPEND" in first_call

    @pytest.mark.asyncio
    async def test_toggle_task_maintenance_task(self, mock_sf: AsyncMock) -> None:
        """Test toggle_task for maintenance tasks toggles directly."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        await service.toggle_task("CLEANUP_COORDINATION_TASK", "resume")

        assert mock_sf.execute.call_count == 2

    @pytest.mark.asyncio
    async def test_toggle_task_invalid_name_raises(self, mock_sf: AsyncMock) -> None:
        """Test toggle_task raises ValueError for invalid task names."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        with pytest.raises(ValueError, match="Invalid task name"):
            await service.toggle_task("INVALID_TASK", "resume")

    @pytest.mark.asyncio
    async def test_reset_pipeline(self, mock_sf: AsyncMock) -> None:
        """Test reset_pipeline calls stored procedure."""
        mock_sf.execute.return_value = "Pipeline reset successfully"
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        result = await service.reset_pipeline()

        assert result == "Pipeline reset successfully"
        call_arg = mock_sf.execute.call_args[0][0]
        assert "RESET_PIPELINE" in call_arg

    @pytest.mark.asyncio
    @pytest.mark.asyncio
    @pytest.mark.asyncio
    def test_parse_pipeline_status_parses_json(self, mock_sf: AsyncMock) -> None:
        """Test _parse_pipeline_status handles JSON string result."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        result = service._parse_pipeline_status([{"GET_PIPELINE_STATUS": '{"status": "ok"}'}])
        assert result == {"status": "ok"}

    def test_parse_pipeline_status_handles_dict(self, mock_sf: AsyncMock) -> None:
        """Test _parse_pipeline_status handles dict result directly."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        result = service._parse_pipeline_status([{"col": {"status": "ok"}}])
        assert result == {"status": "ok"}

    def test_parse_pipeline_status_handles_exception(self, mock_sf: AsyncMock) -> None:
        """Test _parse_pipeline_status returns empty dict on exception."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        result = service._parse_pipeline_status(ValueError("test error"))
        assert result == {}

    def test_parse_pipeline_status_handles_empty_list(self, mock_sf: AsyncMock) -> None:
        """Test _parse_pipeline_status returns empty dict on empty list."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        result = service._parse_pipeline_status([])
        assert result == {}

    def test_parse_pipeline_status_handles_non_dict_row(self, mock_sf: AsyncMock) -> None:
        """Test _parse_pipeline_status returns empty dict when row is not a dict."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        result = service._parse_pipeline_status(["not a dict"])
        assert result == {}

    def test_parse_pipeline_status_handles_invalid_json(self, mock_sf: AsyncMock) -> None:
        """Test _parse_pipeline_status returns empty dict on invalid JSON."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        result = service._parse_pipeline_status([{"col": "not valid json {"}])
        assert result == {}

    def test_process_task_rows_filters_and_sorts(self, mock_sf: AsyncMock) -> None:
        """Test _process_task_rows filters pipeline tasks and sorts by level."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        rows = [
            {"name": "STAGING_MERGE_TASK", "state": "started", "schedule": "", "comment": ""},
            {"name": "DEDUP_FASTPATH_TASK", "state": "started", "schedule": "", "comment": ""},
            {"name": "UNRELATED_TASK", "state": "started", "schedule": "", "comment": ""},
        ]

        result = service._process_task_rows(rows)

        # Should include both DAG tasks, sorted by level
        assert len(result) == 2
        assert result[0]["name"] == "DEDUP_FASTPATH_TASK"  # level 0
        assert result[1]["name"] == "STAGING_MERGE_TASK"  # level 4

    def test_process_task_rows_handles_exception(self, mock_sf: AsyncMock) -> None:
        """Test _process_task_rows returns empty list on exception."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        result = service._process_task_rows(ValueError("test error"))

        assert result == []

    def test_process_task_rows_includes_pipeline_keyword_tasks(self, mock_sf: AsyncMock) -> None:
        """Test _process_task_rows includes tasks with PIPELINE in name."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        rows = [
            {"name": "MY_CUSTOM_PIPELINE_TASK", "state": "started", "schedule": "", "comment": ""},
        ]

        result = service._process_task_rows(rows)

        assert len(result) == 1
        assert result[0]["role"] == "other"

    def test_parse_classification_status(self, mock_sf: AsyncMock) -> None:
        """Test _parse_classification_status parses query result."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        result = service._parse_classification_status(
            [{"TOTAL_PENDING": 100, "MISSING_CATEGORY": 20, "HAS_CATEGORY": 80}]
        )

        assert result["total"] == 100
        assert result["missing"] == 20
        assert result["has_category"] == 80
        assert result["pct_classified"] == 80.0

    def test_parse_classification_status_handles_exception(self, mock_sf: AsyncMock) -> None:
        """Test _parse_classification_status returns defaults on exception."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        result = service._parse_classification_status(ValueError("test error"))

        assert result["total"] == 0
        assert result["missing"] == 0

    def test_parse_classification_status_handles_empty(self, mock_sf: AsyncMock) -> None:
        """Test _parse_classification_status returns defaults on empty list."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        result = service._parse_classification_status([])

        assert result["total"] == 0

    def test_parse_classification_status_handles_zero_total(self, mock_sf: AsyncMock) -> None:
        """Test _parse_classification_status handles zero total correctly."""
        service = PipelineService(db_name="TEST_DB", sf=mock_sf)

        result = service._parse_classification_status([{"TOTAL_PENDING": 0, "MISSING_CATEGORY": 0, "HAS_CATEGORY": 0}])

        assert result["total"] == 0
        assert result["pct_classified"] == 0

    @pytest.mark.asyncio
    async def test_get_pipeline_tab_data_returns_all_fields(self, mock_sf: AsyncMock) -> None:
        """Test get_pipeline_tab_data returns complete data structure."""
        # Mock query to return different data for different calls
        mock_sf.query.side_effect = [
            # Pending count
            [{"CNT": 150}],
            # Task rows (via _fetch_all_tasks - 2 queries)
            [{"name": "DEDUP_FASTPATH_TASK", "state": "started", "schedule": "", "comment": ""}],
            [],  # analytics tasks
            # Classification status (no cache)
            [{"TOTAL_PENDING": 100, "MISSING_CATEGORY": 20, "HAS_CATEGORY": 80}],
            # Config (no cache)
            [{"CONFIG_KEY": "DASHBOARD_AUTO_REFRESH", "CONFIG_VALUE": "on"}],
            # Task history
            [{"TASK_NAME": "DEDUP_FASTPATH_TASK", "STATE": "SUCCEEDED", "SCHEDULED_TIME": "2024-01-01"}],
            # Task history count (no cache)
            [{"TOTAL": 50}],
            # Pipeline status
            [{"GET_PIPELINE_STATUS": '{"status": "healthy", "pending": 150}'}],
        ]
        service = PipelineService(db_name="TEST_DB", sf=mock_sf, cache=None)

        result = await service.get_pipeline_tab_data()

        assert "pipeline_status" in result
        assert "pending_count" in result
        assert "tasks" in result
        assert "classification_status" in result
        assert "auto_refresh_enabled" in result
        assert "task_history" in result
        assert "task_history_total" in result
        assert result["pending_count"] == 150
        # Verify key fields are present and have correct types
        assert isinstance(result["tasks"], list)
        assert isinstance(result["classification_status"], dict)
        assert isinstance(result["task_history"], list)

    @pytest.mark.asyncio
    async def test_get_pipeline_tab_data_handles_pending_exception(self, mock_sf: AsyncMock) -> None:
        """Test get_pipeline_tab_data handles exception in pending count query."""
        mock_sf.query.side_effect = [
            Exception("Connection error"),  # pending count fails
            [{"name": "DEDUP_FASTPATH_TASK", "state": "started", "schedule": "", "comment": ""}],
            [],
            [{"TOTAL_PENDING": 100, "MISSING_CATEGORY": 20, "HAS_CATEGORY": 80}],
            [],
            [],
            [{"TOTAL": 0}],
            [{"GET_PIPELINE_STATUS": '{"status": "healthy"}'}],
        ]
        service = PipelineService(db_name="TEST_DB", sf=mock_sf, cache=None)

        result = await service.get_pipeline_tab_data()

        # Should return 0 for pending count when query fails
        assert result["pending_count"] == 0

    @pytest.mark.asyncio
    async def test_get_pipeline_tab_data_handles_task_history_exception(self, mock_sf: AsyncMock) -> None:
        """Test get_pipeline_tab_data handles exception in task history query."""
        mock_sf.query.side_effect = [
            [{"CNT": 50}],
            [{"name": "DEDUP_FASTPATH_TASK", "state": "started", "schedule": "", "comment": ""}],
            [],
            [{"TOTAL_PENDING": 50, "MISSING_CATEGORY": 10, "HAS_CATEGORY": 40}],
            [],
            Exception("Task history query failed"),  # task history fails
            Exception("Count also fails"),  # task history count fails
            [{"GET_PIPELINE_STATUS": '{"status": "healthy"}'}],
        ]
        service = PipelineService(db_name="TEST_DB", sf=mock_sf, cache=None)

        result = await service.get_pipeline_tab_data()

        # Should return empty task history when query fails
        assert result["task_history"] == []
        assert result["task_history_total"] == 0
        assert result["task_history_total_pages"] == 1

    @pytest.mark.asyncio
    async def test_get_pipeline_tab_data_computes_all_suspended(self, mock_sf: AsyncMock) -> None:
        """Test get_pipeline_tab_data correctly computes all_tasks_suspended."""
        mock_sf.query.side_effect = [
            [{"CNT": 0}],
            # All stream_pipeline tasks are suspended
            [
                {"name": "DEDUP_FASTPATH_TASK", "state": "suspended", "schedule": "", "comment": ""},
                {"name": "VECTOR_PREP_TASK", "state": "suspended", "schedule": "", "comment": ""},
            ],
            [],
            [{"TOTAL_PENDING": 0, "MISSING_CATEGORY": 0, "HAS_CATEGORY": 0}],
            [],
            [],
            [{"TOTAL": 0}],
            [{"GET_PIPELINE_STATUS": '{"status": "idle"}'}],
        ]
        service = PipelineService(db_name="TEST_DB", sf=mock_sf, cache=None)

        result = await service.get_pipeline_tab_data()

        assert result["all_tasks_suspended"] is True

    @pytest.mark.asyncio
    async def test_get_pipeline_tab_data_with_cache(self, mock_sf: AsyncMock) -> None:
        """Test get_pipeline_tab_data uses cache for slow-changing data."""
        mock_cache = MagicMock()
        # Cache returns data directly
        mock_cache.get_or_fetch = AsyncMock(
            side_effect=[
                [{"TOTAL_PENDING": 100, "MISSING_CATEGORY": 10, "HAS_CATEGORY": 90}],
                [{"CONFIG_KEY": "DASHBOARD_AUTO_REFRESH", "CONFIG_VALUE": "off"}],
                [{"TOTAL": 25}],
            ]
        )
        mock_sf.query.side_effect = [
            [{"CNT": 100}],
            [{"name": "DEDUP_FASTPATH_TASK", "state": "started", "schedule": "", "comment": ""}],
            [],
            [],  # task history
            [{"GET_PIPELINE_STATUS": '{"status": "healthy"}'}],
        ]
        service = PipelineService(db_name="TEST_DB", sf=mock_sf, cache=mock_cache)

        result = await service.get_pipeline_tab_data()

        assert mock_cache.get_or_fetch.call_count == 3
        assert result["auto_refresh_enabled"] is False
        assert result["task_history_total"] == 25


# ---------------------------------------------------------------------------
# ComparisonService Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestComparisonService:
    """Tests for ComparisonService."""

    @pytest.mark.asyncio
    async def test_get_agreement_analysis_queries_view(self, mock_sf: AsyncMock) -> None:
        """Test get_agreement_analysis executes correct SQL."""
        mock_sf.query.return_value = [{"agreement_level": "4 of 4 Agree", "match_count": 100, "avg_confidence": 0.95}]
        service = ComparisonService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_agreement_analysis()

        assert len(result) == 1
        assert result[0]["agreement_level"] == "4 of 4 Agree"
        # Verify SQL contains expected clauses
        call_arg = mock_sf.query.call_args[0][0]
        assert "ITEM_MATCHES" in call_arg
        assert "SEARCH_MATCHED_ID" in call_arg

    @pytest.mark.asyncio
    async def test_get_source_performance_groups_by_source(self, mock_sf: AsyncMock) -> None:
        """Test get_source_performance returns per-source metrics."""
        mock_sf.query.return_value = [
            {
                "SOURCE_SYSTEM": "POS_A",
                "item_count": 500,
                "avg_search": 0.85,
                "avg_ensemble": 0.90,
            }
        ]
        service = ComparisonService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_source_performance()

        assert result[0]["SOURCE_SYSTEM"] == "POS_A"
        assert result[0]["item_count"] == 500

    @pytest.mark.asyncio
    async def test_compute_similarity_escapes_input(self, mock_sf: AsyncMock) -> None:
        """Test compute_similarity escapes special characters in input."""
        mock_sf.query.return_value = [{"cosine_sim": 0.9, "edit_sim": 0.8}]
        service = ComparisonService(db_name="TEST_DB", sf=mock_sf)

        await service.compute_similarity("test's input", "standard's text")

        call_arg = mock_sf.query.call_args[0][0]
        assert "test''s input" in call_arg
        assert "standard''s text" in call_arg


# ---------------------------------------------------------------------------
# TestingService Tests
# ---------------------------------------------------------------------------


class TestTestingService:
    """Tests for TestingService."""

    @pytest.mark.asyncio
    async def test_get_test_stats_returns_default_on_empty(self, mock_sf: AsyncMock) -> None:
        """Test get_test_stats returns default dict when no data."""
        mock_sf.query.return_value = []
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_test_stats()

        assert result["TOTAL_CASES"] == 0
        assert result["EASY_COUNT"] == 0

    @pytest.mark.asyncio
    async def test_get_test_stats_returns_data(self, mock_sf: AsyncMock) -> None:
        """Test get_test_stats returns query data."""
        mock_sf.query.return_value = [{"TOTAL_CASES": 100, "EASY_COUNT": 30, "MEDIUM_COUNT": 40, "HARD_COUNT": 30}]
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_test_stats()

        assert result["TOTAL_CASES"] == 100
        assert result["EASY_COUNT"] == 30

    @pytest.mark.asyncio
    async def test_get_latest_test_run_returns_row(self, mock_sf: AsyncMock) -> None:
        """Test get_latest_test_run returns most recent run."""
        mock_sf.query.return_value = [{"RUN_ID": "run-123", "TOTAL_TESTS": 100}]
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_latest_test_run()

        assert result is not None
        assert result["RUN_ID"] == "run-123"

    @pytest.mark.asyncio
    async def test_get_latest_test_run_returns_none_on_empty(self, mock_sf: AsyncMock) -> None:
        """Test get_latest_test_run returns None when no runs exist."""
        mock_sf.query.return_value = []
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_latest_test_run()

        assert result is None

    @pytest.mark.asyncio
    async def test_get_accuracy_summary(self, mock_sf: AsyncMock) -> None:
        """Test get_accuracy_summary returns method accuracy data."""
        mock_sf.query.return_value = [{"METHOD": "SEARCH", "TOP1_ACCURACY_PCT": 85.5}]
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_accuracy_summary()

        assert len(result) == 1
        assert result[0]["METHOD"] == "SEARCH"

    @pytest.mark.asyncio
    async def test_get_accuracy_by_difficulty(self, mock_sf: AsyncMock) -> None:
        """Test get_accuracy_by_difficulty returns breakdown data."""
        mock_sf.query.return_value = [{"METHOD": "SEARCH", "DIFFICULTY": "EASY", "TOP1_PCT": 95.0}]
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_accuracy_by_difficulty()

        assert len(result) == 1
        assert result[0]["DIFFICULTY"] == "EASY"

    @pytest.mark.asyncio
    async def test_get_failure_count(self, mock_sf: AsyncMock) -> None:
        """Test get_failure_count returns count."""
        mock_sf.query.return_value = [{"TOTAL_FAILURES": 25}]
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_failure_count()

        assert result == 25

    @pytest.mark.asyncio
    async def test_get_failure_count_empty(self, mock_sf: AsyncMock) -> None:
        """Test get_failure_count returns 0 on empty."""
        mock_sf.query.return_value = []
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_failure_count()

        assert result == 0

    @pytest.mark.asyncio
    async def test_get_failures_with_pagination(self, mock_sf: AsyncMock) -> None:
        """Test get_failures handles pagination and filtering."""
        mock_sf.query.side_effect = [
            [{"TOTAL": 25}],  # Count query
            [{"METHOD": "SEARCH", "TEST_INPUT": "test", "SCORE": 0.5}],  # Data query
        ]
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_failures(
            page=2,
            page_size=10,
            sort_col="METHOD",
            sort_dir="ASC",
            method_filter="All",
            difficulty_filter="HARD",
        )

        assert result["total_failures"] == 25
        assert result["total_pages"] == 3
        assert result["page"] == 2
        # Verify filter was applied
        count_query = mock_sf.query.call_args_list[0][0][0]
        assert "DIFFICULTY = 'HARD'" in count_query

    @pytest.mark.asyncio
    async def test_get_failures_validates_sort_column(self, mock_sf: AsyncMock) -> None:
        """Test get_failures validates and sanitizes sort column."""
        mock_sf.query.side_effect = [
            [{"TOTAL": 10}],
            [{"METHOD": "SEARCH"}],
        ]
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        await service.get_failures(
            page=1,
            page_size=10,
            sort_col="INVALID_COL",  # Should fall back to METHOD
            sort_dir="DESC",
            method_filter="All",
            difficulty_filter="All",
        )

        # Query should use default METHOD column
        data_query = mock_sf.query.call_args_list[1][0][0]
        assert "ORDER BY METHOD DESC" in data_query

    @pytest.mark.asyncio
    async def test_get_filter_options(self, mock_sf: AsyncMock) -> None:
        """Test get_filter_options returns methods and difficulties."""
        mock_sf.query.side_effect = [
            [{"METHOD": "SEARCH"}, {"METHOD": "COSINE"}],
            [{"DIFFICULTY": "EASY"}, {"DIFFICULTY": "HARD"}],
        ]
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_filter_options()

        assert result["methods"] == ["SEARCH", "COSINE"]
        assert result["difficulties"] == ["EASY", "HARD"]

    @pytest.mark.asyncio
    async def test_create_test_run_escapes_id(self, mock_sf: AsyncMock) -> None:
        """Test create_test_run escapes the run_id properly."""
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        await service.create_test_run("test's-run-id")

        call_arg = mock_sf.execute.call_args[0][0]
        assert "test''s-run-id" in call_arg

    @pytest.mark.asyncio
    async def test_run_test_procedure(self, mock_sf: AsyncMock) -> None:
        """Test run_test_procedure calls stored procedure."""
        mock_sf.execute.return_value = "OK"
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.run_test_procedure("TEST_CORTEX_SEARCH_ACCURACY", "run-123")

        assert result == "OK"
        call_arg = mock_sf.execute.call_args[0][0]
        assert "TEST_CORTEX_SEARCH_ACCURACY" in call_arg
        assert "run-123" in call_arg

    @pytest.mark.asyncio
    async def test_check_running_tests_returns_count(self, mock_sf: AsyncMock) -> None:
        """Test check_running_tests returns remaining count (expected - completed)."""
        # Method queries COMPLETED_METHODS and returns (expected_methods - completed)
        # Default expected_methods is 4, so 1 completed = 3 still running
        mock_sf.query.return_value = [{"COMPLETED_METHODS": 1}]
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.check_running_tests("run-123")

        assert result == 3  # 4 expected - 1 completed = 3 running

    @pytest.mark.asyncio
    async def test_check_running_tests_all_completed(self, mock_sf: AsyncMock) -> None:
        """Test check_running_tests returns 0 when all completed."""
        mock_sf.query.return_value = [{"COMPLETED_METHODS": 4}]
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.check_running_tests("run-123")

        assert result == 0

    @pytest.mark.asyncio
    async def test_check_running_tests_empty_result(self, mock_sf: AsyncMock) -> None:
        """Test check_running_tests handles empty result."""
        mock_sf.query.return_value = []
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.check_running_tests("run-123")

        assert result == 4  # All 4 still running

    @pytest.mark.asyncio
    async def test_finalize_test_run(self, mock_sf: AsyncMock) -> None:
        """Test finalize_test_run updates run with results."""
        mock_sf.query.return_value = [{"METHODS": "SEARCH, COSINE"}]
        mock_sf.execute.return_value = "OK"
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.finalize_test_run("run-123")

        assert result == "OK"
        execute_arg = mock_sf.execute.call_args[0][0]
        assert "UPDATE" in execute_arg
        assert "METHODS_TESTED" in execute_arg

    @pytest.mark.asyncio
    async def test_finalize_test_run_empty_methods(self, mock_sf: AsyncMock) -> None:
        """Test finalize_test_run handles empty methods."""
        mock_sf.query.return_value = []
        mock_sf.execute.return_value = "OK"
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.finalize_test_run("run-123")

        assert result == "OK"

    @pytest.mark.asyncio
    async def test_mark_run_cancelled(self, mock_sf: AsyncMock) -> None:
        """Test mark_run_cancelled updates run as cancelled."""
        mock_sf.query.return_value = [{"METHODS": "SEARCH"}]
        mock_sf.execute.return_value = "OK"
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.mark_run_cancelled("run-123")

        assert result == "OK"
        execute_arg = mock_sf.execute.call_args[0][0]
        assert "CANCELLED" in execute_arg

    @pytest.mark.asyncio
    async def test_mark_run_cancelled_no_completed(self, mock_sf: AsyncMock) -> None:
        """Test mark_run_cancelled with no completed methods."""
        mock_sf.query.return_value = [{"METHODS": ""}]
        mock_sf.execute.return_value = "OK"
        service = TestingService(db_name="TEST_DB", sf=mock_sf)

        result = await service.mark_run_cancelled("run-123")

        assert result == "OK"
        execute_arg = mock_sf.execute.call_args[0][0]
        assert "CANCELLED" in execute_arg


# ---------------------------------------------------------------------------
# LogsService Tests
# ---------------------------------------------------------------------------


class TestLogsService:
    """Tests for LogsService."""

    @pytest.mark.asyncio
    async def test_get_pipeline_logs_validates_sort(self, mock_sf: AsyncMock) -> None:
        """Test get_pipeline_logs validates and sanitizes sort column."""
        mock_sf.query.return_value = []
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        await service.get_pipeline_logs(
            step="All",
            status="All",
            category="All",
            sort_col="INVALID_COL",  # Should fall back to STARTED_AT
            sort_dir="DESC",
            page=1,
            page_size=20,
        )

        call_arg = mock_sf.query.call_args[0][0]
        assert "ORDER BY STARTED_AT DESC" in call_arg

    def test_pipeline_base_where_builds_clauses(self, mock_sf: AsyncMock) -> None:
        """Test _pipeline_base_where builds filter clauses."""
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        where = service._pipeline_base_where("All", "All")
        assert "DATEADD" in where
        assert "STEP_NAME" not in where

        where = service._pipeline_base_where("CLASSIFY", "Beverages")
        assert "STEP_NAME = 'CLASSIFY'" in where
        assert "CATEGORY = 'Beverages'" in where

    @pytest.mark.asyncio
    async def test_get_pipeline_logs_count_returns_total(self, mock_sf: AsyncMock) -> None:
        """Test get_pipeline_logs_count returns correct total."""
        mock_sf.query.return_value = [{"TOTAL": 42}]
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_pipeline_logs_count(step="All", status="All", category="All")
        assert result == 42

    @pytest.mark.asyncio
    async def test_get_pipeline_logs_count_returns_zero_on_empty(self, mock_sf: AsyncMock) -> None:
        """Test get_pipeline_logs_count returns 0 when no results."""
        mock_sf.query.return_value = []
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_pipeline_logs_count(step="All", status="All", category="All")
        assert result == 0

    @pytest.mark.asyncio
    async def test_get_recent_errors_returns_paginated(self, mock_sf: AsyncMock) -> None:
        """Test get_recent_errors returns paginated error logs."""
        mock_sf.query.return_value = [{"LOG_ID": 1, "ERROR_MESSAGE": "Test error"}]
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_recent_errors(page=1, page_size=10)
        assert len(result) == 1
        assert result[0]["ERROR_MESSAGE"] == "Test error"

    @pytest.mark.asyncio
    async def test_get_recent_errors_count(self, mock_sf: AsyncMock) -> None:
        """Test get_recent_errors_count returns count."""
        mock_sf.query.return_value = [{"TOTAL": 15}]
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_recent_errors_count()
        assert result == 15

    @pytest.mark.asyncio
    async def test_get_recent_errors_count_empty(self, mock_sf: AsyncMock) -> None:
        """Test get_recent_errors_count returns 0 on empty."""
        mock_sf.query.return_value = []
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_recent_errors_count()
        assert result == 0

    @pytest.mark.asyncio
    async def test_get_method_performance(self, mock_sf: AsyncMock) -> None:
        """Test get_method_performance returns performance logs."""
        mock_sf.query.return_value = [{"METHOD_NAME": "SEARCH", "DURATION_MS": 150}]
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_method_performance()
        assert len(result) == 1
        assert result[0]["METHOD_NAME"] == "SEARCH"

    @pytest.mark.asyncio
    async def test_get_audit_logs_paginated(self, mock_sf: AsyncMock) -> None:
        """Test get_audit_logs returns paginated audit entries."""
        mock_sf.query.return_value = [{"AUDIT_ID": 1, "ACTION": "CONFIRM"}]
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_audit_logs(page=1, page_size=10)
        assert len(result) == 1
        assert result[0]["ACTION"] == "CONFIRM"

    @pytest.mark.asyncio
    async def test_get_audit_logs_count(self, mock_sf: AsyncMock) -> None:
        """Test get_audit_logs_count returns total."""
        mock_sf.query.return_value = [{"TOTAL": 25}]
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_audit_logs_count()
        assert result == 25

    @pytest.mark.asyncio
    async def test_get_audit_logs_count_empty(self, mock_sf: AsyncMock) -> None:
        """Test get_audit_logs_count returns 0 on empty."""
        mock_sf.query.return_value = []
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_audit_logs_count()
        assert result == 0

    @pytest.mark.asyncio
    async def test_get_auto_refresh_config(self, mock_sf: AsyncMock) -> None:
        """Test get_auto_refresh_config returns config dict."""
        mock_sf.query.return_value = [
            {"CONFIG_KEY": "DASHBOARD_AUTO_REFRESH", "CONFIG_VALUE": "on"},
            {"CONFIG_KEY": "DASHBOARD_REFRESH_INTERVAL", "CONFIG_VALUE": "30"},
        ]
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_auto_refresh_config()
        assert result["DASHBOARD_AUTO_REFRESH"] == "on"
        assert result["DASHBOARD_REFRESH_INTERVAL"] == "30"

    @pytest.mark.asyncio
    async def test_get_filter_options_returns_all_options(self, mock_sf: AsyncMock) -> None:
        """Test get_filter_options returns steps, statuses, categories."""
        mock_sf.query.side_effect = [
            [{"STEP_NAME": "CLASSIFY"}, {"STEP_NAME": "MATCH"}],
            [{"STEP_STATUS": "STARTED"}, {"STEP_STATUS": "COMPLETED"}],
            [{"CATEGORY": "Beverages"}, {"CATEGORY": "Snacks"}],
        ]
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_filter_options()
        assert "steps" in result
        assert "statuses" in result
        assert "categories" in result
        assert "CLASSIFY" in result["steps"]
        # STARTED is filtered out, RUNNING is added
        assert "RUNNING" in result["statuses"]

    @pytest.mark.asyncio
    async def test_get_task_history_paginated(self, mock_sf: AsyncMock) -> None:
        """Test get_task_history returns paginated task history."""
        mock_sf.query.return_value = [{"TASK_NAME": "DEDUP_TASK", "STATE": "SUCCEEDED"}]
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_task_history(page=1, page_size=10)
        assert len(result) == 1
        assert result[0]["TASK_NAME"] == "DEDUP_TASK"

    @pytest.mark.asyncio
    async def test_get_task_history_count(self, mock_sf: AsyncMock) -> None:
        """Test get_task_history_count returns total."""
        mock_sf.query.return_value = [{"TOTAL": 100}]
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_task_history_count()
        assert result == 100

    @pytest.mark.asyncio
    async def test_get_task_history_count_empty(self, mock_sf: AsyncMock) -> None:
        """Test get_task_history_count returns 0 on empty."""
        mock_sf.query.return_value = []
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = await service.get_task_history_count()
        assert result == 0

    def test_pipeline_status_filter_all(self, mock_sf: AsyncMock) -> None:
        """Test _pipeline_status_filter returns empty for 'All'."""
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = service._pipeline_status_filter("All")
        assert result == ""

    def test_pipeline_status_filter_specific(self, mock_sf: AsyncMock) -> None:
        """Test _pipeline_status_filter builds WHERE clause for specific status."""
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        result = service._pipeline_status_filter("COMPLETED")
        assert "WHERE STEP_STATUS = 'COMPLETED'" in result

    def test_pipeline_status_filter_handles_all(self, mock_sf: AsyncMock) -> None:
        """Test _pipeline_status_filter returns empty string for 'All'."""
        service = LogsService(db_name="TEST_DB", sf=mock_sf)

        assert service._pipeline_status_filter("All") == ""
        assert "WHERE" in service._pipeline_status_filter("COMPLETED")


