"""Comparison service for algorithm agreement, performance, and similarity queries.

Extracts SQL queries from comparison route handlers into a reusable service layer.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from backend.services.base import BaseService


@dataclass
class ComparisonService(BaseService):
    """Service for algorithm comparison data queries.

    Encapsulates all SQL queries used by comparison route handlers,
    returning raw query results for presentation by the routes.
    """

    async def get_agreement_analysis(self) -> list[dict[str, Any]]:
        """Analyze 4-way agreement among primary matchers.

        Evaluates agreement levels (Search, Cosine, Edit Distance, Jaccard)
        with match counts and average confidence per level.

        Returns:
            Rows with agreement_level, match_count, avg_confidence.
        """
        db = self.db_name
        return await self.sf.query(f"""
            SELECT
                CASE
                    -- All 4 matchers agree (excluding 'None')
                    WHEN SEARCH_MATCHED_ID = COSINE_MATCHED_ID
                         AND COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID
                         AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID
                         AND SEARCH_MATCHED_ID IS NOT NULL
                         AND SEARCH_MATCHED_ID != 'None'
                    THEN '4 of 4 Agree'
                    -- 3 of 4 agree (excluding 'None')
                    WHEN (SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None')
                        OR (SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND COSINE_MATCHED_ID = JACCARD_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None')
                        OR (SEARCH_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None')
                        OR (COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID AND COSINE_MATCHED_ID IS NOT NULL AND COSINE_MATCHED_ID != 'None')
                    THEN '3 of 4 Agree'
                    -- 2 of 4 agree (excluding 'None')
                    WHEN (SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None')
                        OR (SEARCH_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None')
                        OR (SEARCH_MATCHED_ID = JACCARD_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None')
                        OR (COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND COSINE_MATCHED_ID IS NOT NULL AND COSINE_MATCHED_ID != 'None')
                        OR (COSINE_MATCHED_ID = JACCARD_MATCHED_ID AND COSINE_MATCHED_ID IS NOT NULL AND COSINE_MATCHED_ID != 'None')
                        OR (EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID AND EDIT_DISTANCE_MATCHED_ID IS NOT NULL AND EDIT_DISTANCE_MATCHED_ID != 'None')
                    THEN '2 of 4 Agree'
                    ELSE '0 of 4 Agree'
                END AS agreement_level,
                COUNT(*) AS match_count,
                ROUND(AVG(ENSEMBLE_SCORE), 4) AS avg_confidence
            FROM {db}.HARMONIZED.ITEM_MATCHES
            WHERE CORTEX_SEARCH_SCORE IS NOT NULL
              AND COSINE_SCORE IS NOT NULL
              AND EDIT_DISTANCE_SCORE IS NOT NULL
              AND JACCARD_SCORE IS NOT NULL
            GROUP BY agreement_level
            ORDER BY agreement_level DESC
        """)

    async def get_source_performance(self) -> list[dict[str, Any]]:
        """Fetch performance metrics by source system.

        Joins raw items with matches to compute average scores
        per matching method, grouped by SOURCE_SYSTEM.

        Returns:
            Rows with SOURCE_SYSTEM, item_count, and avg scores per method.
        """
        db = self.db_name
        return await self.sf.query(f"""
            SELECT
                ri.SOURCE_SYSTEM,
                COUNT(*) AS item_count,
                ROUND(AVG(im.CORTEX_SEARCH_SCORE), 4) AS avg_search,
                ROUND(AVG(im.COSINE_SCORE), 4) AS avg_cosine,
                ROUND(AVG(im.EDIT_DISTANCE_SCORE), 4) AS avg_edit,
                ROUND(AVG(im.JACCARD_SCORE), 4) AS avg_jaccard,
                ROUND(AVG(im.ENSEMBLE_SCORE), 4) AS avg_ensemble
            FROM {db}.RAW.RAW_RETAIL_ITEMS ri
            JOIN {db}.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
            WHERE im.ENSEMBLE_SCORE IS NOT NULL
            GROUP BY ri.SOURCE_SYSTEM
            ORDER BY ri.SOURCE_SYSTEM
        """)

    async def get_method_accuracy(self) -> list[dict[str, Any]]:
        """Fetch method accuracy data from the analytics view.

        Returns:
            All rows from DT_METHOD_ACCURACY.
        """
        db = self.db_name
        return await self.sf.query(f"SELECT * FROM {db}.ANALYTICS.DT_METHOD_ACCURACY")

    async def compute_similarity(self, raw_text: str, std_text: str) -> list[dict[str, Any]]:
        """Compute semantic (cosine) and lexical (edit distance) similarity.

        Uses Snowflake Cortex embeddings for cosine similarity and
        EDITDISTANCE for normalized lexical similarity.

        Args:
            raw_text: The raw input text to compare.
            std_text: The standardized text to compare against.

        Returns:
            Single-row list with COSINE_SIM and EDIT_SIM scores.
        """
        safe_raw = self._safe(raw_text)
        safe_std = self._safe(std_text)
        return await self.sf.query(f"""
            SELECT
                VECTOR_COSINE_SIMILARITY(
                    SNOWFLAKE.CORTEX.EMBED_TEXT_1024('snowflake-arctic-embed-l-v2.0', '{safe_raw}'),
                    SNOWFLAKE.CORTEX.EMBED_TEXT_1024('snowflake-arctic-embed-l-v2.0', '{safe_std}')
                ) AS cosine_sim,
                1.0 - (EDITDISTANCE(UPPER('{safe_raw}'), UPPER('{safe_std}'))::FLOAT
                       / GREATEST(LENGTH('{safe_raw}'), LENGTH('{safe_std}'), 1)) AS edit_sim
        """)
