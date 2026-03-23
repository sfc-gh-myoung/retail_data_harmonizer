"""Match status update endpoint.

Provides single-match status updates with automatic propagation to related items
sharing the same normalized description via the SUBMIT_REVIEW stored procedure.

Endpoints:
    POST /{match_id}/status: Update match status with automatic sibling propagation.

Side Effects:
    - Calls HARMONIZED.SUBMIT_REVIEW stored procedure which:
      - UPDATE on RAW.RAW_RETAIL_ITEMS and HARMONIZED.ITEM_MATCHES
      - MERGE into HARMONIZED.CONFIRMED_MATCHES (fast-path cache)
      - INSERT into ANALYTICS.MATCH_AUDIT_LOG for audit trail
      - INSERT into HARMONIZED.ML_TRAINING_DATASET for model training
      - Propagates to all items with same NORMALIZED_DESCRIPTION
    - Invalidates service-layer cache
"""

from __future__ import annotations

import json
import logging

from fastapi import APIRouter

from backend.api import snowflake_client as sf
from backend.api.schemas.matches import StatusUpdateRequest, StatusUpdateResponse

router = APIRouter(tags=["matches"])
logger = logging.getLogger(__name__)

# Map React frontend status values to stored procedure action values
_STATUS_TO_ACTION = {
    "CONFIRMED": "CONFIRM",
    "REJECTED": "REJECT",
}


def _cache_invalidate() -> None:
    """Invalidate all cached query results."""
    from backend.services.cache import get_async_cache

    get_async_cache().invalidate()


@router.post("/{match_id}/status", response_model=StatusUpdateResponse)
async def update_status(match_id: str, body: StatusUpdateRequest) -> StatusUpdateResponse:
    """Update match status for the React frontend via SUBMIT_REVIEW stored procedure.

    Uses the SUBMIT_REVIEW stored procedure which:
    - Uses pre-computed NORMALIZED_DESCRIPTION for correct deduplication
    - Writes to CONFIRMED_MATCHES cache for fast-path auto-accept
    - Propagates confirmations to all sibling items automatically
    - Generates ML training data from review decisions

    Side Effects:
        - Calls SUBMIT_REVIEW stored procedure (see docstring above)
        - Invalidates service-layer cache on success
    """
    db = sf.get_database()

    new_status = body.status

    if not new_status:
        return StatusUpdateResponse(success=False, error="No status provided")

    # Map frontend status to SP action
    action = _STATUS_TO_ACTION.get(new_status)
    if not action:
        return StatusUpdateResponse(
            success=False,
            error=f"Unsupported status: {new_status}. Use CONFIRMED or REJECTED.",
        )

    try:
        # Call the SUBMIT_REVIEW stored procedure
        # It handles: status update, CONFIRMED_MATCHES cache, sibling propagation, ML data
        result = await sf.query(f"""
            CALL {db}.HARMONIZED.SUBMIT_REVIEW(
                '{match_id}',
                '{action}',
                NULL,
                CURRENT_USER(),
                NULL,
                NULL
            )
        """)

        if not result:
            return StatusUpdateResponse(success=False, error="No response from stored procedure")

        # Parse the JSON response from the stored procedure
        sp_response = result[0].get("SUBMIT_REVIEW", "{}")
        if isinstance(sp_response, str):
            sp_response = json.loads(sp_response)

        if sp_response.get("status") == "error":
            error_msg = sp_response.get("message", "Unknown error from stored procedure")
            logger.warning("SUBMIT_REVIEW failed: %s", error_msg)
            return StatusUpdateResponse(success=False, error=error_msg)

        # Extract counts from SP response
        rows_updated = sp_response.get("rows_updated", 1)
        propagated_items = sp_response.get("propagated_items", 0)

        _cache_invalidate()
        return StatusUpdateResponse(
            success=True,
            matchId=match_id,
            status=new_status,
            updatedCount=rows_updated + propagated_items,
            variantCount=1 + (1 if propagated_items > 0 else 0),
        )
    except Exception as e:
        logger.exception("Error calling SUBMIT_REVIEW for match %s", match_id)
        return StatusUpdateResponse(success=False, error=str(e))
