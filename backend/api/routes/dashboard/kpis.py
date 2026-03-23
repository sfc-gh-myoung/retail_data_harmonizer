"""Dashboard KPIs endpoint.

Returns core KPIs and status distribution for the dashboard header.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter

from backend.api.deps import CacheDep, DashboardServiceDep
from backend.api.schemas.dashboard import KPIData, KpisResponse, SourceStatus

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 5.0

STATUS_COLORS_MAP = {
    "AUTO_ACCEPTED": "#00C853",
    "CONFIRMED": "#2196F3",
    "PENDING_REVIEW": "#FFD600",
    "PENDING": "#9E9E9E",
    "REJECTED": "#FF1744",
}


@router.get("/kpis", response_model=KpisResponse)
async def get_dashboard_kpis(
    svc: DashboardServiceDep,
    cache: CacheDep,
) -> KpisResponse:
    """Get core KPIs and status distribution.

    Returns total counts, match rates, and status breakdown for
    the dashboard header cards.

    Cache TTL: 5 seconds
    """

    async def fetch_kpis() -> KpisResponse:
        try:
            combined = await svc.get_combined_data()
            scale_data = await svc.get_scale_data()

            kpi = combined["kpi"]
            total_raw = int(kpi.get("TOTAL_ITEMS", 0) or 0)
            auto = int(kpi.get("AUTO_ACCEPTED", 0) or 0)
            confirmed = int(kpi.get("CONFIRMED", 0) or 0)
            pending_review = int(kpi.get("PENDING_REVIEW", 0) or 0)
            pending = int(kpi.get("PENDING", 0) or 0)
            rejected = int(kpi.get("REJECTED", 0) or 0)
            needs_categorized = int(kpi.get("NEEDS_CATEGORIZED", 0) or 0)
            match_rate = round(auto / total_raw * 100, 1) if total_raw > 0 else 0.0
            total_processed = auto + confirmed + pending_review + rejected
            total_unique = int(scale_data.get("unique_count", 0) or 0)

            stats = KPIData(
                totalRaw=total_raw,
                totalUnique=total_unique,
                totalProcessed=total_processed,
                autoAccepted=auto,
                confirmed=confirmed,
                pendingReview=pending_review,
                rejected=rejected,
                needsCategorized=needs_categorized,
                matchRate=match_rate,
                total=total_raw,
            )

            statuses = [
                SourceStatus(label="Auto-Accepted", count=auto, color="#00C853"),
                SourceStatus(label="Confirmed", count=confirmed, color="#2196F3"),
                SourceStatus(label="Pending Review", count=pending_review, color="#FFD600"),
                SourceStatus(label="Pending", count=pending, color="#9E9E9E"),
                SourceStatus(label="Rejected", count=rejected, color="#FF1744"),
            ]

            return KpisResponse(
                stats=stats,
                statuses=statuses,
                status_colors_map=STATUS_COLORS_MAP,
            )
        except Exception as e:
            logger.warning(f"Failed to fetch KPIs: {e}")
            # Return empty response on error
            return KpisResponse(
                stats=KPIData(
                    totalRaw=0,
                    totalUnique=0,
                    totalProcessed=0,
                    autoAccepted=0,
                    confirmed=0,
                    pendingReview=0,
                    rejected=0,
                    needsCategorized=0,
                    matchRate=0.0,
                    total=0,
                ),
                statuses=[],
                status_colors_map=STATUS_COLORS_MAP,
            )

    return await cache.get_or_fetch("dashboard:kpis", CACHE_TTL_SECONDS, fetch_kpis)
