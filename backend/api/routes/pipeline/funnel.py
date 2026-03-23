"""Pipeline funnel metrics endpoint.

Returns item counts at each stage of the pipeline funnel.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter

from backend.api.deps import CacheDep, DashboardServiceDep
from backend.api.schemas.pipeline import FunnelResponse

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 5.0


@router.get("/funnel", response_model=FunnelResponse)
async def get_pipeline_funnel(
    svc: DashboardServiceDep,
    cache: CacheDep,
) -> FunnelResponse:
    """Get pipeline funnel metrics showing item flow through processing stages.

    Returns counts of items at each stage: raw, categorized, blocked,
    unique descriptions, and items in the active pipeline.

    Cache TTL: 5 seconds
    """

    async def fetch_funnel() -> FunnelResponse:
        try:
            p = await svc.get_progress_data()
            if p:
                return FunnelResponse(
                    raw_items=int(p.get("RAW_ITEMS", 0) or 0),
                    categorized_items=int(p.get("CATEGORIZED_ITEMS", 0) or 0),
                    blocked_items=int(p.get("BLOCKED_ITEMS", 0) or 0),
                    unique_descriptions=int(p.get("UNIQUE_DESCRIPTIONS", 0) or 0),
                    pipeline_items=int(p.get("PIPELINE_ITEMS", 0) or 0),
                    ensemble_done=int(p.get("ENSEMBLE_DONE", 0) or 0),
                )
        except Exception as e:
            logger.warning(f"Failed to fetch funnel data: {e}")

        # Return empty response on error
        return FunnelResponse(
            raw_items=0,
            categorized_items=0,
            blocked_items=0,
            unique_descriptions=0,
            pipeline_items=0,
        )

    return await cache.get_or_fetch("pipeline:funnel", CACHE_TTL_SECONDS, fetch_funnel)
