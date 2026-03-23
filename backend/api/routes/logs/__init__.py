"""Logs API routes for React frontend.

Modular endpoints for the logs page, each handling a specific data domain
with independent caching for fast, progressive loading.

Endpoints:
- GET /task-history - Snowflake task execution history (15s cache)
- GET /errors - Recent pipeline errors (15s cache)
- GET /audit - Audit trail entries (30s cache)
"""

from __future__ import annotations

from fastapi import APIRouter

from backend.api.routes.logs import audit, errors, task_history

router = APIRouter(prefix="/api/v2/logs", tags=["logs"])

# Include all sub-routers for modular endpoints
router.include_router(task_history.router)
router.include_router(errors.router)
router.include_router(audit.router)
