"""Logs task history endpoint.

Returns Snowflake task execution history with pagination.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Query

from backend.api.deps import CacheDep, LogsServiceDep
from backend.api.schemas.logs import (
    PaginatedTaskHistory,
    TaskFilterOptions,
    TaskHistoryEntry,
    TaskHistoryResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 15.0


@router.get("/task-history", response_model=TaskHistoryResponse)
async def get_task_history(
    svc: LogsServiceDep,
    cache: CacheDep,
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(10, ge=1, le=100, description="Items per page"),
    task_name: str = Query("", description="Filter by task name (partial match)"),
    state: str = Query("", description="Filter by task state"),
) -> TaskHistoryResponse:
    """Get Snowflake task execution history with pagination and filtering.

    Returns task execution history ordered by scheduled time (most recent first).

    Cache TTL: 15 seconds
    """
    cache_key = f"logs:task-history:{page}:{page_size}:{task_name}:{state}"

    async def fetch_task_history() -> TaskHistoryResponse:
        try:
            task_history, task_count = await _fetch_data(svc, page, page_size, task_name, state)
            total_pages = max(1, (task_count + page_size - 1) // page_size)

            entries = [
                TaskHistoryEntry(
                    taskName=t.get("TASK_NAME", ""),
                    state=t.get("STATE", ""),
                    scheduledTime=str(t.get("SCHEDULED_TIME", "")) if t.get("SCHEDULED_TIME") else None,
                    queryStartTime=str(t.get("QUERY_START_TIME", "")) if t.get("QUERY_START_TIME") else None,
                    durationSeconds=float(t.get("DURATION_SECONDS", 0) or 0)
                    if t.get("DURATION_SECONDS") is not None
                    else None,
                    errorMessage=t.get("ERROR_MESSAGE"),
                )
                for t in task_history
            ]

            return TaskHistoryResponse(
                taskHistory=PaginatedTaskHistory(
                    entries=entries,
                    total=task_count,
                    page=page,
                    pageSize=page_size,
                    totalPages=total_pages,
                )
            )
        except Exception as e:
            logger.warning(f"Failed to fetch task history: {e}")
            return TaskHistoryResponse(
                taskHistory=PaginatedTaskHistory(
                    entries=[],
                    total=0,
                    page=page,
                    pageSize=page_size,
                    totalPages=1,
                )
            )

    return await cache.get_or_fetch(cache_key, CACHE_TTL_SECONDS, fetch_task_history)


async def _fetch_data(svc: LogsServiceDep, page: int, page_size: int, task_name: str, state: str):
    """Fetch task history data and count concurrently."""
    import asyncio

    return await asyncio.gather(
        svc.get_task_history(page, page_size, task_name, state),
        svc.get_task_history_count(task_name, state),
    )


@router.get("/task-history/filter-options", response_model=TaskFilterOptions)
async def get_task_filter_options(
    svc: LogsServiceDep,
    cache: CacheDep,
) -> TaskFilterOptions:
    """Get filter options for task history dropdown menus.

    Returns distinct task names and states from task execution history.

    Cache TTL: 15 seconds
    """
    cache_key = "logs:task-history:filter-options"

    async def fetch_options() -> TaskFilterOptions:
        try:
            options = await svc.get_task_filter_options()
            return TaskFilterOptions(
                taskNames=options.get("taskNames", []),
                states=options.get("states", []),
            )
        except Exception as e:
            logger.warning(f"Failed to fetch task filter options: {e}")
            return TaskFilterOptions()

    return await cache.get_or_fetch(cache_key, CACHE_TTL_SECONDS, fetch_options)
