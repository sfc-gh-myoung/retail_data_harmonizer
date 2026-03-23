"""Pipeline phases progress endpoint.

Returns progress information for each pipeline processing phase.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter

from backend.api.deps import CacheDep, DashboardServiceDep
from backend.api.schemas.pipeline import PhaseProgress, PhasesResponse

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 2.0


@router.get("/phases", response_model=PhasesResponse)
async def get_pipeline_phases(
    svc: DashboardServiceDep,
    cache: CacheDep,
) -> PhasesResponse:
    """Get progress for each pipeline processing phase.

    Returns 5 phases: Cortex Search, Cosine Match, Edit Distance,
    Jaccard Match, Ensemble with their completion status.

    Cache TTL: 2 seconds
    """

    async def fetch_phases() -> PhasesResponse:
        try:
            p = await svc.get_progress_data()
            if p:
                pipeline_items = int(p.get("PIPELINE_ITEMS", 0) or 0)

                phases = [
                    PhaseProgress(
                        name="Cortex Search",
                        done=int(p.get("SEARCH_DONE", 0) or 0),
                        total=pipeline_items,
                        pct=float(p.get("SEARCH_PCT", 0) or 0),
                        state=p.get("SEARCH_STATE", "WAITING"),
                        color="#29B5E8",
                    ),
                    PhaseProgress(
                        name="Cosine Match",
                        done=int(p.get("COSINE_DONE", 0) or 0),
                        total=pipeline_items,
                        pct=float(p.get("COSINE_PCT", 0) or 0),
                        state=p.get("COSINE_STATE", "WAITING"),
                        color="#667eea",
                    ),
                    PhaseProgress(
                        name="Edit Distance",
                        done=int(p.get("EDIT_DONE", 0) or 0),
                        total=pipeline_items,
                        pct=float(p.get("EDIT_PCT", 0) or 0),
                        state=p.get("EDIT_STATE", "WAITING"),
                        color="#FF9800",
                    ),
                    PhaseProgress(
                        name="Jaccard Match",
                        done=int(p.get("JACCARD_DONE", 0) or 0),
                        total=pipeline_items,
                        pct=float(p.get("JACCARD_PCT", 0) or 0),
                        state=p.get("JACCARD_STATE", "WAITING"),
                        color="#9C27B0",
                    ),
                    PhaseProgress(
                        name="Ensemble",
                        done=int(p.get("ENSEMBLE_DONE", 0) or 0),
                        total=pipeline_items,
                        pct=float(p.get("ENSEMBLE_PCT", 0) or 0),
                        state=p.get("ENSEMBLE_STATE", "WAITING"),
                        color="#2196F3",
                    ),
                ]

                pipeline_state = p.get("PIPELINE_STATE", "NOT_STARTED")
                active_phases = [ph.name for ph in phases if ph.state == "PROCESSING"]
                active_phase = ", ".join(active_phases) if active_phases else None

                return PhasesResponse(
                    phases=phases,
                    pipeline_state=pipeline_state,
                    active_phase=active_phase,
                    ensemble_waiting_for=p.get("ENSEMBLE_WAITING_FOR"),
                    batch_id=p.get("BATCH_ID", ""),
                )
        except Exception as e:
            logger.warning(f"Failed to fetch phases data: {e}")

        # Return empty response on error
        return PhasesResponse(phases=[], pipeline_state=None, active_phase=None)

    return await cache.get_or_fetch("pipeline:phases", CACHE_TTL_SECONDS, fetch_phases)
