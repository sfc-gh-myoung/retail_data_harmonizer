"""Comparison API routes for algorithm analysis.

Modular endpoints for the comparison page, each handling a specific data domain
with independent caching for fast, progressive loading.

Endpoints:
- GET /algorithms - Static algorithm descriptions
- GET /agreement - Algorithm agreement analysis (60s cache)
- GET /source-performance - Performance by source system (60s cache)
- GET /method-accuracy - Accuracy metrics per method (60s cache)
"""

from __future__ import annotations

from fastapi import APIRouter

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

