"""Logs recent errors endpoint.

Returns recent pipeline execution errors with pagination.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Query

from backend.api.deps import CacheDep, LogsServiceDep
from backend.api.schemas.logs import ErrorsResponse, PaginatedErrors, RecentError

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 15.0


@router.get("/errors", response_model=ErrorsResponse)
async def get_errors(
    svc: LogsServiceDep,
    cache: CacheDep,
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(25, ge=1, le=100, description="Items per page"),
) -> ErrorsResponse:
    """Get recent pipeline execution errors with pagination.

    Returns failed pipeline steps from the last 7 days.

    Cache TTL: 15 seconds
    """
    cache_key = f"logs:errors:{page}:{page_size}"

    async def fetch_errors() -> ErrorsResponse:
        try:
            errors_data, errors_count = await _fetch_data(svc, page, page_size)
            total_pages = max(1, (errors_count + page_size - 1) // page_size)

            entries = [
                RecentError(
                    logId=str(e.get("LOG_ID", "")),
                    runId=str(e.get("RUN_ID", "")),
                    stepName=e.get("STEP_NAME", ""),
                    category=e.get("CATEGORY", ""),
                    errorMessage=e.get("ERROR_MESSAGE", ""),
                    itemsFailed=int(e.get("ITEMS_FAILED", 0) or 0),
                    queryId=e.get("QUERY_ID"),
                    createdAt=str(e.get("CREATED_AT", "")),
                )
                for e in errors_data
            ]

            return ErrorsResponse(
                recentErrors=PaginatedErrors(
                    entries=entries,
                    total=errors_count,
                    page=page,
                    pageSize=page_size,
                    totalPages=total_pages,
                )
            )
        except Exception as e:
            logger.warning(f"Failed to fetch errors: {e}")
            return ErrorsResponse(
                recentErrors=PaginatedErrors(
                    entries=[],
                    total=0,
                    page=page,
                    pageSize=page_size,
                    totalPages=1,
                )
            )

    return await cache.get_or_fetch(cache_key, CACHE_TTL_SECONDS, fetch_errors)


async def _fetch_data(svc: LogsServiceDep, page: int, page_size: int):
    """Fetch errors data and count concurrently."""
    import asyncio

    return await asyncio.gather(
        svc.get_recent_errors(page, page_size),
        svc.get_recent_errors_count(),
    )
