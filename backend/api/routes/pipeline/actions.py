"""Pipeline action endpoints.

Handles pipeline control operations: run, stop, toggle tasks.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from backend.api.deps import (
    CacheInvalidateDep,
    DatabaseDep,
    PipelineServiceDep,
    SfClientDep,
)
from backend.api.schemas.pipeline import ActionResponse

logger = logging.getLogger(__name__)

router = APIRouter()


class StopRequest(BaseModel):
    """Request body for stopping a pipeline job."""

    job_id: str = Field(..., description="ID of the job to stop")


class ToggleTaskRequest(BaseModel):
    """Request body for toggling a task."""

    task_name: str = Field(..., description="Name of task to toggle")
    action: str = Field(..., description="Action: resume or suspend")


@router.post("/run", response_model=ActionResponse)
async def run_pipeline(
    db_name: DatabaseDep,
    sf: SfClientDep,
    invalidate_cache: CacheInvalidateDep,
) -> ActionResponse:
    """Manually trigger the pipeline by executing DEDUP_FASTPATH_TASK.

    This runs the full pipeline: dedup -> classify -> match -> ensemble.

    Args:
        db_name: Injected database name for fully qualified object references.
        sf: Snowflake client for query execution.
        invalidate_cache: Cache invalidation callback.

    Returns:
        ActionResponse with success=True and confirmation message.

    Side Effects:
        - Executes DEDUP_FASTPATH_TASK via EXECUTE TASK statement
        - Invalidates cached pipeline status data

    Raises:
        HTTPException(500): If task execution fails.
    """
    try:
        await sf.execute(f"EXECUTE TASK {db_name}.HARMONIZED.DEDUP_FASTPATH_TASK")
        invalidate_cache()
        return ActionResponse(
            success=True,
            message="Pipeline triggered successfully",
        )
    except Exception as e:
        logger.error(f"Failed to trigger pipeline: {e}")
        raise HTTPException(status_code=500, detail=str(e)) from None


@router.post("/stop", response_model=ActionResponse)
async def stop_pipeline(
    request: StopRequest,
    db_name: DatabaseDep,
    sf: SfClientDep,
    invalidate_cache: CacheInvalidateDep,
) -> ActionResponse:
    """Stop an active pipeline job by setting STOP_REQUESTED flag.

    Args:
        request: StopRequest containing the job_id to stop.
        db_name: Injected database name for fully qualified object references.
        sf: Snowflake client for query execution.
        invalidate_cache: Cache invalidation callback.

    Returns:
        ActionResponse with success=True, confirmation message, and job_id.

    Side Effects:
        - Updates STOP_REQUESTED flag in ANALYTICS.PIPELINE_RUNS table
        - Invalidates cached pipeline status data

    Raises:
        HTTPException(500): If the UPDATE statement fails.
    """
    try:
        await sf.execute(f"""
            UPDATE {db_name}.ANALYTICS.PIPELINE_RUNS
            SET STOP_REQUESTED = TRUE
            WHERE JOB_ID = '{request.job_id}'
        """)
        invalidate_cache()
        return ActionResponse(
            success=True,
            message="Stop requested",
            job_id=request.job_id,
        )
    except Exception as e:
        logger.error(f"Failed to stop pipeline: {e}")
        raise HTTPException(status_code=500, detail=str(e)) from None


@router.post("/toggle", response_model=ActionResponse)
async def toggle_task(
    request: ToggleTaskRequest,
    svc: PipelineServiceDep,
    invalidate_cache: CacheInvalidateDep,
) -> ActionResponse:
    """Toggle a Snowflake Task on or off.

    Snowflake Task DAGs have specific constraints:
    - Child tasks can only be modified when the root task is suspended
    - Suspending the root task suspends the entire DAG

    Args:
        request: ToggleTaskRequest containing task_name and action (resume/suspend).
        svc: PipelineService for task management operations.
        invalidate_cache: Cache invalidation callback.

    Returns:
        ActionResponse with success=True and confirmation message.

    Side Effects:
        - Executes ALTER TASK statements to resume or suspend tasks
        - For child tasks, temporarily suspends root task during modification
        - Invalidates cached task status data

    Raises:
        HTTPException(400): If task_name is not a valid pipeline task.
        HTTPException(500): If ALTER TASK execution fails.
    """
    try:
        await svc.toggle_task(request.task_name, request.action)
        invalidate_cache()
        return ActionResponse(
            success=True,
            message=f"Task {request.task_name} {request.action}d successfully",
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from None
    except Exception as e:
        logger.error(f"Failed to toggle task {request.task_name}: {e}")
        raise HTTPException(status_code=500, detail=str(e)) from None


@router.post("/tasks/enable-all", response_model=ActionResponse)
async def enable_all_tasks(
    db_name: DatabaseDep,
    sf: SfClientDep,
    invalidate_cache: CacheInvalidateDep,
) -> ActionResponse:
    """Enable all pipeline-related Snowflake Tasks.

    Calls ENABLE_PARALLEL_PIPELINE_TASKS stored procedure which resumes
    all tasks in the pipeline DAG.

    Args:
        db_name: Injected database name for fully qualified object references.
        sf: Snowflake client for query execution.
        invalidate_cache: Cache invalidation callback.

    Returns:
        ActionResponse with success=True and confirmation message.

    Side Effects:
        - Calls ENABLE_PARALLEL_PIPELINE_TASKS stored procedure
        - Resumes all pipeline tasks (ALTER TASK RESUME)
        - Invalidates cached task status data

    Raises:
        HTTPException(500): If procedure call fails.
    """
    try:
        await sf.execute(f"CALL {db_name}.HARMONIZED.ENABLE_PARALLEL_PIPELINE_TASKS()")
        # Refresh task state cache so UI reflects updated state immediately
        await sf.execute(f"CALL {db_name}.ANALYTICS.REFRESH_TASK_STATE_CACHE_PROC()")
        invalidate_cache()
        return ActionResponse(
            success=True,
            message="All tasks enabled",
        )
    except Exception as e:
        logger.error(f"Failed to enable all tasks: {e}")
        raise HTTPException(status_code=500, detail=str(e)) from None


@router.post("/tasks/disable-all", response_model=ActionResponse)
async def disable_all_tasks(
    db_name: DatabaseDep,
    sf: SfClientDep,
    invalidate_cache: CacheInvalidateDep,
) -> ActionResponse:
    """Disable all pipeline-related Snowflake Tasks.

    Calls DISABLE_PARALLEL_PIPELINE_TASKS stored procedure which suspends
    all tasks in the pipeline DAG.

    Side Effects:
        - Calls DISABLE_PARALLEL_PIPELINE_TASKS stored procedure
        - Suspends all pipeline tasks (ALTER TASK SUSPEND)
        - Invalidates cached task status data

    Raises:
        HTTPException(500): If procedure call fails.
    """
    try:
        await sf.execute(f"CALL {db_name}.HARMONIZED.DISABLE_PARALLEL_PIPELINE_TASKS()")
        # Refresh task state cache so UI reflects updated state immediately
        await sf.execute(f"CALL {db_name}.ANALYTICS.REFRESH_TASK_STATE_CACHE_PROC()")
        invalidate_cache()
        return ActionResponse(
            success=True,
            message="All tasks disabled",
        )
    except Exception as e:
        logger.error(f"Failed to disable all tasks: {e}")
        raise HTTPException(status_code=500, detail=str(e)) from None


@router.post("/reset", response_model=ActionResponse)
async def reset_pipeline(
    svc: PipelineServiceDep,
    invalidate_cache: CacheInvalidateDep,
) -> ActionResponse:
    """Reset the matching pipeline, clearing all matches.

    This is a destructive operation that removes all existing match data
    and resets items to PENDING status for re-processing.

    Args:
        svc: PipelineService for pipeline management operations.
        invalidate_cache: Cache invalidation callback.

    Returns:
        ActionResponse with success=True and confirmation message.

    Side Effects:
        - Calls RESET_PIPELINE stored procedure
        - Clears all records from HARMONIZED.ITEM_MATCHES
        - Resets MATCH_STATUS to PENDING in RAW.RAW_RETAIL_ITEMS
        - Invalidates all cached pipeline and match data

    Raises:
        HTTPException(500): If reset procedure fails.
    """
    try:
        await svc.reset_pipeline()
        invalidate_cache()
        return ActionResponse(
            success=True,
            message="Pipeline has been reset. All matches cleared.",
        )
    except Exception as e:
        logger.error(f"Failed to reset pipeline: {e}")
        raise HTTPException(status_code=500, detail=str(e)) from None


@router.get("/status")
async def pipeline_status(svc: PipelineServiceDep):
    """Return pipeline Task DAG status and item counts.

    Fetches current pipeline state including task enablement, pending items,
    and match statistics for the dashboard status display.

    Args:
        svc: PipelineService for pipeline status queries.

    Returns:
        Dict with tasksEnabled, rootTaskState, pendingItems, pendingReview,
        autoAccepted, matchedItems, and fastPathItems counts. Returns error
        dict on failure.

    Side Effects:
        - Calls GET_PIPELINE_STATUS stored procedure
        - Queries RAW.RAW_RETAIL_ITEMS for pending count
    """
    db = svc.db_name

    try:
        status_result = await svc.sf.query(f"CALL {db}.HARMONIZED.GET_PIPELINE_STATUS()")

        pending = await svc.sf.query(f"""
            SELECT COUNT(*) AS CNT FROM {db}.RAW.RAW_RETAIL_ITEMS
            WHERE MATCH_STATUS = 'PENDING'
        """)
        pending_count = int(pending[0].get("CNT", 0)) if pending else 0

        if status_result:
            status = status_result[0] if status_result else {}
            return {
                "tasksEnabled": status.get("tasks_enabled", False),
                "rootTaskState": status.get("root_task_state", "unknown"),
                "pendingItems": status.get("pending_items", pending_count),
                "pendingReview": status.get("pending_review", 0),
                "autoAccepted": status.get("auto_accepted", 0),
                "matchedItems": status.get("matched_items", 0),
                "fastPathItems": status.get("fast_path_items", 0),
            }
        else:
            return {
                "tasksEnabled": False,
                "pendingCount": pending_count,
            }

    except Exception as exc:
        return {"error": str(exc)}
