"""Logs audit trail endpoint.

Returns audit log entries with pagination.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Query

from backend.api.deps import CacheDep, LogsServiceDep
from backend.api.schemas.logs import AuditLogEntry, AuditResponse, PaginatedAuditLogs

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 30.0


@router.get("/audit", response_model=AuditResponse)
async def get_audit(
    svc: LogsServiceDep,
    cache: CacheDep,
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(25, ge=1, le=100, description="Items per page"),
) -> AuditResponse:
    """Get audit log entries with pagination.

    Returns match review audit trail from the last 7 days.

    Cache TTL: 30 seconds
    """
    cache_key = f"logs:audit:{page}:{page_size}"

    async def fetch_audit() -> AuditResponse:
        try:
            audit_data, audit_count = await _fetch_data(svc, page, page_size)
            total_pages = max(1, (audit_count + page_size - 1) // page_size)

            entries = [
                AuditLogEntry(
                    auditId=str(al.get("AUDIT_ID", "")),
                    actionType=al.get("ACTION", ""),
                    tableName="MATCH_AUDIT_LOG",
                    recordId=str(al.get("MATCH_ID", "")) if al.get("MATCH_ID") else None,
                    oldValue=al.get("OLD_STATUS"),
                    newValue=al.get("NEW_STATUS"),
                    changedBy=al.get("REVIEWED_BY", ""),
                    changedAt=str(al.get("CREATED_AT", "")),
                    changeReason=al.get("NOTES"),
                )
                for al in audit_data
            ]

            return AuditResponse(
                auditLogs=PaginatedAuditLogs(
                    entries=entries,
                    total=audit_count,
                    page=page,
                    pageSize=page_size,
                    totalPages=total_pages,
                )
            )
        except Exception as e:
            logger.warning(f"Failed to fetch audit logs: {e}")
            return AuditResponse(
                auditLogs=PaginatedAuditLogs(
                    entries=[],
                    total=0,
                    page=page,
                    pageSize=page_size,
                    totalPages=1,
                )
            )

    return await cache.get_or_fetch(cache_key, CACHE_TTL_SECONDS, fetch_audit)


async def _fetch_data(svc: LogsServiceDep, page: int, page_size: int):
    """Fetch audit data and count concurrently."""
    import asyncio

    return await asyncio.gather(
        svc.get_audit_logs(page, page_size),
        svc.get_audit_logs_count(),
    )
