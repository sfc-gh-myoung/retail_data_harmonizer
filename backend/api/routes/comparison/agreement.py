"""Comparison agreement analysis endpoint.

Returns algorithm agreement distribution analysis.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter

from backend.api.deps import CacheDep, ComparisonServiceDep
from backend.api.schemas.comparison import AgreementData, AgreementResponse

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 60.0


@router.get("/agreement", response_model=AgreementResponse)
async def get_agreement(
    svc: ComparisonServiceDep,
    cache: CacheDep,
) -> AgreementResponse:
    """Get algorithm agreement distribution analysis.

    Returns counts of how many algorithms agree on matches
    (4 of 4, 3 of 4, 2 of 4, 0 of 4).

    Cache TTL: 60 seconds
    """

    async def fetch_agreement() -> AgreementResponse:
        try:
            agreement_result = await svc.get_agreement_analysis()
            agreement = [
                AgreementData(
                    level=row.get("AGREEMENT_LEVEL", ""),
                    count=int(row.get("MATCH_COUNT", 0) or 0),
                    avgConfidence=float(row.get("AVG_CONFIDENCE", 0) or 0),
                )
                for row in agreement_result
            ]
            return AgreementResponse(agreement=agreement)
        except Exception as e:
            logger.warning(f"Failed to fetch agreement analysis: {e}")
            return AgreementResponse(agreement=[])

    return await cache.get_or_fetch("comparison:agreement", CACHE_TTL_SECONDS, fetch_agreement)
