"""Match bulk actions endpoint.

Provides bulk accept/reject operations for the match review queue
via the BULK_SUBMIT_REVIEW stored procedure.

Endpoints:
    POST /bulk: Bulk status update for multiple matches.

Side Effects:
    - Calls HARMONIZED.BULK_SUBMIT_REVIEW stored procedure which:
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
from backend.api.schemas.matches import BulkActionRequest, BulkActionResponse

router = APIRouter(tags=["matches"])
logger = logging.getLogger(__name__)

# Map frontend action values to stored procedure action values
_ACTION_MAP = {
    "accept": "CONFIRM",
    "reject": "REJECT",
}


def _cache_invalidate() -> None:
    """Invalidate all cached query results."""
    from backend.services.cache import get_async_cache

    get_async_cache().invalidate()


@router.post("/bulk", response_model=BulkActionResponse)
async def bulk_action(body: BulkActionRequest) -> BulkActionResponse:
    """Handle bulk match actions via BULK_SUBMIT_REVIEW stored procedure.

    Uses the BULK_SUBMIT_REVIEW stored procedure which:
    - Uses pre-computed NORMALIZED_DESCRIPTION for correct deduplication
    - Writes to CONFIRMED_MATCHES cache for fast-path auto-accept
    - Propagates confirmations to all sibling items automatically
    - Generates ML training data from review decisions

    Side Effects:
        - Calls BULK_SUBMIT_REVIEW stored procedure (see docstring above)
        - Invalidates service-layer cache on success
    """
    db = sf.get_database()

    action = body.action
    ids = body.ids

    if not ids:
        return BulkActionResponse(success=False, error="No IDs provided")

    # Map frontend action to SP action
    sp_action = _ACTION_MAP.get(action)
    if not sp_action:
        return BulkActionResponse(
            success=False,
            error=f"Unsupported action: {action}. Use 'accept' or 'reject'.",
        )

    try:
        # Build the VARIANT array for the stored procedure
        # Format: [{"match_id": "...", "action": "CONFIRM"}, ...]
        items_array = [{"match_id": mid, "action": sp_action} for mid in ids]
        items_json = json.dumps(items_array)

        # Call the BULK_SUBMIT_REVIEW stored procedure
        result = await sf.query(f"""
            CALL {db}.HARMONIZED.BULK_SUBMIT_REVIEW(
                PARSE_JSON('{items_json}'),
                CURRENT_USER(),
                NULL
            )
        """)

        if not result:
            return BulkActionResponse(success=False, error="No response from stored procedure")

        # Parse the VARIANT response from the stored procedure
        sp_response = result[0].get("BULK_SUBMIT_REVIEW", {})
        if isinstance(sp_response, str):
            sp_response = json.loads(sp_response)

        if sp_response.get("status") == "error":
            error_msg = sp_response.get("message", "Unknown error from stored procedure")
            logger.warning("BULK_SUBMIT_REVIEW failed: %s", error_msg)
            return BulkActionResponse(success=False, error=error_msg)

        # Extract counts from SP response
        success_count = sp_response.get("success_count", len(ids))
        propagated_total = sp_response.get("propagated_total", 0)

        _cache_invalidate()
        return BulkActionResponse(
            success=True,
            updated=success_count + propagated_total,
        )
    except Exception as e:
        logger.exception("Error calling BULK_SUBMIT_REVIEW")
        return BulkActionResponse(success=False, error=str(e))
