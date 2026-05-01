"""System API routes for health and status checks."""

from __future__ import annotations

from fastapi import APIRouter, Request
from pydantic import BaseModel, Field

from backend.api import snowflake_client as sf
from backend.api.errors import ErrorEnvelope, classify_snowflake_error

router = APIRouter(prefix="/api/v2", tags=["system"])


class HealthResponse(BaseModel):
    """Health check response."""

    status: str = Field(..., description="Health status")


class TableCount(BaseModel):
    """Row count for a single table."""

    table_name: str = Field(..., alias="TABLE_NAME", description="Table name")
    row_count: int = Field(..., alias="ROW_COUNT", description="Number of rows")

    model_config = {"populate_by_name": True}


class StatusResponse(BaseModel):
    """Database status response with structured dependency health."""

    connected: bool = Field(..., description="Whether Snowflake is connected")
    tables: list[TableCount] | None = Field(None, description="Table row counts")
    error: ErrorEnvelope | None = Field(None, description="Classified error envelope if connection failed")


@router.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    """Return simple health check status.

    Returns:
        JSON with status "ok" if API is responding.
    """
    return HealthResponse(status="ok")


@router.get("/status", response_model=StatusResponse)
async def api_status(request: Request) -> StatusResponse:
    """Return Snowflake dependency status with structured error information.

    Distinguishes API health (always OK if responding) from Snowflake
    connectivity. Returns classified error envelope for connection failures.

    Args:
        request: FastAPI request (provides request_id from middleware)

    Returns:
        StatusResponse with connection status, table counts, or classified error.
    """
    db = sf.get_database()
    request_id = getattr(request.state, "request_id", "unknown")

    try:
        connected = await sf.test_connection()
        rows = await sf.query(
            f"""
            SELECT 'STANDARD_ITEMS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM {db}.RAW.STANDARD_ITEMS
            UNION ALL SELECT 'RAW_RETAIL_ITEMS', COUNT(*) FROM {db}.RAW.RAW_RETAIL_ITEMS
            UNION ALL SELECT 'ITEM_MATCHES', COUNT(*) FROM {db}.HARMONIZED.ITEM_MATCHES
            UNION ALL SELECT 'MATCH_CANDIDATES', COUNT(*) FROM {db}.HARMONIZED.MATCH_CANDIDATES
            ORDER BY TABLE_NAME
        """
        )
        tables = [TableCount(**row) for row in rows]
        return StatusResponse(connected=connected, tables=tables)
    except Exception as exc:
        # Classify Snowflake connection/query failure
        envelope = classify_snowflake_error(exc, request_id=request_id)
        return StatusResponse(connected=False, error=envelope)
