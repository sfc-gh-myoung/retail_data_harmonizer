"""System API routes for health and status checks."""

from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel, Field

from backend.api import snowflake_client as sf

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
    """Database status response."""

    connected: bool = Field(..., description="Whether DB is connected")
    tables: list[TableCount] | None = Field(None, description="Table row counts")
    error: str | None = Field(None, description="Error message if failed")


@router.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    """Return simple health check status.

    Returns:
        JSON with status "ok" if API is responding.
    """
    return HealthResponse(status="ok")


@router.get("/status", response_model=StatusResponse)
async def api_status() -> StatusResponse:
    """Return DB status and row counts as JSON.

    Returns:
        StatusResponse with connection status and table row counts.
    """
    db = sf.get_database()
    try:
        connected = await sf.test_connection()
        rows = await sf.query(f"""
            SELECT 'STANDARD_ITEMS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM {db}.RAW.STANDARD_ITEMS
            UNION ALL SELECT 'RAW_RETAIL_ITEMS', COUNT(*) FROM {db}.RAW.RAW_RETAIL_ITEMS
            UNION ALL SELECT 'ITEM_MATCHES', COUNT(*) FROM {db}.HARMONIZED.ITEM_MATCHES
            UNION ALL SELECT 'MATCH_CANDIDATES', COUNT(*) FROM {db}.HARMONIZED.MATCH_CANDIDATES
            ORDER BY TABLE_NAME
        """)
        tables = [TableCount(**row) for row in rows]
        return StatusResponse(connected=connected, tables=tables)
    except Exception as exc:
        return StatusResponse(connected=False, error=str(exc))
