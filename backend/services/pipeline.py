"""Pipeline management service layer.

Extracts SQL queries and business logic from pipeline route handlers
into reusable, testable methods. Routes handle HTTP/HTML/SSE concerns;
this service handles data access and transformation.
"""

from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import dataclass
from typing import Any, TypedDict

from backend.services.base import BaseService

logger = logging.getLogger(__name__)


class TaskMetadata(TypedDict):
    """Metadata for a single task in the DAG hierarchy.

    Attributes:
        role: Task role in the DAG (root, child, sibling, finalizer).
        level: Execution level (0=root, higher=later in pipeline).
        dag: DAG group name (e.g., 'stream_pipeline').
        schema: Snowflake schema where task resides (e.g., 'HARMONIZED', 'ANALYTICS').
    """

    role: str
    level: int
    dag: str
    schema: str


@dataclass
class PipelineService(BaseService):
    """Service for pipeline management, monitoring, and task control.

    Encapsulates all Snowflake queries related to the matching pipeline,
    including optimization metrics, latency data, error monitoring,
    task DAG management, and configuration.

    Attributes:
        DAG_HIERARCHY: Metadata dict mapping task names to their DAG role, level, and group.
        STREAM_PIPELINE_TASKS: Frozen set of all task names in the stream pipeline DAG.
        STREAM_PIPELINE_ROOT: Name of the root task that controls DAG execution.
        db_name: Inherited from BaseService - database name for fully qualified queries.
        sf: Inherited from BaseService - Snowflake client for query execution.
        cache: Inherited from BaseService - optional TTL cache for query results.

    Side Effects:
        - Executes SELECT queries against ANALYTICS views and CONFIG table
        - Executes SHOW TASKS to retrieve task states
        - Executes ALTER TASK to resume/suspend pipeline tasks
        - Calls stored procedures: GET_PIPELINE_STATUS, RESET_PIPELINE,
          ENABLE_PARALLEL_PIPELINE_TASKS, DISABLE_PARALLEL_PIPELINE_TASKS

    Thread Safety:
        Not thread-safe. Each request should use its own service instance
        via FastAPI dependency injection. DAG_HIERARCHY is initialized once
        in __post_init__ and is read-only thereafter.
    """

    # Stream Pipeline DAG structure
    DAG_HIERARCHY: dict[str, TaskMetadata] = None  # type: ignore[assignment]

    STREAM_PIPELINE_TASKS: frozenset[str] = frozenset(
        {
            "DEDUP_FASTPATH_TASK",
            "CLASSIFY_UNIQUE_TASK",
            "VECTOR_PREP_TASK",
            "CORTEX_SEARCH_TASK",
            "COSINE_MATCH_TASK",
            "EDIT_MATCH_TASK",
            "JACCARD_MATCH_TASK",
            "STAGING_MERGE_TASK",
        }
    )

    STREAM_PIPELINE_ROOT: str = "DEDUP_FASTPATH_TASK"

    def __post_init__(self) -> None:
        """Initialize DAG hierarchy metadata."""
        self.DAG_HIERARCHY = {
            # Stream Pipeline DAG (triggered by RAW_ITEMS_STREAM)
            "DEDUP_FASTPATH_TASK": {"role": "root", "level": 0, "dag": "stream_pipeline", "schema": "HARMONIZED"},
            "CLASSIFY_UNIQUE_TASK": {"role": "child", "level": 1, "dag": "stream_pipeline", "schema": "HARMONIZED"},
            "VECTOR_PREP_TASK": {"role": "child", "level": 2, "dag": "stream_pipeline", "schema": "HARMONIZED"},
            "CORTEX_SEARCH_TASK": {"role": "parallel", "level": 3, "dag": "stream_pipeline", "schema": "HARMONIZED"},
            "COSINE_MATCH_TASK": {"role": "parallel", "level": 3, "dag": "stream_pipeline", "schema": "HARMONIZED"},
            "EDIT_MATCH_TASK": {"role": "parallel", "level": 3, "dag": "stream_pipeline", "schema": "HARMONIZED"},
            "JACCARD_MATCH_TASK": {"role": "parallel", "level": 3, "dag": "stream_pipeline", "schema": "HARMONIZED"},
            "STAGING_MERGE_TASK": {"role": "finalizer", "level": 4, "dag": "stream_pipeline", "schema": "HARMONIZED"},
            # Decoupled Pipeline Tasks (independent, interval-based)
            "ENSEMBLE_SCORING_TASK": {"role": "root", "level": 0, "dag": "decoupled_pipeline", "schema": "HARMONIZED"},
            "ITEM_ROUTER_TASK": {"role": "root", "level": 0, "dag": "decoupled_pipeline", "schema": "HARMONIZED"},
            # Maintenance Tasks
            "CLEANUP_COORDINATION_TASK": {"role": "root", "level": 0, "dag": "maintenance", "schema": "HARMONIZED"},
            # Analytics Maintenance Tasks (cache refresh)
            "REFRESH_TASK_HISTORY_CACHE": {"role": "root", "level": 0, "dag": "maintenance", "schema": "ANALYTICS"},
            "CLEANUP_TASK_EXECUTION_CACHE": {"role": "root", "level": 0, "dag": "maintenance", "schema": "ANALYTICS"},
            "REFRESH_TASK_STATE_CACHE": {"role": "root", "level": 0, "dag": "maintenance", "schema": "ANALYTICS"},
        }

    # ------------------------------------------------------------------
    # Dashboard: Optimization metrics
    # ------------------------------------------------------------------

    async def get_optimization_data(self) -> dict[str, Any]:
        """Fetch pipeline optimization metrics from DT_OPTIMIZATION_METRICS.

        Returns:
            Dict with total_matches, cache_hits, rates, and early exit counts.
        """
        rows = await self.sf.query(f"SELECT * FROM {self.db_name}.ANALYTICS.DT_OPTIMIZATION_METRICS")
        row = rows[0] if rows else {}

        return {
            "total_matches": int(row.get("TOTAL_MATCHES", 0) or 0),
            "cache_hits": int(row.get("CACHE_HITS", 0) or 0),
            "cache_hit_rate_pct": float(row.get("CACHE_HIT_RATE_PCT", 0) or 0),
            "early_exit_4way": int(row.get("EARLY_EXIT_4WAY_COUNT", 0) or 0),
            "early_exit_3way": int(row.get("EARLY_EXIT_3WAY_COUNT", 0) or 0),
            "early_exit_2way": int(row.get("EARLY_EXIT_2WAY_COUNT", 0) or 0),
        }

    # ------------------------------------------------------------------
    # Dashboard: Latency data
    # ------------------------------------------------------------------

    async def get_latency_data(self) -> dict[str, Any]:
        """Fetch pipeline latency summary from V_PIPELINE_LATENCY_SUMMARY.

        Note: This uses a view (not a Dynamic Table) because it depends on
        V_TASK_EXECUTION_METRICS which uses TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
        with non-constant arguments - incompatible with Dynamic Tables.

        Returns:
            Dict with runs list, avg_latency, target_met count, and total_runs.
        """
        rows = await self.sf.query(f"""
            SELECT
                RUN_MINUTE,
                LATENCY_DISPLAY,
                TOTAL_LATENCY_SECONDS,
                CORTEX_SEARCH_SECONDS,
                COSINE_SECONDS,
                EDIT_SECONDS,
                JACCARD_SECONDS,
                PREP_SECONDS,
                ENSEMBLE_SECONDS,
                RUN_STATUS
            FROM {self.db_name}.ANALYTICS.V_PIPELINE_LATENCY_SUMMARY
            ORDER BY RUN_MINUTE DESC
            LIMIT 10
        """)

        return {
            "runs": rows,
            "avg_latency": (sum(r.get("TOTAL_LATENCY_SECONDS", 0) or 0 for r in rows) / len(rows) if rows else 0),
            "target_met": (sum(1 for r in rows if (r.get("TOTAL_LATENCY_SECONDS", 0) or 0) <= 300) if rows else 0),
            "total_runs": len(rows),
        }

    # ------------------------------------------------------------------
    # Monitoring: Pipeline errors
    # ------------------------------------------------------------------

    async def get_pipeline_errors(self, limit: int = 50) -> list[dict[str, Any]]:
        """Fetch recent pipeline errors from PIPELINE_ERRORS table.

        Args:
            limit: Maximum number of error rows to return.

        Returns:
            List of error dicts with ERROR_ID, PROCEDURE_NAME, etc.
        """
        return await self.sf.query(f"""
            SELECT
                ERROR_ID,
                PROCEDURE_NAME,
                ERROR_MESSAGE,
                ERROR_CONTEXT,
                TO_VARCHAR(CREATED_AT, 'YYYY-MM-DD HH24:MI:SS') AS timestamp
            FROM {self.db_name}.ANALYTICS.PIPELINE_ERRORS
            ORDER BY CREATED_AT DESC
            LIMIT {limit}
        """)

    # ------------------------------------------------------------------
    # Monitoring: Pipeline progress
    # ------------------------------------------------------------------

    async def get_pipeline_progress(self, limit: int = 20) -> list[dict[str, Any]]:
        """Fetch recent pipeline run progress from PIPELINE_RUN_PROGRESS.

        Args:
            limit: Maximum number of progress rows to return.

        Returns:
            List of progress dicts with RUN_ID, STATUS, counts, etc.
        """
        return await self.sf.query(f"""
            SELECT
                RUN_ID,
                PROCEDURE_NAME,
                BATCH_NUMBER,
                ITEMS_PROCESSED,
                ITEMS_MATCHED,
                ITEMS_FAILED,
                TO_VARCHAR(START_TIME, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
                TO_VARCHAR(END_TIME, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
                STATUS,
                RESULT_MESSAGE
            FROM {self.db_name}.ANALYTICS.PIPELINE_RUN_PROGRESS
            ORDER BY START_TIME DESC
            LIMIT {limit}
        """)

    # ------------------------------------------------------------------
    # Pipeline tab: Full data set
    # ------------------------------------------------------------------

    async def get_pipeline_tab_data(self) -> dict[str, Any]:
        """Fetch all data needed for the pipeline management tab.

        Runs multiple queries in parallel: pending count, SHOW TASKS,
        classification status, config, task history, pipeline status.

        Returns:
            Dict with all pipeline tab context data.
        """
        db = self.db_name

        # Cache keys for slow-changing data
        cache_key_config = f"{db}:pipeline_config"
        cache_key_classification = f"{db}:classification_status"
        cache_key_history_count = f"{db}:task_history_count"

        (
            pending_result,
            task_rows_result,
            classification_result,
            config_result,
            task_history_result,
            task_history_count_result,
            pipeline_status_result,
        ) = await asyncio.gather(
            self.sf.query(f"""
                SELECT COUNT(*) AS CNT FROM {db}.RAW.RAW_RETAIL_ITEMS
                WHERE MATCH_STATUS = 'PENDING'
            """),
            self._fetch_all_tasks(),
            self.cache.get_or_fetch(
                cache_key_classification,
                30.0,
                lambda: self.sf.query(f"""
                    SELECT
                        COUNT(*) AS TOTAL_PENDING,
                        SUM(CASE WHEN INFERRED_CATEGORY IS NULL THEN 1 ELSE 0 END) AS MISSING_CATEGORY,
                        SUM(CASE WHEN INFERRED_CATEGORY IS NOT NULL THEN 1 ELSE 0 END) AS HAS_CATEGORY
                    FROM {db}.RAW.RAW_RETAIL_ITEMS
                    WHERE MATCH_STATUS = 'PENDING'
                """),
            )
            if self.cache
            else self.sf.query(f"""
                SELECT
                    COUNT(*) AS TOTAL_PENDING,
                    SUM(CASE WHEN INFERRED_CATEGORY IS NULL THEN 1 ELSE 0 END) AS MISSING_CATEGORY,
                    SUM(CASE WHEN INFERRED_CATEGORY IS NOT NULL THEN 1 ELSE 0 END) AS HAS_CATEGORY
                FROM {db}.RAW.RAW_RETAIL_ITEMS
                WHERE MATCH_STATUS = 'PENDING'
            """),
            self.cache.get_or_fetch(
                cache_key_config,
                60.0,
                lambda: self.sf.query(
                    f"SELECT CONFIG_KEY, CONFIG_VALUE FROM {db}.ANALYTICS.CONFIG"
                    " WHERE CONFIG_KEY IN ('DASHBOARD_AUTO_REFRESH', 'DASHBOARD_REFRESH_INTERVAL')"
                    " AND IS_ACTIVE = TRUE"
                ),
            )
            if self.cache
            else self.sf.query(
                f"SELECT CONFIG_KEY, CONFIG_VALUE FROM {db}.ANALYTICS.CONFIG"
                " WHERE CONFIG_KEY IN ('DASHBOARD_AUTO_REFRESH', 'DASHBOARD_REFRESH_INTERVAL')"
                " AND IS_ACTIVE = TRUE"
            ),
            self.sf.query(f"""
                SELECT * FROM {db}.ANALYTICS.V_TASK_EXECUTION_HISTORY
                ORDER BY SCHEDULED_TIME DESC
                LIMIT 10
            """),
            self.cache.get_or_fetch(
                cache_key_history_count,
                30.0,
                lambda: self.sf.query(f"""
                    SELECT COUNT(*) AS TOTAL FROM {db}.ANALYTICS.V_TASK_EXECUTION_HISTORY
                """),
            )
            if self.cache
            else self.sf.query(f"""
                SELECT COUNT(*) AS TOTAL FROM {db}.ANALYTICS.V_TASK_EXECUTION_HISTORY
            """),
            self.sf.query(f"CALL {db}.HARMONIZED.GET_PIPELINE_STATUS()"),
            return_exceptions=True,
        )

        # --- Process config ---
        config: dict[str, str] = {}
        if not isinstance(config_result, Exception) and isinstance(config_result, list):
            for row in config_result:
                config[row.get("CONFIG_KEY", "")] = row.get("CONFIG_VALUE", "")
        auto_refresh_enabled = config.get("DASHBOARD_AUTO_REFRESH", "off").lower() == "on"

        # --- Process pipeline status ---
        pipeline_status = self._parse_pipeline_status(pipeline_status_result)

        # --- Process pending count ---
        pending_count = 0
        if not isinstance(pending_result, Exception) and isinstance(pending_result, list) and pending_result:
            pending_count = int(pending_result[0].get("CNT", 0) or 0)
        elif isinstance(pending_result, Exception):
            logger.warning(f"Failed to get pending count: {pending_result}")

        # --- Process tasks with DAG hierarchy ---
        tasks = self._process_task_rows(task_rows_result)

        # --- Compute DAG suspension state ---
        stream_tasks = [t for t in tasks if t.get("dag") == "stream_pipeline"]
        all_tasks_suspended = bool(stream_tasks) and all(t["state"] != "started" for t in stream_tasks)

        # --- Process classification status ---
        classification_status = self._parse_classification_status(classification_result)

        # --- Process task history ---
        task_history: list[dict[str, Any]] = []
        if not isinstance(task_history_result, Exception) and isinstance(task_history_result, list):
            task_history = task_history_result
        elif isinstance(task_history_result, Exception):
            logger.warning(f"Failed to get task execution history: {task_history_result}")

        # --- Process task history count ---
        task_history_total = 0
        if (
            not isinstance(task_history_count_result, Exception)
            and isinstance(task_history_count_result, list)
            and task_history_count_result
        ):
            task_history_total = int(task_history_count_result[0].get("TOTAL", 0) or 0)
        elif isinstance(task_history_count_result, Exception):
            logger.warning(f"Failed to get task history count: {task_history_count_result}")

        page_size = 10
        task_history_total_pages = max(1, (task_history_total + page_size - 1) // page_size)

        task_names = sorted({row.get("TASK_NAME", "") for row in task_history if row.get("TASK_NAME")})
        statuses = sorted({row.get("STATE", "") for row in task_history if row.get("STATE")})

        return {
            "pipeline_status": pipeline_status,
            "pending_count": pending_count,
            "tasks": tasks,
            "classification_status": classification_status,
            "auto_refresh_enabled": auto_refresh_enabled,
            "all_tasks_suspended": all_tasks_suspended,
            "task_history": task_history,
            "task_history_page": 1,
            "task_history_total_pages": task_history_total_pages,
            "task_history_total": task_history_total,
            "task_history_has_prev": False,
            "task_history_has_next": task_history_total_pages > 1,
            "page_size": page_size,
            "sort_col": "SCHEDULED_TIME",
            "sort_dir": "DESC",
            "task_filter": "All",
            "status_filter": "All",
            "task_names": task_names,
            "statuses": statuses,
        }

    # ------------------------------------------------------------------
    # Task management
    # ------------------------------------------------------------------

    async def get_task_status(self) -> list[dict[str, Any]]:
        """Fetch current Snowflake Task states via SHOW TASKS.

        Returns:
            List of task row dicts from SHOW TASKS (both HARMONIZED and ANALYTICS schemas).
        """
        import asyncio

        harmonized_tasks, analytics_tasks = await asyncio.gather(
            self.sf.query(f"SHOW TASKS IN SCHEMA {self.db_name}.HARMONIZED"),
            self.sf.query(f"SHOW TASKS IN SCHEMA {self.db_name}.ANALYTICS"),
        )
        return (harmonized_tasks or []) + (analytics_tasks or [])

    async def _fetch_all_tasks(self) -> list[dict[str, Any]]:
        """Fetch tasks from V_TASK_STATE_CACHE (deduplicated view over cached SHOW TASKS).

        Used by get_pipeline_tab_data for fast task state retrieval.
        Cache is refreshed every 30 seconds by REFRESH_TASK_STATE_CACHE task.
        View uses QUALIFY ROW_NUMBER() to guarantee one row per task name.

        Returns:
            Combined list of task row dicts from both HARMONIZED and ANALYTICS schemas.
        """
        # Query the deduplicated view (not the table) for guaranteed uniqueness
        # Column names match SHOW TASKS output for compatibility with _process_task_rows
        return (
            await self.sf.query(f"""
            SELECT
                TASK_NAME AS "name",
                DATABASE_NAME AS "database_name",
                SCHEMA_NAME AS "schema_name",
                STATE AS "state",
                SCHEDULE AS "schedule",
                PREDECESSORS AS "predecessors",
                WAREHOUSE AS "warehouse",
                COMMENT AS "comment"
            FROM {self.db_name}.ANALYTICS.V_TASK_STATE_CACHE
            WHERE SCHEMA_NAME IN ('HARMONIZED', 'ANALYTICS')
            ORDER BY SCHEMA_NAME, TASK_NAME
        """)
            or []
        )

    async def toggle_task(self, task_name: str, action: str) -> None:
        """Resume or suspend a Snowflake Task, respecting DAG constraints.

        For DAG child tasks, the root must be suspended first, then the child
        modified, then the root resumed. Decoupled tasks (independent roots)
        can be toggled directly.

        Args:
            task_name: Name of the task to toggle.
            action: Either "resume" or "suspend".

        Raises:
            ValueError: If task_name is not a valid pipeline task.
        """
        # Validate against all known tasks (stream pipeline + decoupled + maintenance)
        if task_name not in self.DAG_HIERARCHY:
            raise ValueError(f"Invalid task name: {task_name}")

        db = self.db_name
        task_meta = self.DAG_HIERARCHY[task_name]
        schema = task_meta.get("schema", "HARMONIZED")

        # Decoupled/maintenance tasks are independent roots - toggle directly
        if task_meta["dag"] in ("decoupled_pipeline", "maintenance"):
            if action == "resume":
                await self.sf.execute(f"ALTER TASK {db}.{schema}.{task_name} RESUME")
            elif action == "suspend":
                await self.sf.execute(f"ALTER TASK {db}.{schema}.{task_name} SUSPEND")
            # Refresh task state cache so UI reflects updated state immediately
            await self.sf.execute(f"CALL {db}.ANALYTICS.REFRESH_TASK_STATE_CACHE_PROC()")
            return

        # Stream pipeline tasks require DAG-aware toggling (always HARMONIZED schema)
        root = self.STREAM_PIPELINE_ROOT
        is_root = task_name == root

        if action == "resume":
            if is_root:
                await self.sf.execute(f"ALTER TASK {db}.HARMONIZED.{root} RESUME")
            else:
                # Suspend root -> resume child -> resume root
                await self.sf.execute(f"ALTER TASK {db}.HARMONIZED.{root} SUSPEND")
                await self.sf.execute(f"ALTER TASK {db}.HARMONIZED.{task_name} RESUME")
                await self.sf.execute(f"ALTER TASK {db}.HARMONIZED.{root} RESUME")
        elif action == "suspend":
            # Suspending any DAG task suspends via root
            await self.sf.execute(f"ALTER TASK {db}.HARMONIZED.{root} SUSPEND")

        # Refresh task state cache so UI reflects updated state immediately
        await self.sf.execute(f"CALL {db}.ANALYTICS.REFRESH_TASK_STATE_CACHE_PROC()")

    # ------------------------------------------------------------------
    # Pipeline control
    # ------------------------------------------------------------------

    async def reset_pipeline(self) -> str:
        """Reset the matching pipeline via RESET_PIPELINE stored procedure.

        Returns:
            Status message from the execute call.
        """
        return await self.sf.execute(f"CALL {self.db_name}.HARMONIZED.RESET_PIPELINE()")

    # ------------------------------------------------------------------
    # Configuration
    # ------------------------------------------------------------------

    async def get_batch_size_config(self) -> int:
        """Fetch DEFAULT_BATCH_SIZE from the CONFIG table.

        Returns:
            Batch size integer, defaults to 100 if not found.
        """
        rows = await self.sf.query(f"""
            SELECT CONFIG_VALUE::INT AS val
            FROM {self.db_name}.ANALYTICS.CONFIG
            WHERE CONFIG_KEY = 'DEFAULT_BATCH_SIZE'
        """)
        return rows[0]["val"] if rows else 100

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _parse_pipeline_status(self, result: Any) -> dict[str, Any]:
        """Parse GET_PIPELINE_STATUS procedure result into a dict.

        Args:
            result: Raw result from asyncio.gather (may be an Exception).

        Returns:
            Parsed pipeline status dict, or empty dict on failure.
        """
        if isinstance(result, Exception) or not isinstance(result, list) or not result:
            return {}

        row = result[0] if result else {}
        if not isinstance(row, dict):
            return {}

        for _key, val in row.items():
            if isinstance(val, dict):
                return val
            if isinstance(val, str):
                try:
                    return json.loads(val)
                except (json.JSONDecodeError, TypeError):
                    return {}
        return {}

    def _process_task_rows(self, result: Any) -> list[dict[str, Any]]:
        """Process SHOW TASKS result into sorted task list with DAG metadata.

        Args:
            result: Raw result from asyncio.gather (may be an Exception).

        Returns:
            Sorted list of task dicts with name, state, role, level, dag.
        """
        tasks: list[dict[str, Any]] = []
        if isinstance(result, Exception) or not isinstance(result, list):
            if isinstance(result, Exception):
                logger.warning(f"Failed to get tasks: {result}")
            return tasks

        for row in result:
            task_name = row.get("name", "")
            if task_name in self.DAG_HIERARCHY or "PIPELINE" in task_name.upper() or "MATCHING" in task_name.upper():
                info = self.DAG_HIERARCHY.get(task_name, {"role": "other", "level": 0, "dag": "other"})
                tasks.append(
                    {
                        "name": task_name,
                        "state": row.get("state", "").lower(),
                        "schedule": row.get("schedule", ""),
                        "description": row.get("comment", ""),
                        "role": info["role"],
                        "level": info["level"],
                        "dag": info["dag"],
                    }
                )

        tasks.sort(key=lambda t: (t.get("level", 99), t.get("name", "")))
        return tasks

    def _parse_classification_status(self, result: Any) -> dict[str, Any]:
        """Parse classification query result into status dict.

        Args:
            result: Raw result from asyncio.gather (may be an Exception).

        Returns:
            Dict with total, missing, has_category, pct_classified, classified_pending.
        """
        default = {
            "total": 0,
            "missing": 0,
            "has_category": 0,
            "pct_classified": 0,
            "classified_pending": 0,
        }

        if isinstance(result, Exception):
            logger.warning(f"Failed to get classification status: {result}")
            return default
        if not isinstance(result, list) or not result:
            return default

        row = result[0]
        total = int(row.get("TOTAL_PENDING", 0) or 0)
        missing = int(row.get("MISSING_CATEGORY", 0) or 0)
        has_cat = int(row.get("HAS_CATEGORY", 0) or 0)
        pct = round(has_cat / total * 100, 1) if total > 0 else 0

        return {
            "total": total,
            "missing": missing,
            "has_category": has_cat,
            "pct_classified": pct,
            "classified_pending": has_cat,
        }
