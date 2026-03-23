"""Comparison API routes for algorithm analysis.

Modular endpoints for the comparison page, each handling a specific data domain
with independent caching for fast, progressive loading.

Endpoints:
- GET /algorithms - Static algorithm descriptions
- GET /agreement - Algorithm agreement analysis (60s cache)
- GET /source-performance - Performance by source system (60s cache)
- GET /method-accuracy - Accuracy metrics per method (60s cache)
- GET / - Legacy aggregated endpoint (for backward compatibility)
"""

from __future__ import annotations

from fastapi import APIRouter

from backend.api import snowflake_client as sf
from backend.api.routes.comparison import agreement, method_accuracy, source_performance
from backend.api.schemas.comparison import Algorithm, AlgorithmsResponse

router = APIRouter(prefix="/api/v2/comparison", tags=["comparison"])

# Include all sub-routers for modular endpoints
router.include_router(agreement.router)
router.include_router(source_performance.router)
router.include_router(method_accuracy.router)

# Static algorithm descriptions
ALGORITHMS = [
    Algorithm(
        name="Search",
        description="Text-based retrieval using Cortex Search",
        features=["Handles abbreviations", "Fast lookup"],
    ),
    Algorithm(
        name="Cosine",
        description="Semantic similarity via vector embeddings",
        features=["snowflake-arctic-embed-l-v2.0", "Handles variations"],
    ),
    Algorithm(
        name="Edit Distance",
        description="Character-level Levenshtein matching",
        features=["Good for typos", "Fast, deterministic"],
    ),
    Algorithm(
        name="Jaccard",
        description="Token overlap scoring",
        features=["Word-level comparison", "Order-independent"],
    ),
    Algorithm(
        name="Ensemble",
        description="Weighted combination of all methods",
        features=["Configurable weights", "Best overall accuracy"],
    ),
]


@router.get("/algorithms", response_model=AlgorithmsResponse)
async def get_algorithms() -> AlgorithmsResponse:
    """Get static algorithm descriptions.

    Returns descriptions and features for each matching algorithm.
    No caching needed - this is static data.
    """
    return AlgorithmsResponse(algorithms=ALGORITHMS)


# ---------------------------------------------------------------------------
# Legacy endpoint for backward compatibility
# ---------------------------------------------------------------------------


@router.get("")
async def get_comparison():
    """Return algorithm comparison data for the React frontend.

    DEPRECATED: Use individual endpoints for better performance.
    This endpoint is kept for backward compatibility.
    """
    db = sf.get_database()

    # Get agreement analysis
    try:
        agreement_result = await sf.query(f"""
            SELECT
                CASE
                    WHEN SEARCH_MATCHED_ID = COSINE_MATCHED_ID
                         AND COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID
                         AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID
                         AND SEARCH_MATCHED_ID IS NOT NULL
                         AND SEARCH_MATCHED_ID != 'None'
                    THEN '4 of 4 Agree'
                    WHEN (SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None')
                        OR (SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND COSINE_MATCHED_ID = JACCARD_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None')
                        OR (SEARCH_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None')
                        OR (COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID AND COSINE_MATCHED_ID IS NOT NULL AND COSINE_MATCHED_ID != 'None')
                    THEN '3 of 4 Agree'
                    WHEN (SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None')
                        OR (SEARCH_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None')
                        OR (SEARCH_MATCHED_ID = JACCARD_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None')
                        OR (COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND COSINE_MATCHED_ID IS NOT NULL AND COSINE_MATCHED_ID != 'None')
                        OR (COSINE_MATCHED_ID = JACCARD_MATCHED_ID AND COSINE_MATCHED_ID IS NOT NULL AND COSINE_MATCHED_ID != 'None')
                        OR (EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID AND EDIT_DISTANCE_MATCHED_ID IS NOT NULL AND EDIT_DISTANCE_MATCHED_ID != 'None')
                    THEN '2 of 4 Agree'
                    ELSE '0 of 4 Agree'
                END AS agreement_level,
                COUNT(*) AS match_count,
                ROUND(AVG(ENSEMBLE_SCORE), 4) AS avg_confidence
            FROM {db}.HARMONIZED.ITEM_MATCHES
            WHERE CORTEX_SEARCH_SCORE IS NOT NULL
            GROUP BY agreement_level
            ORDER BY agreement_level DESC
        """)
    except Exception:
        agreement_result = []

    agreement_data = [
        {
            "level": row.get("AGREEMENT_LEVEL", ""),
            "count": int(row.get("MATCH_COUNT", 0) or 0),
            "avgConfidence": float(row.get("AVG_CONFIDENCE", 0) or 0),
        }
        for row in agreement_result
    ]

    # Get source performance
    try:
        source_result = await sf.query(f"""
            SELECT
                ri.SOURCE_SYSTEM,
                COUNT(*) AS item_count,
                ROUND(AVG(im.CORTEX_SEARCH_SCORE), 4) AS avg_search,
                ROUND(AVG(im.COSINE_SCORE), 4) AS avg_cosine,
                ROUND(AVG(im.EDIT_DISTANCE_SCORE), 4) AS avg_edit,
                ROUND(AVG(im.JACCARD_SCORE), 4) AS avg_jaccard,
                ROUND(AVG(im.ENSEMBLE_SCORE), 4) AS avg_ensemble
            FROM {db}.RAW.RAW_RETAIL_ITEMS ri
            JOIN {db}.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
            WHERE im.ENSEMBLE_SCORE IS NOT NULL
            GROUP BY ri.SOURCE_SYSTEM
            ORDER BY ri.SOURCE_SYSTEM
        """)
    except Exception:
        source_result = []

    source_performance_data = [
        {
            "source": row.get("SOURCE_SYSTEM", ""),
            "itemCount": int(row.get("ITEM_COUNT", 0) or 0),
            "avgSearch": float(row.get("AVG_SEARCH", 0) or 0),
            "avgCosine": float(row.get("AVG_COSINE", 0) or 0),
            "avgEdit": float(row.get("AVG_EDIT", 0) or 0),
            "avgJaccard": float(row.get("AVG_JACCARD", 0) or 0),
            "avgEnsemble": float(row.get("AVG_ENSEMBLE", 0) or 0),
        }
        for row in source_result
    ]

    # Get method accuracy
    try:
        accuracy_result = await sf.query(f"SELECT * FROM {db}.ANALYTICS.DT_METHOD_ACCURACY")
        accuracy_data = accuracy_result[0] if accuracy_result else {}
    except Exception:
        accuracy_data = {}

    method_accuracy_data = {
        "totalConfirmed": int(accuracy_data.get("TOTAL_CONFIRMED", 0) or 0),
        "searchCorrect": int(accuracy_data.get("SEARCH_CORRECT", 0) or 0),
        "searchAccuracyPct": float(accuracy_data.get("SEARCH_ACCURACY_PCT", 0) or 0),
        "cosineCorrect": int(accuracy_data.get("COSINE_CORRECT", 0) or 0),
        "cosineAccuracyPct": float(accuracy_data.get("COSINE_ACCURACY_PCT", 0) or 0),
        "editCorrect": int(accuracy_data.get("EDIT_CORRECT", 0) or 0),
        "editAccuracyPct": float(accuracy_data.get("EDIT_ACCURACY_PCT", 0) or 0),
        "jaccardCorrect": int(accuracy_data.get("JACCARD_CORRECT", 0) or 0),
        "jaccardAccuracyPct": float(accuracy_data.get("JACCARD_ACCURACY_PCT", 0) or 0),
        "ensembleCorrect": int(accuracy_data.get("ENSEMBLE_CORRECT", 0) or 0),
        "ensembleAccuracyPct": float(accuracy_data.get("ENSEMBLE_ACCURACY_PCT", 0) or 0),
    }

    return {
        "algorithms": [a.model_dump() for a in ALGORITHMS],
        "agreement": agreement_data,
        "sourcePerformance": source_performance_data,
        "methodAccuracy": method_accuracy_data,
    }
