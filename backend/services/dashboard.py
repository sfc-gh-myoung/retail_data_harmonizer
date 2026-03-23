"""Dashboard service for KPI, confidence, cost, scale, activity, and progress queries.

Extracts SQL queries from dashboard route handlers into a reusable service layer.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from typing import Any

from backend.services.base import BaseService


@dataclass
class DashboardService(BaseService):
    """Service for dashboard data queries.

    Encapsulates all SQL queries used by dashboard route handlers,
    returning raw query results for presentation by the routes.

    Attributes:
        db_name: Inherited from BaseService - database name for fully qualified queries.
        sf: Inherited from BaseService - Snowflake client for query execution.
        cache: Inherited from BaseService - optional TTL cache for query results.

    Side Effects:
        - Executes SELECT queries against ANALYTICS Dynamic Tables
          (DT_DASHBOARD_KPIS, DT_DASHBOARD_SOURCES, DT_DASHBOARD_CATEGORIES, etc.)
        - Reads from ANALYTICS.MATCH_AUDIT_LOG for activity data
        - Reads from ANALYTICS.V_COST_COMPARISON for cost metrics
        - Reads from ANALYTICS.DT_DASHBOARD_SCALE for scale projections
    """

    async def get_combined_data(self) -> dict[str, Any]:
        """Fetch KPI, source-status, category, and signal data in parallel.

        Executes 6 parallel queries for the main dashboard view using
        materialized views and aggregation queries.

        Returns:
            Dict with keys: kpi, source_status_rows, category_rate_rows,
            signal_dominance_rows, signal_alignment_rows, agreement_rows.
        """
        if self.cache:
            cached = self.cache.get("raw_items_combined")
            if cached is not None:
                return cached

        db = self.db_name

        (
            kpi_rows,
            source_rows,
            category_rows,
            signal_dominance_rows,
            signal_alignment_rows,
            agreement_rows,
        ) = await asyncio.gather(
            self.sf.query(f"SELECT * FROM {db}.ANALYTICS.DT_DASHBOARD_KPIS"),
            self.sf.query(f"SELECT * FROM {db}.ANALYTICS.DT_DASHBOARD_SOURCES ORDER BY SOURCE_SYSTEM, MATCH_STATUS"),
            self.sf.query(f"SELECT * FROM {db}.ANALYTICS.DT_DASHBOARD_CATEGORIES ORDER BY TOTAL DESC"),
            # Signal Dominance: which signal had the highest score per match
            self.sf.query(f"""
                SELECT DOMINANT_SIGNAL as METHOD, COUNT(*) as COUNT
                FROM (
                    SELECT
                        CASE GREATEST(
                            COALESCE(CORTEX_SEARCH_SCORE, 0),
                            COALESCE(COSINE_SCORE, 0),
                            COALESCE(EDIT_DISTANCE_SCORE, 0),
                            COALESCE(JACCARD_SCORE, 0)
                        )
                            WHEN COALESCE(CORTEX_SEARCH_SCORE, 0) THEN 'SEARCH'
                            WHEN COALESCE(COSINE_SCORE, 0) THEN 'COSINE'
                            WHEN COALESCE(EDIT_DISTANCE_SCORE, 0) THEN 'EDIT'
                            WHEN COALESCE(JACCARD_SCORE, 0) THEN 'JACCARD'
                            ELSE 'NONE'
                        END as DOMINANT_SIGNAL
                    FROM {db}.HARMONIZED.ITEM_MATCHES
                    WHERE SUGGESTED_STANDARD_ID IS NOT NULL
                )
                GROUP BY DOMINANT_SIGNAL
                ORDER BY COUNT DESC
            """),
            # Signal-Ensemble Alignment: how often each signal agrees with ensemble
            self.sf.query(f"""
                SELECT 'SEARCH' as METHOD,
                       SUM(CASE WHEN SEARCH_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END) as MATCHES
                FROM {db}.HARMONIZED.ITEM_MATCHES WHERE SUGGESTED_STANDARD_ID IS NOT NULL
                UNION ALL
                SELECT 'COSINE', SUM(CASE WHEN COSINE_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END)
                FROM {db}.HARMONIZED.ITEM_MATCHES WHERE SUGGESTED_STANDARD_ID IS NOT NULL
                UNION ALL
                SELECT 'EDIT', SUM(CASE WHEN EDIT_DISTANCE_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END)
                FROM {db}.HARMONIZED.ITEM_MATCHES WHERE SUGGESTED_STANDARD_ID IS NOT NULL
                UNION ALL
                SELECT 'JACCARD', SUM(CASE WHEN JACCARD_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END)
                FROM {db}.HARMONIZED.ITEM_MATCHES WHERE SUGGESTED_STANDARD_ID IS NOT NULL
                ORDER BY MATCHES DESC
            """),
            # Agreement distribution: how many methods agree on each match (4 methods max)
            self.sf.query(f"""
                SELECT
                    CASE
                        WHEN (CASE WHEN SEARCH_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END +
                              CASE WHEN COSINE_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END +
                              CASE WHEN EDIT_DISTANCE_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END +
                              CASE WHEN JACCARD_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END) = 1 THEN '1-Way'
                        WHEN (CASE WHEN SEARCH_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END +
                              CASE WHEN COSINE_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END +
                              CASE WHEN EDIT_DISTANCE_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END +
                              CASE WHEN JACCARD_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END) = 2 THEN '2-Way'
                        WHEN (CASE WHEN SEARCH_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END +
                              CASE WHEN COSINE_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END +
                              CASE WHEN EDIT_DISTANCE_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END +
                              CASE WHEN JACCARD_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END) = 3 THEN '3-Way'
                        WHEN (CASE WHEN SEARCH_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END +
                              CASE WHEN COSINE_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END +
                              CASE WHEN EDIT_DISTANCE_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END +
                              CASE WHEN JACCARD_MATCHED_ID = SUGGESTED_STANDARD_ID THEN 1 ELSE 0 END) = 4 THEN '4-Way'
                        ELSE 'No Agreement'
                    END as AGREEMENT_LEVEL,
                    COUNT(*) as COUNT
                FROM {db}.HARMONIZED.ITEM_MATCHES
                WHERE SUGGESTED_STANDARD_ID IS NOT NULL
                GROUP BY AGREEMENT_LEVEL
                ORDER BY
                    CASE AGREEMENT_LEVEL
                        WHEN '1-Way' THEN 1 WHEN '2-Way' THEN 2 WHEN '3-Way' THEN 3
                        WHEN '4-Way' THEN 4 ELSE 5
                    END
            """),
        )

        result = {
            "kpi": kpi_rows[0] if kpi_rows else {},
            "source_status_rows": source_rows,
            "category_rate_rows": category_rows,
            "signal_dominance_rows": signal_dominance_rows,
            "signal_alignment_rows": signal_alignment_rows,
            "agreement_rows": agreement_rows,
        }

        if self.cache:
            self.cache.set("raw_items_combined", result)

        return result

    async def get_confidence_data(self) -> dict[str, list[dict[str, Any]]]:
        """Fetch confidence score distribution data.

        Returns best-match and ensemble confidence bucket distributions
        from materialized views, with per-key caching.

        Returns:
            Dict with keys: confidence_best, confidence_ensemble.
        """
        db = self.db_name

        best_rows = None
        ensemble_rows = None

        if self.cache:
            best_rows = self.cache.get("confidence_best")
            ensemble_rows = self.cache.get("confidence_ensemble")

        if best_rows is None:
            best_rows = await self.sf.query(
                f"SELECT * FROM {db}.ANALYTICS.DT_DASHBOARD_CONFIDENCE_BEST ORDER BY BUCKET"
            )
            if self.cache:
                self.cache.set("confidence_best", best_rows)

        if ensemble_rows is None:
            ensemble_rows = await self.sf.query(
                f"SELECT * FROM {db}.ANALYTICS.DT_DASHBOARD_CONFIDENCE_ENSEMBLE ORDER BY BUCKET"
            )
            if self.cache:
                self.cache.set("confidence_ensemble", ensemble_rows)

        return {"confidence_best": best_rows, "confidence_ensemble": ensemble_rows}

    async def get_cost_data(self) -> dict[str, Any]:
        """Fetch cost and ROI comparison data.

        Returns:
            Single row dict from V_COST_COMPARISON, or empty dict if no data.
        """
        db = self.db_name

        if self.cache:
            cached = self.cache.get("cost")
            if cached is not None:
                return cached

        cost_rows = await self.sf.query(f"SELECT * FROM {db}.ANALYTICS.V_COST_COMPARISON")
        cost_data = cost_rows[0] if cost_rows else {}

        if self.cache:
            self.cache.set("cost", cost_data)

        return cost_data

    async def get_scale_data(self) -> dict[str, Any]:
        """Fetch scale projection metrics.

        Queries DT_DASHBOARD_SCALE and computes dedup ratio and fast-path rate.

        Returns:
            Dict with keys: total, unique_count, dedup_ratio, fast_path_count,
            fast_path_rate.
        """
        db = self.db_name

        if self.cache:
            cached = self.cache.get("scale")
            if cached is not None:
                return cached

        scale_rows = await self.sf.query(f"SELECT * FROM {db}.ANALYTICS.DT_DASHBOARD_SCALE")
        scale_row = scale_rows[0] if scale_rows else {}

        total = int(scale_row.get("TOTAL_ITEMS", 0) or 0)
        unique_count = int(scale_row.get("UNIQUE_COUNT", 0) or 0)
        fast_path_count = int(scale_row.get("FAST_PATH_COUNT", 0) or 0)

        dedup_ratio = round(unique_count / total, 2) if total > 0 else 1.0
        fast_path_rate = round(fast_path_count / total * 100, 1) if total > 0 else 0.0

        scale_data = {
            "total": total,
            "unique_count": unique_count,
            "dedup_ratio": dedup_ratio,
            "fast_path_count": fast_path_count,
            "fast_path_rate": fast_path_rate,
        }

        if self.cache:
            self.cache.set("scale", scale_data)

        return scale_data

    async def get_activity_data(self) -> list[dict[str, Any]]:
        """Fetch recent activity log entries.

        Returns:
            List of recent PIPELINE_RUN and STATUS_CHANGE audit log entries,
            ordered by most recent first, limited to 20.
        """
        db = self.db_name

        if self.cache:
            cached = self.cache.get("activity")
            if cached is not None:
                return cached

        activity_rows = await self.sf.query(f"""
            SELECT
                TO_VARCHAR(CREATED_AT, 'YYYY-MM-DD HH24:MI') AS timestamp,
                ACTION AS action,
                COALESCE(NOTES, '') AS details,
                REVIEWED_BY AS performed_by
            FROM {db}.ANALYTICS.MATCH_AUDIT_LOG
            WHERE ACTION IN ('PIPELINE_RUN', 'STATUS_CHANGE')
            ORDER BY CREATED_AT DESC
            LIMIT 20
        """)

        if self.cache:
            self.cache.set("activity", activity_rows)

        return activity_rows

    async def get_progress_data(self) -> dict[str, Any]:
        """Fetch pipeline phase progress status.

        Queries DT_PIPELINE_PHASE_STATUS for per-phase item counts, states,
        and pipeline funnel metrics.

        Returns:
            Single row dict from DT_PIPELINE_PHASE_STATUS, or empty dict.
        """
        db = self.db_name

        progress_rows = await self.sf.query(f"SELECT * FROM {db}.ANALYTICS.DT_PIPELINE_PHASE_STATUS")

        return progress_rows[0] if progress_rows else {}
