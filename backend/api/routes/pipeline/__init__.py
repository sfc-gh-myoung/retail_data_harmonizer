"""Pipeline v2 API routes for React frontend.

Modular endpoints replacing the monolithic /api/v2/pipeline/status endpoint.
Each sub-module handles a specific data domain with independent caching.
"""

from fastapi import APIRouter

from backend.api.routes.pipeline import (
    actions,
    funnel,
    phases,
    tasks,
)

router = APIRouter(prefix="/api/v2/pipeline", tags=["pipeline"])

# Include all sub-routers
router.include_router(funnel.router)
router.include_router(phases.router)
router.include_router(tasks.router)
router.include_router(actions.router)
