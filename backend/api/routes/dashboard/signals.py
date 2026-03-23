"""Dashboard signals endpoint.

Returns signal dominance, alignment, and agreement metrics.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter

from backend.api.deps import CacheDep, DashboardServiceDep
from backend.api.schemas.dashboard import (
    AgreementLevel,
    SignalAlignment,
    SignalDominance,
    SignalsResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 30.0

SIGNAL_COLORS = {
    "SEARCH": "#29B5E8",
    "COSINE": "#667eea",
    "EDIT": "#00C853",
    "JACCARD": "#FF9800",
}

AGREEMENT_COLORS = {
    "1-Way": "#FF6B6B",
    "2-Way": "#FFD600",
    "3-Way": "#29B5E8",
    "4-Way": "#00C853",
    "5-Way": "#9C27B0",
    "No Agreement": "#9E9E9E",
}


@router.get("/signals", response_model=SignalsResponse)
async def get_dashboard_signals(
    svc: DashboardServiceDep,
    cache: CacheDep,
) -> SignalsResponse:
    """Get signal dominance, alignment, and agreement metrics.

    Returns which signals are most dominant, how well they align
    with the ensemble decision, and agreement distribution.

    Cache TTL: 30 seconds
    """

    async def fetch_signals() -> SignalsResponse:
        try:
            combined = await svc.get_combined_data()
            signal_dominance_rows = combined.get("signal_dominance_rows", [])
            signal_alignment_rows = combined.get("signal_alignment_rows", [])
            agreement_rows = combined.get("agreement_rows", [])

            # Signal dominance
            dominance_total = sum(int(r.get("COUNT", 0) or 0) for r in signal_dominance_rows)
            signal_dominance = []
            for row in signal_dominance_rows:
                method = row.get("METHOD", "")
                count = int(row.get("COUNT", 0) or 0)
                pct = round(count / dominance_total * 100, 1) if dominance_total > 0 else 0.0
                signal_dominance.append(
                    SignalDominance(
                        method=method,
                        count=count,
                        pct=pct,
                        color=SIGNAL_COLORS.get(method, "#9E9E9E"),
                    )
                )

            # Signal alignment
            alignment_total = sum(int(r.get("MATCHES", 0) or 0) for r in signal_alignment_rows)
            signal_alignment = []
            for row in signal_alignment_rows:
                method = row.get("METHOD", "")
                count = int(row.get("MATCHES", 0) or 0)
                pct = round(count / alignment_total * 100, 1) if alignment_total > 0 else 0.0
                signal_alignment.append(
                    SignalAlignment(
                        method=method,
                        count=count,
                        pct=pct,
                        color=SIGNAL_COLORS.get(method, "#9E9E9E"),
                    )
                )

            # Agreement distribution
            agreement_total = sum(int(r.get("COUNT", 0) or 0) for r in agreement_rows)
            agreements = []
            for row in agreement_rows:
                level = row.get("AGREEMENT_LEVEL", "")
                count = int(row.get("COUNT", 0) or 0)
                pct = round(count / agreement_total * 100, 1) if agreement_total > 0 else 0.0
                agreements.append(
                    AgreementLevel(
                        level=level,
                        count=count,
                        pct=pct,
                        color=AGREEMENT_COLORS.get(level, "#9E9E9E"),
                    )
                )

            return SignalsResponse(
                signal_dominance=signal_dominance,
                signal_alignment=signal_alignment,
                agreements=agreements,
            )
        except Exception as e:
            logger.warning(f"Failed to fetch signals: {e}")
            return SignalsResponse(
                signal_dominance=[],
                signal_alignment=[],
                agreements=[],
            )

    return await cache.get_or_fetch("dashboard:signals", CACHE_TTL_SECONDS, fetch_signals)
