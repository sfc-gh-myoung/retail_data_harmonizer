"""Settings API routes for React frontend.

Provides read access to the application configuration stored in ANALYTICS.CONFIG.
Returns structured config grouped by domain: weights, thresholds, performance,
cost, and automation.

Endpoints:
    GET /: Return all settings as a structured SettingsResponse.
"""

from __future__ import annotations

from fastapi import APIRouter

from backend.api import snowflake_client as sf
from backend.api.schemas.settings import (
    AutomationConfig,
    CostConfig,
    PerformanceConfig,
    SettingsResponse,
    ThresholdsConfig,
    WeightsConfig,
)

router = APIRouter(prefix="/api/v2/settings", tags=["settings"])


@router.get("/", response_model=SettingsResponse)
async def get_settings() -> SettingsResponse:
    """Return all settings for the React frontend."""
    db = sf.get_database()

    try:
        config_rows = await sf.query(f"SELECT CONFIG_KEY, CONFIG_VALUE FROM {db}.ANALYTICS.CONFIG")
        config = {r["CONFIG_KEY"]: r["CONFIG_VALUE"] for r in config_rows}
    except Exception:
        config = {}

    return SettingsResponse(
        weights=WeightsConfig(
            cortexSearch=float(config.get("ENSEMBLE_WEIGHT_SEARCH", 0.3)),
            cosine=float(config.get("ENSEMBLE_WEIGHT_COSINE", 0.3)),
            editDistance=float(config.get("ENSEMBLE_WEIGHT_EDIT", 0.2)),
            jaccard=float(config.get("ENSEMBLE_WEIGHT_JACCARD", 0.2)),
        ),
        thresholds=ThresholdsConfig(
            autoAccept=float(config.get("AUTO_ACCEPT_THRESHOLD", 0.85)),
            reject=float(config.get("REVIEW_THRESHOLD", 0.3)),
            reviewMin=float(config.get("REVIEW_THRESHOLD", 0.5)),
            reviewMax=float(config.get("AUTO_ACCEPT_THRESHOLD", 0.85)),
        ),
        performance=PerformanceConfig(
            batchSize=int(config.get("DEFAULT_BATCH_SIZE", 1000)),
            parallelism=int(config.get("CORTEX_PARALLEL_THREADS", 4)),
            cacheEnabled=config.get("CACHE_ENABLED", "true").lower() == "true",
        ),
        cost=CostConfig(
            cortexCostPerCall=float(config.get("CREDIT_RATE_USD", 0.01)),
            targetROI=float(config.get("TARGET_ROI", 10.0)),
            maxDailyCost=float(config.get("MAX_DAILY_COST", 100.0)),
        ),
        automation=AutomationConfig(
            autoAcceptEnabled=config.get("AGENTIC_ENABLED", "true").lower() == "true",
            autoRejectEnabled=config.get("AUTO_REJECT_ENABLED", "false").lower() == "true",
            minAgreementLevel=int(config.get("MIN_AGREEMENT_LEVEL", 3)),
        ),
    )
