"""Settings API routes for React frontend.

Provides read and write access to the application configuration stored in
ANALYTICS.CONFIG. Returns structured config grouped by domain: weights,
thresholds, performance, cost, and automation.

Threshold model: two editable boundaries (autoAccept, reject) define a derived
review band [reject, autoAccept). reviewMin == reject and reviewMax == autoAccept.

Endpoints:
    GET /: Return all settings as a structured SettingsResponse.
    POST /: Persist editable settings to ANALYTICS.CONFIG and return the result.
"""

from __future__ import annotations

import json

from fastapi import APIRouter, HTTPException

from backend.api import snowflake_client as sf
from backend.api.schemas.settings import (
    AutomationConfig,
    CostConfig,
    PerformanceConfig,
    SettingsResponse,
    SettingsUpdateRequest,
    ThresholdsConfig,
    WeightsConfig,
)

router = APIRouter(prefix="/api/v2/settings", tags=["settings"])


async def _load_config() -> dict[str, str]:
    """Read all CONFIG key/value pairs. Returns empty dict on failure."""
    db = sf.get_database()
    try:
        rows = await sf.query(f"SELECT CONFIG_KEY, CONFIG_VALUE FROM {db}.ANALYTICS.CONFIG")
        return {r["CONFIG_KEY"]: r["CONFIG_VALUE"] for r in rows}
    except Exception:
        return {}


def _build_response(config: dict[str, str]) -> SettingsResponse:
    """Map a CONFIG dict to the structured SettingsResponse.

    Review band is derived: reviewMin = AUTO_REJECT_THRESHOLD,
    reviewMax = AUTO_ACCEPT_THRESHOLD.
    """
    auto_accept = float(config.get("AUTO_ACCEPT_THRESHOLD", 0.75))
    auto_reject = float(config.get("AUTO_REJECT_THRESHOLD", 0.45))

    return SettingsResponse(
        weights=WeightsConfig(
            cortexSearch=float(config.get("ENSEMBLE_WEIGHT_SEARCH", 0.3)),
            cosine=float(config.get("ENSEMBLE_WEIGHT_COSINE", 0.3)),
            editDistance=float(config.get("ENSEMBLE_WEIGHT_EDIT", 0.2)),
            jaccard=float(config.get("ENSEMBLE_WEIGHT_JACCARD", 0.2)),
        ),
        thresholds=ThresholdsConfig(
            autoAccept=auto_accept,
            reject=auto_reject,
            reviewMin=auto_reject,
            reviewMax=auto_accept,
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
            autoAcceptEnabled=config.get("AUTO_ACCEPT_ENABLED", "true").lower() == "true",
            autoRejectEnabled=config.get("AUTO_REJECT_ENABLED", "false").lower() == "true",
            minAgreementLevel=int(config.get("MIN_AGREEMENT_LEVEL", 3)),
        ),
    )


@router.get("/", response_model=SettingsResponse)
async def get_settings() -> SettingsResponse:
    """Return all settings for the React frontend."""
    return _build_response(await _load_config())


@router.post("/", response_model=SettingsResponse)
async def update_settings(payload: SettingsUpdateRequest) -> SettingsResponse:
    """Persist editable settings to ANALYTICS.CONFIG and return the result."""
    t = payload.thresholds
    # Threshold ordering: reject must be strictly below auto-accept.
    if not (0.0 <= t.reject < t.autoAccept <= 1.0):
        raise HTTPException(
            status_code=422,
            detail=(
                "Invalid thresholds: require 0 <= reject < autoAccept <= 1 "
                f"(got reject={t.reject}, autoAccept={t.autoAccept})."
            ),
        )

    # Build CONFIG_KEY -> value map. All values are validated numbers/booleans,
    # so embedding the JSON in the CALL carries no injection risk.
    settings_map: dict[str, str] = {
        "ENSEMBLE_WEIGHT_SEARCH": f"{payload.weights.cortexSearch}",
        "ENSEMBLE_WEIGHT_COSINE": f"{payload.weights.cosine}",
        "ENSEMBLE_WEIGHT_EDIT": f"{payload.weights.editDistance}",
        "ENSEMBLE_WEIGHT_JACCARD": f"{payload.weights.jaccard}",
        "AUTO_ACCEPT_THRESHOLD": f"{t.autoAccept}",
        "AUTO_REJECT_THRESHOLD": f"{t.reject}",
        "DEFAULT_BATCH_SIZE": f"{payload.performance.batchSize}",
        "CORTEX_PARALLEL_THREADS": f"{payload.performance.parallelism}",
        "CACHE_ENABLED": "true" if payload.performance.cacheEnabled else "false",
        "AUTO_ACCEPT_ENABLED": "true" if payload.automation.autoAcceptEnabled else "false",
        "AUTO_REJECT_ENABLED": "true" if payload.automation.autoRejectEnabled else "false",
        "MIN_AGREEMENT_LEVEL": f"{payload.automation.minAgreementLevel}",
    }

    db = sf.get_database()
    payload_json = json.dumps(settings_map)
    try:
        result = await sf.execute(f"CALL {db}.ANALYTICS.UPDATE_CONFIG(PARSE_JSON('{payload_json}'))")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to persist settings: {e}") from e

    # Inspect the procedure's JSON return for an explicit error status.
    try:
        proc_result = json.loads(result)
    except (ValueError, TypeError):
        proc_result = {}
    if proc_result.get("status") == "error":
        raise HTTPException(
            status_code=500,
            detail=proc_result.get("message", "UPDATE_CONFIG returned an error."),
        )

    return _build_response(await _load_config())
