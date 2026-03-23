"""Logs API response schemas for modular endpoints."""

from __future__ import annotations

from pydantic import BaseModel, Field

# ============================================================================
# Individual data models
# ============================================================================


class TaskHistoryEntry(BaseModel):
    """Task execution history entry."""

    taskName: str
    state: str
    scheduledTime: str | None = None
    queryStartTime: str | None = None
    durationSeconds: float | None = None
    errorMessage: str | None = None


class RecentError(BaseModel):
    """Recent error log entry."""

    logId: str
    runId: str
    stepName: str
    category: str | None = None
    errorMessage: str
    itemsFailed: int
    queryId: str | None = None
    createdAt: str


class AuditLogEntry(BaseModel):
    """Audit log entry."""

    auditId: str
    actionType: str
    tableName: str
    recordId: str | None = None
    oldValue: str | None = None
    newValue: str | None = None
    changedBy: str
    changedAt: str
    changeReason: str | None = None


class MethodPerformance(BaseModel):
    """Method performance metrics entry."""

    logId: str
    runId: str
    methodName: str
    category: str | None = None
    itemsProcessed: int
    avgScore: float | None = None
    minScore: float | None = None
    maxScore: float | None = None
    cacheHits: int
    earlyExits: int
    durationMs: float | None = None
    createdAt: str


# ============================================================================
# Pagination wrapper
# ============================================================================


class PaginatedResponse(BaseModel):
    """Generic paginated response wrapper."""

    total: int
    page: int
    pageSize: int
    totalPages: int


class PaginatedTaskHistory(PaginatedResponse):
    """Paginated task history response."""

    entries: list[TaskHistoryEntry]


class PaginatedErrors(PaginatedResponse):
    """Paginated errors response."""

    entries: list[RecentError]


class PaginatedAuditLogs(PaginatedResponse):
    """Paginated audit logs response."""

    entries: list[AuditLogEntry]


# ============================================================================
# Endpoint response schemas
# ============================================================================


class TaskHistoryResponse(BaseModel):
    """Response for GET /api/v2/logs/task-history endpoint."""

    taskHistory: PaginatedTaskHistory


class ErrorsResponse(BaseModel):
    """Response for GET /api/v2/logs/errors endpoint."""

    recentErrors: PaginatedErrors


class MethodPerformanceResponse(BaseModel):
    """Response for GET /api/v2/logs/method-performance endpoint."""

    methodPerformance: list[MethodPerformance]


class AuditResponse(BaseModel):
    """Response for GET /api/v2/logs/audit endpoint."""

    auditLogs: PaginatedAuditLogs


class FilterOptions(BaseModel):
    """Filter options for logs pages."""

    steps: list[str] = Field(default_factory=list)
    categories: list[str] = Field(default_factory=list)
    statuses: list[str] = Field(default_factory=list)


class TaskFilterOptions(BaseModel):
    """Filter options for task history."""

    taskNames: list[str] = Field(default_factory=list)
    states: list[str] = Field(default_factory=list)
