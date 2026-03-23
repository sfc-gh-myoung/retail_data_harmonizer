"""Dashboard sources endpoint.

Returns source system breakdown with status distribution and match rates.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter

from backend.api.deps import CacheDep, DashboardServiceDep
from backend.api.schemas.dashboard import SourceRate, SourcesResponse

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 10.0


@router.get("/sources", response_model=SourcesResponse)
async def get_dashboard_sources(
    svc: DashboardServiceDep,
    cache: CacheDep,
) -> SourcesResponse:
    """Get source system breakdown with status distribution.

    Returns status counts per source and match rate rankings.

    Cache TTL: 10 seconds
    """

    async def fetch_sources() -> SourcesResponse:
        try:
            combined = await svc.get_combined_data()
            source_status_rows = combined["source_status_rows"]

            # Build source systems map
            source_systems: dict[str, dict[str, int]] = {}
            for row in source_status_rows:
                src = row.get("SOURCE_SYSTEM", "")
                status_val = row.get("MATCH_STATUS", "")
                cnt = int(row.get("CNT", 0) or 0)
                if src and src.upper() != "UNKNOWN":
                    if src not in source_systems:
                        source_systems[src] = {}
                    source_systems[src][status_val] = cnt

            # Calculate source rates
            source_rates = []
            for src, statuses_map in source_systems.items():
                src_total = sum(statuses_map.values())
                src_matched = statuses_map.get("AUTO_ACCEPTED", 0) + statuses_map.get("CONFIRMED", 0)
                src_rate = round(src_matched / src_total * 100, 1) if src_total > 0 else 0.0
                source_rates.append(
                    SourceRate(
                        source=src,
                        total=src_total,
                        matched=src_matched,
                        rate=src_rate,
                    )
                )
            source_rates.sort(key=lambda x: x.rate, reverse=True)

            # Calculate max for normalization
            source_max = max(sum(s.values()) for s in source_systems.values()) if source_systems else 1

            return SourcesResponse(
                source_systems=source_systems,
                source_rates=source_rates,
                source_max=source_max,
            )
        except Exception as e:
            logger.warning(f"Failed to fetch sources: {e}")
            return SourcesResponse(
                source_systems={},
                source_rates=[],
                source_max=1,
            )

    return await cache.get_or_fetch("dashboard:sources", CACHE_TTL_SECONDS, fetch_sources)
