"""Comparison method accuracy endpoint.

Returns accuracy metrics for each matching method based on confirmed matches.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter

from backend.api.deps import CacheDep, ComparisonServiceDep
from backend.api.schemas.comparison import MethodAccuracy, MethodAccuracyResponse

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 60.0


@router.get("/method-accuracy", response_model=MethodAccuracyResponse)
async def get_method_accuracy(
    svc: ComparisonServiceDep,
    cache: CacheDep,
) -> MethodAccuracyResponse:
    """Get accuracy metrics for each matching method.

    Calculates accuracy based on confirmed matches - how often each
    algorithm's top pick matched the confirmed result.

    Cache TTL: 60 seconds
    """

    async def fetch_method_accuracy() -> MethodAccuracyResponse:
        try:
            accuracy_result = await svc.get_method_accuracy()
            accuracy_data = accuracy_result[0] if accuracy_result else {}

            accuracy = MethodAccuracy(
                totalConfirmed=int(accuracy_data.get("TOTAL_CONFIRMED", 0) or 0),
                searchCorrect=int(accuracy_data.get("SEARCH_CORRECT", 0) or 0),
                searchAccuracyPct=float(accuracy_data.get("SEARCH_ACCURACY_PCT", 0) or 0),
                cosineCorrect=int(accuracy_data.get("COSINE_CORRECT", 0) or 0),
                cosineAccuracyPct=float(accuracy_data.get("COSINE_ACCURACY_PCT", 0) or 0),
                editCorrect=int(accuracy_data.get("EDIT_CORRECT", 0) or 0),
                editAccuracyPct=float(accuracy_data.get("EDIT_ACCURACY_PCT", 0) or 0),
                jaccardCorrect=int(accuracy_data.get("JACCARD_CORRECT", 0) or 0),
                jaccardAccuracyPct=float(accuracy_data.get("JACCARD_ACCURACY_PCT", 0) or 0),
                ensembleCorrect=int(accuracy_data.get("ENSEMBLE_CORRECT", 0) or 0),
                ensembleAccuracyPct=float(accuracy_data.get("ENSEMBLE_ACCURACY_PCT", 0) or 0),
            )

            return MethodAccuracyResponse(methodAccuracy=accuracy)
        except Exception as e:
            logger.warning(f"Failed to fetch method accuracy: {e}")
            return MethodAccuracyResponse(
                methodAccuracy=MethodAccuracy(
                    totalConfirmed=0,
                    searchCorrect=0,
                    searchAccuracyPct=0.0,
                    cosineCorrect=0,
                    cosineAccuracyPct=0.0,
                    editCorrect=0,
                    editAccuracyPct=0.0,
                    jaccardCorrect=0,
                    jaccardAccuracyPct=0.0,
                    ensembleCorrect=0,
                    ensembleAccuracyPct=0.0,
                )
            )

    return await cache.get_or_fetch("comparison:method-accuracy", CACHE_TTL_SECONDS, fetch_method_accuracy)
