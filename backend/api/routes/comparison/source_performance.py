"""Comparison source performance endpoint.

Returns algorithm performance metrics broken down by source system.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter

from backend.api.deps import CacheDep, ComparisonServiceDep
from backend.api.schemas.comparison import SourcePerformance, SourcePerformanceResponse

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 60.0


@router.get("/source-performance", response_model=SourcePerformanceResponse)
async def get_source_performance(
    svc: ComparisonServiceDep,
    cache: CacheDep,
) -> SourcePerformanceResponse:
    """Get algorithm performance metrics by source system.

    Returns average scores for each algorithm broken down by
    data source (POS, inventory, e-commerce, etc.).

    Cache TTL: 60 seconds
    """

    async def fetch_source_performance() -> SourcePerformanceResponse:
        try:
            source_result = await svc.get_source_performance()
            performance = [
                SourcePerformance(
                    source=row.get("SOURCE_SYSTEM", ""),
                    itemCount=int(row.get("ITEM_COUNT", 0) or 0),
                    avgSearch=float(row.get("AVG_SEARCH", 0) or 0),
                    avgCosine=float(row.get("AVG_COSINE", 0) or 0),
                    avgEdit=float(row.get("AVG_EDIT", 0) or 0),
                    avgJaccard=float(row.get("AVG_JACCARD", 0) or 0),
                    avgEnsemble=float(row.get("AVG_ENSEMBLE", 0) or 0),
                )
                for row in source_result
            ]
            return SourcePerformanceResponse(sourcePerformance=performance)
        except Exception as e:
            logger.warning(f"Failed to fetch source performance: {e}")
            return SourcePerformanceResponse(sourcePerformance=[])

    return await cache.get_or_fetch("comparison:source-performance", CACHE_TTL_SECONDS, fetch_source_performance)
