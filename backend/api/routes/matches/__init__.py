"""Matches v2 API routes.

Mounts all match-related endpoints under /api/v2/matches:
    - POST /search: Paginated match search with filtering and sorting
    - GET /filter-options: Dropdown filter values for the review UI
    - GET /{item_id}/alternatives: Alternative match candidates
    - POST /bulk: Bulk accept/reject operations
    - POST /{match_id}/status: Single match status update with propagation
"""

from fastapi import APIRouter

from backend.api.routes.matches import (
    alternatives,
    bulk,
    filter_options,
    search,
    status,
)

router = APIRouter(prefix="/api/v2/matches", tags=["matches"])

router.include_router(search.router)
router.include_router(filter_options.router)
router.include_router(alternatives.router)
router.include_router(bulk.router)
router.include_router(status.router)
