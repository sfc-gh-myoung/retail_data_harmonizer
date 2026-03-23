"""Dashboard cost and scale endpoint.

Returns cost/ROI metrics and scale projection data.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter

from backend.api.deps import CacheDep, DashboardServiceDep
from backend.api.schemas.dashboard import CostMetrics, CostResponse, ScaleMetrics

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 900.0  # 15 min - ACCOUNT_USAGE data has ~45-min latency anyway


@router.get("/cost", response_model=CostResponse)
async def get_dashboard_cost(
    svc: DashboardServiceDep,
    cache: CacheDep,
) -> CostResponse:
    """Get cost/ROI metrics and scale projection data.

    Returns cost analysis and scale extrapolation metrics.

    Cache TTL: 60 seconds
    """

    async def fetch_cost() -> CostResponse:
        try:
            cost_data = await svc.get_cost_data()
            scale_data = await svc.get_scale_data()

            cost_metrics = None
            if cost_data:
                cost_metrics = CostMetrics(
                    totalRuns=int(cost_data.get("TOTAL_RUNS", 0) or 0),
                    totalUsd=float(cost_data.get("TOTAL_ESTIMATED_USD", 0) or 0),
                    totalCredits=float(cost_data.get("TOTAL_CREDITS_USED", 0) or 0),
                    totalItems=int(cost_data.get("TOTAL_ITEMS", 0) or 0),
                    costPerItem=float(cost_data.get("COST_PER_ITEM", 0) or 0),
                    baselineWeeklyCost=float(cost_data.get("BASELINE_WEEKLY_COST", 0) or 0),
                    hoursSaved=float(cost_data.get("HOURS_SAVED", 0) or 0),
                    roiPercentage=float(cost_data.get("ROI_PERCENTAGE", 0) or 0),
                    creditRateUsd=float(cost_data.get("CREDIT_RATE_USD", 3.00) or 3.00),
                    manualHourlyRate=float(cost_data.get("MANUAL_HOURLY_RATE", 50.00) or 50.00),
                    manualMinutesPerItem=float(cost_data.get("MANUAL_MINUTES_PER_ITEM", 3.0) or 3.0),
                )

            scale_metrics = ScaleMetrics(
                total=scale_data.get("total", 0),
                uniqueCount=scale_data.get("unique_count", 0),
                dedupRatio=scale_data.get("dedup_ratio", 1.0),
                fastPathCount=scale_data.get("fast_path_count", 0),
                fastPathRate=scale_data.get("fast_path_rate", 0.0),
            )

            return CostResponse(
                cost_data=cost_metrics,
                scale_data=scale_metrics,
            )
        except Exception as e:
            logger.warning(f"Failed to fetch cost data: {e}")
            return CostResponse(
                cost_data=None,
                scale_data=ScaleMetrics(
                    total=0,
                    uniqueCount=0,
                    dedupRatio=1.0,
                    fastPathCount=0,
                    fastPathRate=0.0,
                ),
            )

    return await cache.get_or_fetch("dashboard:cost", CACHE_TTL_SECONDS, fetch_cost)
