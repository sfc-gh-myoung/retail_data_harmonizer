"""Testing service for accuracy test queries and execution.

Extracts SQL queries from testing route handlers into a reusable service layer.
Manages the full accuracy test lifecycle: create → run → poll → finalize/cancel.

Public API:
    Read Operations:
        - get_latest_test_run: Most recent test run metadata
        - get_test_stats: Test set statistics by difficulty
        - get_accuracy_summary: Accuracy metrics by method
        - get_accuracy_by_difficulty: Accuracy breakdown by method and difficulty
        - get_failures: Paginated test failures
        - get_filter_options: Filter dropdown values
        - check_running_tests: Poll for completion status

    Write Operations:
        - create_test_run: INSERT into ACCURACY_TEST_RUNS
        - run_test_procedure: CALL stored procedure for accuracy test
        - finalize_test_run: UPDATE test run with final results
        - mark_run_cancelled: UPDATE test run as cancelled

Side Effects:
    - create_test_run: INSERT into ACCURACY_TEST_RUNS
    - run_test_procedure: CALL stored procedures (TEST_*_ACCURACY) which INSERT into ACCURACY_TEST_RESULTS
    - finalize_test_run/mark_run_cancelled: UPDATE ACCURACY_TEST_RUNS
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from backend.services.base import BaseService


@dataclass
class TestingService(BaseService):
    """Service for accuracy testing data queries and test execution.

    Manages the full accuracy test lifecycle:
    1. create_test_run: Create a new test run record (PENDING state)
    2. run_test_procedure: Execute stored procedures for each method (RUNNING state)
    3. check_running_tests: Poll for completion by counting result rows
    4. finalize_test_run: Update run with results (COMPLETED state)
    5. mark_run_cancelled: Mark run as cancelled if interrupted

    Side Effects:
        - create_test_run: INSERT into ACCURACY_TEST_RUNS
        - run_test_procedure: CALL TEST_*_ACCURACY procedures which INSERT into ACCURACY_TEST_RESULTS
        - finalize_test_run: UPDATE ACCURACY_TEST_RUNS with TOTAL_TESTS, METHODS_TESTED
        - mark_run_cancelled: UPDATE ACCURACY_TEST_RUNS with CANCELLED status

    Thread Safety:
        Safe for concurrent use. Each test run uses a unique RUN_ID (UUID).
    """

    __test__ = False  # Not a pytest test class

    async def get_latest_test_run(self) -> dict[str, Any] | None:
        """Fetch the most recent accuracy test run.

        Returns:
            Single row dict with RUN_ID, RUN_TIMESTAMP, TOTAL_TESTS,
            METHODS_TESTED, or None if no runs exist.
        """
        db = self.db_name
        rows = await self.sf.query(f"""
            SELECT
                RUN_ID,
                RUN_TIMESTAMP,
                TOTAL_TESTS,
                METHODS_TESTED
            FROM {db}.ANALYTICS.ACCURACY_TEST_RUNS
            ORDER BY RUN_TIMESTAMP DESC
            LIMIT 1
        """)
        return rows[0] if rows else None

    async def get_test_stats(self) -> dict[str, Any]:
        """Fetch test set statistics by difficulty level.

        Returns:
            Dict with TOTAL_CASES, EASY/MEDIUM/HARD counts and percentages.
        """
        db = self.db_name
        rows = await self.sf.query(f"""
            SELECT
                COUNT(*) AS TOTAL_CASES,
                SUM(CASE WHEN DIFFICULTY = 'EASY' THEN 1 ELSE 0 END) AS EASY_COUNT,
                SUM(CASE WHEN DIFFICULTY = 'MEDIUM' THEN 1 ELSE 0 END) AS MEDIUM_COUNT,
                SUM(CASE WHEN DIFFICULTY = 'HARD' THEN 1 ELSE 0 END) AS HARD_COUNT,
                ROUND(100.0 * SUM(CASE WHEN DIFFICULTY = 'EASY' THEN 1 ELSE 0 END) / COUNT(*), 1) AS EASY_PCT,
                ROUND(100.0 * SUM(CASE WHEN DIFFICULTY = 'MEDIUM' THEN 1 ELSE 0 END) / COUNT(*), 1) AS MEDIUM_PCT,
                ROUND(100.0 * SUM(CASE WHEN DIFFICULTY = 'HARD' THEN 1 ELSE 0 END) / COUNT(*), 1) AS HARD_PCT
            FROM {db}.ANALYTICS.ACCURACY_TEST_SET
            WHERE EXPECTED_ITEM_ID IS NOT NULL
        """)
        return (
            rows[0]
            if rows
            else {
                "TOTAL_CASES": 0,
                "EASY_COUNT": 0,
                "MEDIUM_COUNT": 0,
                "HARD_COUNT": 0,
                "EASY_PCT": 0,
                "MEDIUM_PCT": 0,
                "HARD_PCT": 0,
            }
        )

    async def get_accuracy_summary(self) -> list[dict[str, Any]]:
        """Fetch accuracy summary by method from V_ACCURACY_SUMMARY.

        Returns:
            List of rows with METHOD, TOP1/TOP3/TOP5_ACCURACY_PCT.
        """
        db = self.db_name
        return await self.sf.query(f"""
            SELECT
                METHOD,
                TOP1_ACCURACY_PCT,
                TOP3_ACCURACY_PCT,
                TOP5_ACCURACY_PCT
            FROM {db}.ANALYTICS.V_ACCURACY_SUMMARY
            ORDER BY TOP1_ACCURACY_PCT DESC
        """)

    async def get_accuracy_by_difficulty(self) -> list[dict[str, Any]]:
        """Fetch accuracy breakdown by method and difficulty.

        Returns:
            List of rows with METHOD, DIFFICULTY, TESTS, TOP1_PCT.
        """
        db = self.db_name
        return await self.sf.query(f"""
            SELECT
                METHOD,
                DIFFICULTY,
                TESTS,
                TOP1_PCT
            FROM {db}.ANALYTICS.V_ACCURACY_BY_DIFFICULTY
            ORDER BY METHOD,
                CASE DIFFICULTY WHEN 'EASY' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'HARD' THEN 3 END
        """)

    async def get_failure_count(self) -> int:
        """Fetch total count of accuracy test failures.

        Returns:
            Integer count of failures.
        """
        db = self.db_name
        rows = await self.sf.query(f"""
            SELECT COUNT(*) AS TOTAL_FAILURES
            FROM {db}.ANALYTICS.V_ACCURACY_FAILURES
        """)
        return int(rows[0].get("TOTAL_FAILURES", 0) if rows else 0)

    async def get_failures(
        self,
        page: int,
        page_size: int,
        sort_col: str,
        sort_dir: str,
        method_filter: str,
        difficulty_filter: str,
    ) -> dict[str, Any]:
        """Fetch paginated test failures with sorting and filtering.

        Args:
            page: 1-based page number.
            page_size: Number of rows per page.
            sort_col: Column name to sort by.
            sort_dir: Sort direction (ASC/DESC).
            method_filter: Filter by METHOD value, or 'All'.
            difficulty_filter: Filter by DIFFICULTY value, or 'All'.

        Returns:
            Dict with keys: failures, total_failures, total_pages, page.
        """
        db = self.db_name

        allowed_sort_cols = {"METHOD", "TEST_INPUT", "SCORE", "DIFFICULTY"}
        sort_col, sort_dir = self._validate_sort(sort_col, sort_dir, allowed_sort_cols, "METHOD")

        sort_col_map = {"TEST_INPUT": "RAW_DESCRIPTION"}
        db_sort_col = sort_col_map.get(sort_col, sort_col)

        filter_map = {"method_filter": "METHOD", "difficulty_filter": "DIFFICULTY"}
        where_sql = self._build_filter_clause(
            {"method_filter": method_filter, "difficulty_filter": difficulty_filter},
            filter_map,
        )

        count_result = await self.sf.query(f"""
            SELECT COUNT(*) AS TOTAL
            FROM {db}.ANALYTICS.V_ACCURACY_FAILURES
            WHERE {where_sql}
        """)
        total_failures = int(count_result[0].get("TOTAL", 0) if count_result else 0)
        total_pages = max(1, (total_failures + page_size - 1) // page_size)

        page = min(page, total_pages)
        offset = (page - 1) * page_size

        nulls_order = "NULLS LAST" if sort_dir == "ASC" else "NULLS FIRST"
        failures = await self.sf.query(f"""
            SELECT
                METHOD,
                RAW_DESCRIPTION AS TEST_INPUT,
                EXPECTED_MATCH,
                ACTUAL_MATCH,
                SCORE,
                DIFFICULTY
            FROM {db}.ANALYTICS.V_ACCURACY_FAILURES
            WHERE {where_sql}
            ORDER BY {db_sort_col} {sort_dir} {nulls_order}
            LIMIT {page_size}
            OFFSET {offset}
        """)

        return {
            "failures": failures,
            "total_failures": total_failures,
            "total_pages": total_pages,
            "page": page,
        }

    async def get_filter_options(self) -> dict[str, list[str]]:
        """Fetch distinct METHOD and DIFFICULTY values for filter dropdowns.

        Returns:
            Dict with keys: methods, difficulties (each a list of strings).
        """
        db = self.db_name
        methods = await self.sf.query(f"""
            SELECT DISTINCT METHOD FROM {db}.ANALYTICS.V_ACCURACY_FAILURES ORDER BY METHOD
        """)
        difficulties = await self.sf.query(f"""
            SELECT DISTINCT DIFFICULTY FROM {db}.ANALYTICS.V_ACCURACY_FAILURES ORDER BY DIFFICULTY
        """)
        return {
            "methods": [r.get("METHOD", "") for r in methods],
            "difficulties": [r.get("DIFFICULTY", "") for r in difficulties],
        }

    async def create_test_run(self, run_id: str) -> str:
        """Insert a new accuracy test run record.

        Args:
            run_id: UUID string for the test run.

        Returns:
            Status message from execute.
        """
        db = self.db_name
        safe_id = self._safe(run_id)
        return await self.sf.execute(f"""
            INSERT INTO {db}.ANALYTICS.ACCURACY_TEST_RUNS (RUN_ID, NOTES)
            VALUES ('{safe_id}', 'UI-triggered accuracy test run')
        """)

    async def run_test_procedure(self, proc_name: str, run_id: str) -> str:
        """Call an accuracy test stored procedure.

        Args:
            proc_name: Procedure name (e.g. TEST_CORTEX_SEARCH_ACCURACY).
            run_id: UUID string for the test run.

        Returns:
            Status message from execute.
        """
        db = self.db_name
        safe_id = self._safe(run_id)
        return await self.sf.execute(f"CALL {db}.ANALYTICS.{proc_name}('{safe_id}')")

    async def check_running_tests(self, run_id: str, expected_methods: int = 4) -> int:
        """Check count of still-running tests for a given run.

        Compares the number of distinct methods with results against
        the expected count to determine if tests are still in progress.

        Args:
            run_id: UUID string for the test run.
            expected_methods: Number of methods expected (default 4: cortex, cosine, edit, jaccard).

        Returns:
            Count of tests still running (expected - completed).
        """
        db = self.db_name
        safe_id = self._safe(run_id)

        # Count distinct methods that have completed results for this run
        result = await self.sf.query(f"""
            SELECT COUNT(DISTINCT METHOD) AS COMPLETED_METHODS
            FROM {db}.ANALYTICS.ACCURACY_TEST_RESULTS
            WHERE RUN_ID = '{safe_id}'
        """)
        completed = int(result[0].get("COMPLETED_METHODS", 0)) if result else 0

        # Return how many are still running
        return max(0, expected_methods - completed)

    async def finalize_test_run(self, run_id: str) -> str:
        """Update a test run record with final results.

        Populates TOTAL_TESTS and METHODS_TESTED from ACCURACY_TEST_RESULTS.

        Args:
            run_id: UUID string for the test run.

        Returns:
            Status message from execute.
        """
        db = self.db_name
        safe_id = self._safe(run_id)

        methods_result = await self.sf.query(f"""
            SELECT LISTAGG(DISTINCT METHOD, ', ') WITHIN GROUP (ORDER BY METHOD) AS METHODS
            FROM {db}.ANALYTICS.ACCURACY_TEST_RESULTS
            WHERE RUN_ID = '{safe_id}'
        """)
        methods_str = self._safe(methods_result[0].get("METHODS", "") if methods_result else "")

        return await self.sf.execute(f"""
            UPDATE {db}.ANALYTICS.ACCURACY_TEST_RUNS
            SET TOTAL_TESTS = (
                    SELECT COUNT(DISTINCT TEST_ID)
                    FROM {db}.ANALYTICS.ACCURACY_TEST_RESULTS
                    WHERE RUN_ID = '{safe_id}'
                ),
                METHODS_TESTED = '{methods_str}'
            WHERE RUN_ID = '{safe_id}'
        """)

    async def mark_run_cancelled(self, run_id: str) -> str:
        """Mark a test run as cancelled.

        Updates the METHODS_TESTED field to indicate cancellation.

        Args:
            run_id: UUID string for the test run.

        Returns:
            Status message from execute.
        """
        db = self.db_name
        safe_id = self._safe(run_id)

        # Get any methods that completed before cancellation
        methods_result = await self.sf.query(f"""
            SELECT LISTAGG(DISTINCT METHOD, ', ') WITHIN GROUP (ORDER BY METHOD) AS METHODS
            FROM {db}.ANALYTICS.ACCURACY_TEST_RESULTS
            WHERE RUN_ID = '{safe_id}'
        """)
        completed_methods = methods_result[0].get("METHODS", "") if methods_result else ""

        # Build status string indicating cancellation
        status_str = f"CANCELLED (completed: {completed_methods})" if completed_methods else "CANCELLED"
        status_str = self._safe(status_str)

        return await self.sf.execute(f"""
            UPDATE {db}.ANALYTICS.ACCURACY_TEST_RUNS
            SET TOTAL_TESTS = (
                    SELECT COUNT(DISTINCT TEST_ID)
                    FROM {db}.ANALYTICS.ACCURACY_TEST_RESULTS
                    WHERE RUN_ID = '{safe_id}'
                ),
                METHODS_TESTED = '{status_str}'
            WHERE RUN_ID = '{safe_id}'
        """)
