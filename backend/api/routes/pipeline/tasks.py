"""Pipeline tasks endpoint.

Returns the state of all Snowflake Tasks in the pipeline DAG.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter

from backend.api.deps import CacheDep, PipelineServiceDep
from backend.api.schemas.pipeline import TasksResponse, TaskState

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 15.0


@router.get("/tasks", response_model=TasksResponse)
async def get_pipeline_tasks(
    svc: PipelineServiceDep,
    cache: CacheDep,
) -> TasksResponse:
    """Get all pipeline DAG tasks and their states.

    Returns task names, states, schedules, and DAG hierarchy information.

    Cache TTL: 15 seconds
    """

    async def fetch_tasks() -> TasksResponse:
        try:
            ctx = await svc.get_pipeline_tab_data()

            tasks = ctx.get("tasks", [])
            tasks_list = [
                TaskState(
                    name=t.get("name", ""),
                    state=t.get("state", ""),
                    schedule=t.get("schedule", ""),
                    role=t.get("role", ""),
                    level=t.get("level", 0),
                    dag=t.get("dag", ""),
                )
                for t in tasks
            ]

            # Check if pipeline is running by looking for active job
            is_running = False
            try:
                # Check PIPELINE_RUNS for active job
                active_runs = await svc.sf.query(f"""
                    SELECT COUNT(*) AS CNT FROM {svc.db_name}.ANALYTICS.PIPELINE_RUNS
                    WHERE STATUS = 'RUNNING'
                """)
                if active_runs and active_runs[0].get("CNT", 0) > 0:
                    is_running = True
            except Exception:
                pass

            return TasksResponse(
                tasks=tasks_list,
                all_tasks_suspended=ctx.get("all_tasks_suspended", False),
                pending_count=ctx.get("pending_count", 0),
                is_running=is_running,
            )
        except Exception as e:
            logger.warning(f"Failed to fetch tasks data: {e}")

        return TasksResponse(tasks=[], all_tasks_suspended=False, pending_count=0, is_running=False)

    return await cache.get_or_fetch("pipeline:tasks", CACHE_TTL_SECONDS, fetch_tasks)
