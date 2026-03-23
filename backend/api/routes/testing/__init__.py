"""Testing API routes (JSON API v2 only).

Provides accuracy testing endpoints for the React frontend. Tests compare
matching algorithms (cortex_search, cosine, edit_distance, jaccard, ensemble)
against a labeled test set to measure top-1/3/5 accuracy.

Endpoints:
    GET /dashboard: Test verification dashboard data (latest run, stats, accuracy).
    GET /failures: Paginated test failures with sorting and filtering.
    POST /run: Launch accuracy tests in background for selected methods.
    GET /status/{run_id}: Poll test run completion status.
    POST /cancel: Cancel an active test run.

Side Effects:
    - POST /run: INSERT into ACCURACY_TEST_RUNS, CALL TEST_*_ACCURACY procedures
      (which INSERT into ACCURACY_TEST_RESULTS). Runs as background asyncio task.
    - GET /status/{run_id}: UPDATE ACCURACY_TEST_RUNS on completion (finalize_test_run).
    - POST /cancel: Cancels asyncio task, UPDATE ACCURACY_TEST_RUNS with CANCELLED status.
    - Module-level _active_runs dict tracks background tasks (mutated by run/cancel).
"""

from __future__ import annotations

import asyncio
import logging
import uuid

from fastapi import APIRouter, Query
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from backend.api.deps import TestingServiceDep

router = APIRouter(prefix="/api/v2/testing", tags=["testing"])

logger = logging.getLogger("retail_harmonizer.api")

# Background task tracking: run_id -> asyncio.Task mapping
_active_runs: dict[str, asyncio.Task] = {}

# Track background tasks for graceful shutdown
_background_tasks: set[asyncio.Task] = set()


# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------


class RunTestsRequest(BaseModel):
    """Request body for running accuracy tests."""

    methods: list[str]


class RunTestsResponse(BaseModel):
    """Response for run tests endpoint."""

    runId: str
    status: str
    methods: list[str]


class TestStatusResponse(BaseModel):
    """Response for test status check."""

    status: str
    runningCount: int


class CancelTestsResponse(BaseModel):
    """Response for cancel tests endpoint."""

    runId: str
    status: str
    message: str


# ---------------------------------------------------------------------------
# Background task runner
# ---------------------------------------------------------------------------


async def _run_tests_in_background(svc: TestingServiceDep, run_id: str, methods: list[str]) -> None:
    """Execute accuracy test procedures in the background."""
    proc_map = {
        "cortex_search": "TEST_CORTEX_SEARCH_ACCURACY",
        "cosine": "TEST_COSINE_ACCURACY",
        "edit_distance": "TEST_EDIT_DISTANCE_ACCURACY",
        "jaccard": "TEST_JACCARD_ACCURACY",
        "ensemble": "TEST_ENSEMBLE_ACCURACY",
    }
    try:
        for method in methods:
            proc_name = proc_map.get(method)
            if proc_name:
                logger.info(f"Background test: starting {proc_name} for run {run_id[:8]}...")
                await svc.run_test_procedure(proc_name, run_id)
                logger.info(f"Background test: completed {proc_name} for run {run_id[:8]}")
    except asyncio.CancelledError:
        logger.warning(f"Background test run {run_id[:8]} was cancelled")
        await svc.mark_run_cancelled(run_id)
        raise
    except Exception as e:
        logger.exception(f"Background test execution failed for run {run_id[:8]}: {e}")
    finally:
        _active_runs.pop(run_id, None)


# ---------------------------------------------------------------------------
# JSON API endpoints
# ---------------------------------------------------------------------------


@router.get("/dashboard")
async def get_testing_dashboard(svc: TestingServiceDep):
    """Return test verification dashboard data as JSON."""
    test_run, test_stats, accuracy_summary, accuracy_by_difficulty, total_failures = await asyncio.gather(
        svc.get_latest_test_run(),
        svc.get_test_stats(),
        svc.get_accuracy_summary(),
        svc.get_accuracy_by_difficulty(),
        svc.get_failure_count(),
    )

    test_run_data = None
    if test_run:
        run_timestamp = test_run.get("RUN_TIMESTAMP")
        test_run_data = {
            "runId": test_run.get("RUN_ID"),
            "timestamp": run_timestamp.isoformat() if run_timestamp else None,
            "totalTests": test_run.get("TOTAL_TESTS"),
            "methodsTested": test_run.get("METHODS_TESTED"),
        }

    test_stats_data = {
        "totalCases": int(test_stats.get("TOTAL_CASES", 0)),
        "easyCount": int(test_stats.get("EASY_COUNT", 0)),
        "mediumCount": int(test_stats.get("MEDIUM_COUNT", 0)),
        "hardCount": int(test_stats.get("HARD_COUNT", 0)),
        "easyPct": float(test_stats.get("EASY_PCT", 0)),
        "mediumPct": float(test_stats.get("MEDIUM_PCT", 0)),
        "hardPct": float(test_stats.get("HARD_PCT", 0)),
    }

    accuracy_summary_data = [
        {
            "method": row.get("METHOD"),
            "top1AccuracyPct": float(row.get("TOP1_ACCURACY_PCT", 0)),
            "top3AccuracyPct": float(row.get("TOP3_ACCURACY_PCT", 0)),
            "top5AccuracyPct": float(row.get("TOP5_ACCURACY_PCT", 0)),
        }
        for row in accuracy_summary
    ]

    accuracy_by_difficulty_data = [
        {
            "method": row.get("METHOD"),
            "difficulty": row.get("DIFFICULTY"),
            "tests": int(row.get("TESTS", 0)),
            "top1Pct": float(row.get("TOP1_PCT", 0)),
        }
        for row in accuracy_by_difficulty
    ]

    return {
        "testRun": test_run_data,
        "testStats": test_stats_data,
        "accuracySummary": accuracy_summary_data,
        "accuracyByDifficulty": accuracy_by_difficulty_data,
        "totalFailures": total_failures,
    }


@router.get("/failures")
async def get_testing_failures(
    svc: TestingServiceDep,
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_col: str = Query("METHOD"),
    sort_dir: str = Query("ASC"),
    method_filter: str = Query("All"),
    difficulty_filter: str = Query("All"),
):
    """Return paginated test failures as JSON."""
    result = await svc.get_failures(
        page=page,
        page_size=page_size,
        sort_col=sort_col,
        sort_dir=sort_dir,
        method_filter=method_filter,
        difficulty_filter=difficulty_filter,
    )

    filter_options = await svc.get_filter_options()

    failures_data = [
        {
            "method": row.get("METHOD"),
            "testInput": row.get("TEST_INPUT"),
            "expectedMatch": row.get("EXPECTED_MATCH"),
            "actualMatch": row.get("ACTUAL_MATCH"),
            "score": float(row.get("SCORE")) if row.get("SCORE") is not None else None,
            "difficulty": row.get("DIFFICULTY"),
        }
        for row in result["failures"]
    ]

    return {
        "failures": failures_data,
        "totalFailures": result["total_failures"],
        "totalPages": result["total_pages"],
        "currentPage": result["page"],
        "pageSize": page_size,
        "hasPrev": result["page"] > 1,
        "hasNext": result["page"] < result["total_pages"],
        "filterOptions": {
            "methods": filter_options["methods"],
            "difficulties": filter_options["difficulties"],
        },
    }


@router.post("/run")
async def run_accuracy_tests_json(
    request_body: RunTestsRequest,
    svc: TestingServiceDep,
):
    """Run accuracy tests for selected methods."""
    run_id = str(uuid.uuid4())

    valid_methods = {"cortex_search", "cosine", "edit_distance", "jaccard", "ensemble"}
    methods = [m for m in request_body.methods if m in valid_methods]

    if not methods:
        return JSONResponse(
            status_code=400,
            content={
                "error": "No valid test methods selected. Valid methods: cortex_search, cosine, edit_distance, jaccard, ensemble"
            },
        )

    try:
        await svc.create_test_run(run_id)

        task = asyncio.create_task(_run_tests_in_background(svc, run_id, methods))
        _active_runs[run_id] = task
        _background_tasks.add(task)
        task.add_done_callback(_background_tasks.discard)

        return RunTestsResponse(
            runId=run_id,
            status="started",
            methods=methods,
        )
    except Exception as exc:
        return JSONResponse(
            status_code=500,
            content={"error": f"Test execution failed: {exc}"},
        )


@router.get("/status/{run_id}")
async def check_test_status_json(
    run_id: str,
    svc: TestingServiceDep,
    expected_methods: int = 4,
):
    """Check if a test run has completed."""
    try:
        running_count = await svc.check_running_tests(run_id, expected_methods)

        if running_count > 0:
            return TestStatusResponse(status="running", runningCount=running_count)
        else:
            await svc.finalize_test_run(run_id)
            return TestStatusResponse(status="completed", runningCount=0)
    except Exception as exc:
        return JSONResponse(
            status_code=500,
            content={"error": f"Status check failed: {exc}"},
        )


@router.post("/cancel")
async def cancel_test_run(
    svc: TestingServiceDep,
    run_id: str | None = None,
):
    """Cancel an active test run."""
    if run_id is None:
        if not _active_runs:
            return CancelTestsResponse(
                runId="",
                status="no_active_run",
                message="No active test runs to cancel",
            )
        run_id = next(iter(_active_runs.keys()))

    task = _active_runs.get(run_id)
    task_cancelled = False
    if task and not task.done():
        task.cancel()
        task_cancelled = True
        logger.info(f"Cancelled asyncio task for test run {run_id[:8]}")

    try:
        await svc.mark_run_cancelled(run_id)
    except Exception as e:
        logger.warning(f"Could not mark run {run_id[:8]} as cancelled in Snowflake: {e}")

    _active_runs.pop(run_id, None)

    message = "Test run cancelled" if task_cancelled else "Test run marked as cancelled (task was not active)"
    return CancelTestsResponse(
        runId=run_id,
        status="cancelled",
        message=message,
    )
