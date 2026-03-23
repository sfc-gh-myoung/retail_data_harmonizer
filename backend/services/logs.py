"""Logs service for pipeline execution, audit, and observability queries.

Provides read access to pipeline execution logs, audit trails, and task history.

Public API:
    - get_pipeline_logs: Paginated pipeline execution logs
    - get_recent_errors: Recent error log entries
    - get_audit_logs: Settings change audit trail
    - get_task_history: Snowflake Task execution history
    - get_filter_options: Available filter values for UI dropdowns
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from backend.services.base import BaseService


@dataclass
class LogsService(BaseService):
    """Service for logs and observability data queries.

    Provides methods to query pipeline execution logs, audit trails, error logs,
    and task history from the ANALYTICS schema.

    Key Methods:
        get_pipeline_logs: Main pipeline log query with filtering
        get_task_history: Snowflake task execution history

    Thread Safety:
        Safe for concurrent use (no shared mutable state).
    """

    async def get_pipeline_logs(
        self,
        step: str,
        status: str,
        category: str,
        sort_col: str,
        sort_dir: str,
        page: int,
        page_size: int,
    ) -> list[dict[str, Any]]:
        """Fetch consolidated pipeline execution logs with filtering and pagination.

        Args:
            step: Filter by step name (empty string for all steps).
            status: Filter by status: 'all', 'COMPLETED', 'FAILED', 'RUNNING'.
            category: Filter by category (empty string for all categories).
            sort_col: Column to sort by (e.g., 'STARTED_AT', 'DURATION_MS').
            sort_dir: Sort direction: 'asc' or 'desc'.
            page: Page number (1-indexed).
            page_size: Items per page.

        Returns:
            List of log entries with consolidated start/completion data.
        """
        db = self.db_name

        allowed_sort_cols = {
            "STARTED_AT",
            "COMPLETED_AT",
            "RUN_ID",
            "STEP_NAME",
            "STEP_STATUS",
            "CATEGORY",
            "ITEMS_PROCESSED",
            "ITEMS_FAILED",
            "DURATION_MS",
            "CREATED_AT",
        }
        sort_col, sort_dir = self._validate_sort(sort_col, sort_dir, allowed_sort_cols, "STARTED_AT")

        base_where = self._pipeline_base_where(step, category)
        status_filter = self._pipeline_status_filter(status)

        return await self.sf.query(f"""
            WITH step_starts AS (
                SELECT RUN_ID, STEP_NAME, CATEGORY, STARTED_AT, LOG_ID AS START_LOG_ID,
                       EXECUTION_MODE, CREATED_AT
                FROM {db}.ANALYTICS.PIPELINE_EXECUTION_LOG
                WHERE STEP_STATUS = 'STARTED'
                  AND {base_where}
            ),
            step_completions AS (
                SELECT RUN_ID, STEP_NAME, CATEGORY, STEP_STATUS, COMPLETED_AT,
                       DURATION_MS, ITEMS_PROCESSED, ITEMS_SKIPPED, ITEMS_FAILED,
                       ERROR_MESSAGE, LOG_ID AS COMPLETION_LOG_ID
                FROM {db}.ANALYTICS.PIPELINE_EXECUTION_LOG
                WHERE STEP_STATUS IN ('COMPLETED', 'FAILED', 'SKIPPED')
                  AND {base_where}
            ),
            consolidated AS (
                SELECT
                    COALESCE(c.COMPLETION_LOG_ID, s.START_LOG_ID) AS LOG_ID,
                    SUBSTR(s.RUN_ID, 1, 8) AS RUN_ID_SHORT,
                    s.RUN_ID,
                    s.STEP_NAME,
                    COALESCE(c.STEP_STATUS, 'RUNNING') AS STEP_STATUS,
                    COALESCE(c.ITEMS_PROCESSED, 0) AS ITEMS_PROCESSED,
                    COALESCE(c.ITEMS_SKIPPED, 0) AS ITEMS_SKIPPED,
                    COALESCE(c.ITEMS_FAILED, 0) AS ITEMS_FAILED,
                    c.DURATION_MS,
                    c.ERROR_MESSAGE,
                    s.EXECUTION_MODE,
                    s.CATEGORY,
                    TO_VARCHAR(s.STARTED_AT, 'YYYY-MM-DD HH24:MI:SS') AS STARTED_AT,
                    TO_VARCHAR(c.COMPLETED_AT, 'YYYY-MM-DD HH24:MI:SS') AS COMPLETED_AT,
                    TO_VARCHAR(s.CREATED_AT, 'YYYY-MM-DD HH24:MI') AS CREATED_AT
                FROM step_starts s
                LEFT JOIN step_completions c
                    ON s.RUN_ID = c.RUN_ID
                   AND s.STEP_NAME = c.STEP_NAME
                   AND COALESCE(s.CATEGORY, '') = COALESCE(c.CATEGORY, '')
            )
            SELECT * FROM consolidated
            {status_filter}
            ORDER BY {sort_col} {sort_dir} NULLS LAST
            LIMIT {page_size} OFFSET {(page - 1) * page_size}
        """)

    async def get_pipeline_logs_count(
        self,
        step: str,
        status: str,
        category: str,
    ) -> int:
        """Return total count of consolidated pipeline log rows for pagination."""
        db = self.db_name

        base_where = self._pipeline_base_where(step, category)
        status_filter = self._pipeline_status_filter(status)

        rows = await self.sf.query(f"""
            WITH step_starts AS (
                SELECT RUN_ID, STEP_NAME, CATEGORY
                FROM {db}.ANALYTICS.PIPELINE_EXECUTION_LOG
                WHERE STEP_STATUS = 'STARTED'
                  AND {base_where}
            ),
            step_completions AS (
                SELECT RUN_ID, STEP_NAME, CATEGORY, STEP_STATUS
                FROM {db}.ANALYTICS.PIPELINE_EXECUTION_LOG
                WHERE STEP_STATUS IN ('COMPLETED', 'FAILED', 'SKIPPED')
                  AND {base_where}
            ),
            consolidated AS (
                SELECT
                    COALESCE(c.STEP_STATUS, 'RUNNING') AS STEP_STATUS
                FROM step_starts s
                LEFT JOIN step_completions c
                    ON s.RUN_ID = c.RUN_ID
                   AND s.STEP_NAME = c.STEP_NAME
                   AND COALESCE(s.CATEGORY, '') = COALESCE(c.CATEGORY, '')
            )
            SELECT COUNT(*) AS TOTAL FROM consolidated
            {status_filter}
        """)
        return rows[0]["TOTAL"] if rows else 0

    async def get_recent_errors(self, page: int, page_size: int) -> list[dict[str, Any]]:
        """Fetch recent failed pipeline steps with pagination."""
        db = self.db_name
        return await self.sf.query(f"""
            SELECT
                LOG_ID,
                RUN_ID,
                STEP_NAME,
                CATEGORY,
                ERROR_MESSAGE,
                ITEMS_FAILED,
                QUERY_ID,
                TO_VARCHAR(CREATED_AT, 'YYYY-MM-DD HH24:MI') AS CREATED_AT
            FROM {db}.ANALYTICS.PIPELINE_EXECUTION_LOG
            WHERE STEP_STATUS = 'FAILED'
              AND CREATED_AT >= DATEADD('day', -7, CURRENT_DATE())
            ORDER BY CREATED_AT DESC
            LIMIT {page_size} OFFSET {(page - 1) * page_size}
        """)

    async def get_recent_errors_count(self) -> int:
        """Return total count of recent errors for pagination."""
        db = self.db_name
        rows = await self.sf.query(f"""
            SELECT COUNT(*) AS TOTAL
            FROM {db}.ANALYTICS.PIPELINE_EXECUTION_LOG
            WHERE STEP_STATUS = 'FAILED'
              AND CREATED_AT >= DATEADD('day', -7, CURRENT_DATE())
        """)
        return rows[0]["TOTAL"] if rows else 0

    async def get_method_performance(self) -> list[dict[str, Any]]:
        """Fetch method performance logs from the last 7 days."""
        db = self.db_name
        return await self.sf.query(f"""
            SELECT
                LOG_ID,
                RUN_ID,
                METHOD_NAME,
                CATEGORY,
                ITEMS_PROCESSED,
                AVG_SCORE,
                MIN_SCORE,
                MAX_SCORE,
                CACHE_HITS,
                EARLY_EXITS,
                DURATION_MS,
                TO_VARCHAR(CREATED_AT, 'YYYY-MM-DD HH24:MI') AS CREATED_AT
            FROM {db}.ANALYTICS.METHOD_PERFORMANCE_LOG
            WHERE CREATED_AT >= DATEADD('day', -7, CURRENT_DATE())
            ORDER BY CREATED_AT DESC
            LIMIT 100
        """)

    async def get_audit_logs(self, page: int, page_size: int) -> list[dict[str, Any]]:
        """Fetch audit trail entries with pagination."""
        db = self.db_name
        return await self.sf.query(f"""
            SELECT
                AUDIT_ID,
                MATCH_ID,
                ACTION,
                OLD_STATUS,
                NEW_STATUS,
                REVIEWED_BY,
                NOTES,
                TO_VARCHAR(CREATED_AT, 'YYYY-MM-DD HH24:MI') AS CREATED_AT
            FROM {db}.ANALYTICS.MATCH_AUDIT_LOG
            WHERE CREATED_AT >= DATEADD('day', -7, CURRENT_DATE())
            ORDER BY CREATED_AT DESC
            LIMIT {page_size} OFFSET {(page - 1) * page_size}
        """)

    async def get_audit_logs_count(self) -> int:
        """Return total count of audit log entries for pagination."""
        db = self.db_name
        rows = await self.sf.query(f"""
            SELECT COUNT(*) AS TOTAL
            FROM {db}.ANALYTICS.MATCH_AUDIT_LOG
            WHERE CREATED_AT >= DATEADD('day', -7, CURRENT_DATE())
        """)
        return rows[0]["TOTAL"] if rows else 0

    async def get_auto_refresh_config(self) -> dict[str, str]:
        """Fetch dashboard auto-refresh configuration values."""
        db = self.db_name
        rows = await self.sf.query(
            f"SELECT CONFIG_KEY, CONFIG_VALUE FROM {db}.ANALYTICS.CONFIG"
            " WHERE CONFIG_KEY IN ('DASHBOARD_AUTO_REFRESH', 'DASHBOARD_REFRESH_INTERVAL')"
        )
        return {r["CONFIG_KEY"]: r["CONFIG_VALUE"] for r in rows}

    async def get_filter_options(self) -> dict[str, list[str]]:
        """Fetch distinct step, status, and category values for filter dropdowns."""
        db = self.db_name
        import asyncio

        step_rows, status_rows, category_rows = await asyncio.gather(
            self.sf.query(f"""
                SELECT DISTINCT STEP_NAME
                FROM {db}.ANALYTICS.PIPELINE_EXECUTION_LOG
                WHERE CREATED_AT >= DATEADD('day', -30, CURRENT_DATE())
                  AND STEP_NAME IS NOT NULL
                ORDER BY STEP_NAME
            """),
            self.sf.query(f"""
                SELECT DISTINCT STEP_STATUS
                FROM {db}.ANALYTICS.PIPELINE_EXECUTION_LOG
                WHERE CREATED_AT >= DATEADD('day', -30, CURRENT_DATE())
                  AND STEP_STATUS IS NOT NULL
                ORDER BY STEP_STATUS
            """),
            self.sf.query(f"""
                SELECT DISTINCT CATEGORY
                FROM {db}.ANALYTICS.PIPELINE_EXECUTION_LOG
                WHERE CREATED_AT >= DATEADD('day', -30, CURRENT_DATE())
                  AND CATEGORY IS NOT NULL
                ORDER BY CATEGORY
            """),
        )

        steps = [r["STEP_NAME"] for r in step_rows]
        statuses = [r["STEP_STATUS"] for r in status_rows if r["STEP_STATUS"] != "STARTED"]
        if "RUNNING" not in statuses:
            statuses = ["RUNNING", *statuses]
        categories = [r["CATEGORY"] for r in category_rows]

        return {"steps": steps, "statuses": statuses, "categories": categories}

    async def get_task_history(
        self,
        page: int = 1,
        page_size: int = 10,
        task_name: str = "",
        state: str = "",
    ) -> list[dict[str, Any]]:
        """Fetch task execution history ordered by most recent with pagination.

        Args:
            page: Page number (1-indexed).
            page_size: Items per page.
            task_name: Filter by task name (partial match via ILIKE).
            state: Filter by exact state (SUCCEEDED, FAILED, etc.).
        """
        db = self.db_name
        where_clause = self._task_history_where(task_name, state)
        return await self.sf.query(f"""
            SELECT * FROM {db}.ANALYTICS.V_TASK_EXECUTION_HISTORY
            {where_clause}
            ORDER BY SCHEDULED_TIME DESC NULLS LAST
            LIMIT {page_size} OFFSET {(page - 1) * page_size}
        """)

    async def get_task_history_count(self, task_name: str = "", state: str = "") -> int:
        """Return total count of task execution history rows with optional filters."""
        db = self.db_name
        where_clause = self._task_history_where(task_name, state)
        rows = await self.sf.query(f"""
            SELECT COUNT(*) AS TOTAL FROM {db}.ANALYTICS.V_TASK_EXECUTION_HISTORY
            {where_clause}
        """)
        return rows[0]["TOTAL"] if rows else 0

    async def get_task_filter_options(self) -> dict[str, list[str]]:
        """Fetch distinct task names and states for filter dropdowns."""
        db = self.db_name
        import asyncio

        task_rows, state_rows = await asyncio.gather(
            self.sf.query(f"""
                SELECT DISTINCT TASK_NAME
                FROM {db}.ANALYTICS.V_TASK_EXECUTION_HISTORY
                WHERE TASK_NAME IS NOT NULL
                ORDER BY TASK_NAME
            """),
            self.sf.query(f"""
                SELECT DISTINCT STATE
                FROM {db}.ANALYTICS.V_TASK_EXECUTION_HISTORY
                WHERE STATE IS NOT NULL
                ORDER BY STATE
            """),
        )

        return {
            "taskNames": [r["TASK_NAME"] for r in task_rows],
            "states": [r["STATE"] for r in state_rows],
        }

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _pipeline_base_where(self, step: str, category: str) -> str:
        """Build base WHERE clause for pipeline log CTEs."""
        clauses = ["CREATED_AT >= DATEADD('day', -7, CURRENT_DATE())"]
        if step != "All":
            clauses.append(f"STEP_NAME = '{self._safe(step)}'")
        if category != "All":
            clauses.append(f"CATEGORY = '{self._safe(category)}'")
        return " AND ".join(clauses)

    def _pipeline_status_filter(self, status: str) -> str:
        """Build status WHERE clause for the consolidated CTE result."""
        if status == "All":
            return ""
        safe_status = self._safe(status)
        return f"WHERE STEP_STATUS = '{safe_status}'"

    def _task_history_where(self, task_name: str, state: str) -> str:
        """Build WHERE clause for task history filters."""
        clauses: list[str] = []
        if task_name:
            clauses.append(f"TASK_NAME ILIKE '%{self._safe(task_name)}%'")
        if state:
            clauses.append(f"STATE = '{self._safe(state)}'")
        return f"WHERE {' AND '.join(clauses)}" if clauses else ""
