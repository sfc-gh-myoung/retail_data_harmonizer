"""Dashboard API routes for React frontend.

Modular endpoints for the dashboard, each handling a specific data domain
with independent caching for fast, progressive loading.
"""

from __future__ import annotations

from fastapi import APIRouter

from backend.api.routes.dashboard import categories, cost, kpis, signals, sources

router = APIRouter(prefix="/api/v2/dashboard", tags=["dashboard"])

# Include all sub-routers
router.include_router(kpis.router)
router.include_router(sources.router)
router.include_router(categories.router)
router.include_router(signals.router)
router.include_router(cost.router)
