"""Review service for match review queue operations.

Extracts SQL queries from review route handlers into a service layer,
separating data access from HTTP/HTML concerns.
"""

from __future__ import annotations

import json
import logging
from contextlib import suppress
from dataclasses import dataclass
from typing import Any

from backend.services.base import BaseService

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# SQL fragments shared across queries
# ---------------------------------------------------------------------------

_EFFECTIVE_STATUS_CASE = """
            CASE
                WHEN ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'CONFIRMED', 'REJECTED') THEN ri.MATCH_STATUS
                WHEN COALESCE(im.STATUS, ri.MATCH_STATUS) = 'USER_CONFIRMED' THEN 'CONFIRMED'
                ELSE COALESCE(im.STATUS, ri.MATCH_STATUS)
            END AS EFFECTIVE_STATUS"""

_AGREEMENT_LEVEL_CASE = """
            CASE
                WHEN im.SEARCH_MATCHED_ID = im.COSINE_MATCHED_ID
                     AND im.COSINE_MATCHED_ID = im.EDIT_DISTANCE_MATCHED_ID
                     AND im.EDIT_DISTANCE_MATCHED_ID = im.JACCARD_MATCHED_ID
                     AND im.SEARCH_MATCHED_ID IS NOT NULL
                THEN 4
                WHEN (im.SEARCH_MATCHED_ID = im.COSINE_MATCHED_ID AND im.COSINE_MATCHED_ID = im.EDIT_DISTANCE_MATCHED_ID AND im.SEARCH_MATCHED_ID IS NOT NULL)
                  OR (im.SEARCH_MATCHED_ID = im.COSINE_MATCHED_ID AND im.COSINE_MATCHED_ID = im.JACCARD_MATCHED_ID AND im.SEARCH_MATCHED_ID IS NOT NULL)
                  OR (im.SEARCH_MATCHED_ID = im.EDIT_DISTANCE_MATCHED_ID AND im.EDIT_DISTANCE_MATCHED_ID = im.JACCARD_MATCHED_ID AND im.SEARCH_MATCHED_ID IS NOT NULL)
                  OR (im.COSINE_MATCHED_ID = im.EDIT_DISTANCE_MATCHED_ID AND im.EDIT_DISTANCE_MATCHED_ID = im.JACCARD_MATCHED_ID AND im.COSINE_MATCHED_ID IS NOT NULL)
                THEN 3
                WHEN (im.SEARCH_MATCHED_ID = im.COSINE_MATCHED_ID AND im.SEARCH_MATCHED_ID IS NOT NULL)
                  OR (im.SEARCH_MATCHED_ID = im.EDIT_DISTANCE_MATCHED_ID AND im.SEARCH_MATCHED_ID IS NOT NULL)
                  OR (im.SEARCH_MATCHED_ID = im.JACCARD_MATCHED_ID AND im.SEARCH_MATCHED_ID IS NOT NULL)
                  OR (im.COSINE_MATCHED_ID = im.EDIT_DISTANCE_MATCHED_ID AND im.COSINE_MATCHED_ID IS NOT NULL)
                  OR (im.COSINE_MATCHED_ID = im.JACCARD_MATCHED_ID AND im.COSINE_MATCHED_ID IS NOT NULL)
                  OR (im.EDIT_DISTANCE_MATCHED_ID = im.JACCARD_MATCHED_ID AND im.EDIT_DISTANCE_MATCHED_ID IS NOT NULL)
                THEN 2
                ELSE 1
            END AS AGREEMENT_LEVEL"""

_PRIMARY_MATCH_SOURCE_CASE = """
            CASE
                WHEN COALESCE(im.CORTEX_SEARCH_SCORE, 0) >= COALESCE(im.COSINE_SCORE, 0)
                     AND COALESCE(im.CORTEX_SEARCH_SCORE, 0) >= COALESCE(im.EDIT_DISTANCE_SCORE, 0)
                     AND COALESCE(im.CORTEX_SEARCH_SCORE, 0) >= COALESCE(im.JACCARD_SCORE, 0)
                THEN 'SEARCH'
                WHEN COALESCE(im.COSINE_SCORE, 0) >= COALESCE(im.CORTEX_SEARCH_SCORE, 0)
                     AND COALESCE(im.COSINE_SCORE, 0) >= COALESCE(im.EDIT_DISTANCE_SCORE, 0)
                     AND COALESCE(im.COSINE_SCORE, 0) >= COALESCE(im.JACCARD_SCORE, 0)
                THEN 'COSINE'
                WHEN COALESCE(im.EDIT_DISTANCE_SCORE, 0) >= COALESCE(im.CORTEX_SEARCH_SCORE, 0)
                     AND COALESCE(im.EDIT_DISTANCE_SCORE, 0) >= COALESCE(im.COSINE_SCORE, 0)
                     AND COALESCE(im.EDIT_DISTANCE_SCORE, 0) >= COALESCE(im.JACCARD_SCORE, 0)
                THEN 'EDIT'
                ELSE 'JACCARD'
            END AS PRIMARY_MATCH_SOURCE"""

_BASE_SELECT = f"""
            ri.ITEM_ID,
            ri.RAW_DESCRIPTION,
            ri.SOURCE_SYSTEM,
            ri.MATCH_STATUS,
            ri.INFERRED_CATEGORY,
            ri.INFERRED_SUBCATEGORY,
            im.MATCH_ID,
            im.SUGGESTED_STANDARD_ID,
            im.CORTEX_SEARCH_SCORE,
            im.COSINE_SCORE,
            im.EDIT_DISTANCE_SCORE,
            im.JACCARD_SCORE,
            im.ENSEMBLE_SCORE,
            im.MATCH_METHOD,
            im.SEARCH_MATCHED_ID,
            im.COSINE_MATCHED_ID,
            im.EDIT_DISTANCE_MATCHED_ID,
            im.JACCARD_MATCHED_ID,
            CASE WHEN im.LOCK_EXPIRES_AT < CURRENT_TIMESTAMP() THEN NULL ELSE im.LOCKED_BY END AS LOCKED_BY,
            im.IS_CACHED,
            si.STANDARD_DESCRIPTION,
            si.SRP,
            si.BRAND,
            {_EFFECTIVE_STATUS_CASE},
            {_AGREEMENT_LEVEL_CASE},
            {_PRIMARY_MATCH_SOURCE_CASE},
            GREATEST(
                COALESCE(im.CORTEX_SEARCH_SCORE, 0),
                COALESCE(im.COSINE_SCORE, 0),
                COALESCE(im.EDIT_DISTANCE_SCORE, 0),
                COALESCE(im.JACCARD_SCORE, 0)
            ) AS MAX_RAW_SCORE,
            COUNT(*) OVER (PARTITION BY UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\\\s+', ' ')))) AS DUPLICATE_COUNT"""

# Column mapping for sortable headers (with table aliases for inner query)
# Note: Computed columns use full expressions since aliases aren't available in ROW_NUMBER()
_SORT_COLUMNS = {
    "pos_item": "ri.RAW_DESCRIPTION",
    "source": "ri.SOURCE_SYSTEM",
    "category": "ri.INFERRED_CATEGORY",
    "matched": "si.STANDARD_DESCRIPTION",
    "score": "im.ENSEMBLE_SCORE",
    "match_score": """GREATEST(
        COALESCE(im.CORTEX_SEARCH_SCORE, 0),
        COALESCE(im.COSINE_SCORE, 0),
        COALESCE(im.EDIT_DISTANCE_SCORE, 0),
        COALESCE(im.JACCARD_SCORE, 0)
    )""",
    "ensemble_score": "im.ENSEMBLE_SCORE",
    "match_source": """CASE
        WHEN COALESCE(im.CORTEX_SEARCH_SCORE, 0) >= COALESCE(im.COSINE_SCORE, 0)
             AND COALESCE(im.CORTEX_SEARCH_SCORE, 0) >= COALESCE(im.EDIT_DISTANCE_SCORE, 0)
             AND COALESCE(im.CORTEX_SEARCH_SCORE, 0) >= COALESCE(im.JACCARD_SCORE, 0)
        THEN 'SEARCH'
        WHEN COALESCE(im.COSINE_SCORE, 0) >= COALESCE(im.CORTEX_SEARCH_SCORE, 0)
             AND COALESCE(im.COSINE_SCORE, 0) >= COALESCE(im.EDIT_DISTANCE_SCORE, 0)
             AND COALESCE(im.COSINE_SCORE, 0) >= COALESCE(im.JACCARD_SCORE, 0)
        THEN 'COSINE'
        WHEN COALESCE(im.EDIT_DISTANCE_SCORE, 0) >= COALESCE(im.CORTEX_SEARCH_SCORE, 0)
             AND COALESCE(im.EDIT_DISTANCE_SCORE, 0) >= COALESCE(im.COSINE_SCORE, 0)
             AND COALESCE(im.EDIT_DISTANCE_SCORE, 0) >= COALESCE(im.JACCARD_SCORE, 0)
        THEN 'EDIT'
        ELSE 'JACCARD'
    END""",
    "boost": """CASE
        WHEN im.SEARCH_MATCHED_ID = im.COSINE_MATCHED_ID
             AND im.COSINE_MATCHED_ID = im.EDIT_DISTANCE_MATCHED_ID
             AND im.EDIT_DISTANCE_MATCHED_ID = im.JACCARD_MATCHED_ID
             AND im.SEARCH_MATCHED_ID IS NOT NULL
        THEN 4
        WHEN (im.SEARCH_MATCHED_ID = im.COSINE_MATCHED_ID AND im.COSINE_MATCHED_ID = im.EDIT_DISTANCE_MATCHED_ID AND im.SEARCH_MATCHED_ID IS NOT NULL)
          OR (im.SEARCH_MATCHED_ID = im.COSINE_MATCHED_ID AND im.COSINE_MATCHED_ID = im.JACCARD_MATCHED_ID AND im.SEARCH_MATCHED_ID IS NOT NULL)
          OR (im.SEARCH_MATCHED_ID = im.EDIT_DISTANCE_MATCHED_ID AND im.EDIT_DISTANCE_MATCHED_ID = im.JACCARD_MATCHED_ID AND im.SEARCH_MATCHED_ID IS NOT NULL)
          OR (im.COSINE_MATCHED_ID = im.EDIT_DISTANCE_MATCHED_ID AND im.EDIT_DISTANCE_MATCHED_ID = im.JACCARD_MATCHED_ID AND im.COSINE_MATCHED_ID IS NOT NULL)
        THEN 3
        WHEN (im.SEARCH_MATCHED_ID = im.COSINE_MATCHED_ID AND im.SEARCH_MATCHED_ID IS NOT NULL)
          OR (im.SEARCH_MATCHED_ID = im.EDIT_DISTANCE_MATCHED_ID AND im.SEARCH_MATCHED_ID IS NOT NULL)
          OR (im.SEARCH_MATCHED_ID = im.JACCARD_MATCHED_ID AND im.SEARCH_MATCHED_ID IS NOT NULL)
          OR (im.COSINE_MATCHED_ID = im.EDIT_DISTANCE_MATCHED_ID AND im.COSINE_MATCHED_ID IS NOT NULL)
          OR (im.COSINE_MATCHED_ID = im.JACCARD_MATCHED_ID AND im.COSINE_MATCHED_ID IS NOT NULL)
          OR (im.EDIT_DISTANCE_MATCHED_ID = im.JACCARD_MATCHED_ID AND im.EDIT_DISTANCE_MATCHED_ID IS NOT NULL)
        THEN 2
        ELSE 1
    END""",
}

# CTE-compatible column mapping (without table aliases, for outer query on CTE)
_SORT_COLUMNS_CTE = {
    "pos_item": "RAW_DESCRIPTION",
    "source": "SOURCE_SYSTEM",
    "category": "INFERRED_CATEGORY",
    "matched": "STANDARD_DESCRIPTION",
    "score": "ENSEMBLE_SCORE",
    "match_score": "MAX_RAW_SCORE",
    "ensemble_score": "ENSEMBLE_SCORE",
    "match_source": "PRIMARY_MATCH_SOURCE",
    "boost": "AGREEMENT_LEVEL",
}


@dataclass
class ReviewResult:
    """Result container for paginated review items.

    Attributes:
        items: List of match items with scores and metadata.
        total_items: Total matching items across all pages.
        total_pages: Number of pages based on page_size.
        page: Current page number (1-indexed).
        page_size: Items per page.
        auto_refresh_enabled: Whether UI auto-refresh is enabled in config.
    """

    items: list[dict[str, Any]]
    total_items: int
    total_pages: int
    page: int
    page_size: int
    auto_refresh_enabled: bool


@dataclass
class SubmitReviewResult:
    """Result of a single review submission.

    Attributes:
        success: Whether the review action succeeded.
        used_fallback: Whether fallback SQL was used instead of stored procedure.
            Fallback occurs when SUBMIT_REVIEW procedure fails or is unavailable.
        propagated: Number of related items updated (items with same normalized description).
    """

    success: bool
    used_fallback: bool
    propagated: int


@dataclass
class ReviewService(BaseService):
    """Service for match review queue operations.

    Handles paginated review queue retrieval, single/bulk review actions,
    and filter option lookups. Routes remain responsible for HTML generation.

    Attributes:
        PAGE_SIZE: Number of items per page for pagination (default: 25).
        db_name: Inherited from BaseService - database name for fully qualified queries.
        sf: Inherited from BaseService - Snowflake client for query execution.
        cache: Inherited from BaseService - optional TTL cache for query results.

    Side Effects:
        - Executes SELECT queries against RAW.RAW_RETAIL_ITEMS, HARMONIZED.ITEM_MATCHES,
          RAW.STANDARD_ITEMS, and ANALYTICS.CONFIG tables
        - Executes UPDATE on RAW.RAW_RETAIL_ITEMS for review submissions
        - Inserts records into ANALYTICS.MATCH_AUDIT_LOG for audit trail
        - Calls stored procedures: SUBMIT_REVIEW, RELEASE_LOCK

    Thread Safety:
        Not thread-safe. Each request should use its own service instance
        via FastAPI dependency injection.
    """

    PAGE_SIZE: int = 25

    def _build_status_filter(self, status: str) -> str:
        """Build the effective status WHERE clause."""
        return f"""(
            CASE
                WHEN ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'CONFIRMED', 'REJECTED') THEN ri.MATCH_STATUS
                ELSE COALESCE(im.STATUS, ri.MATCH_STATUS)
            END = '{self._safe(status)}'
            OR ('{self._safe(status)}' = 'CONFIRMED' AND COALESCE(im.STATUS, ri.MATCH_STATUS) = 'USER_CONFIRMED')
        )"""

    def _build_match_source_filter(self, match_source: str) -> str:
        """Build the primary match source WHERE clause."""
        return f"""(
            CASE
                WHEN COALESCE(im.CORTEX_SEARCH_SCORE, 0) >= COALESCE(im.COSINE_SCORE, 0)
                     AND COALESCE(im.CORTEX_SEARCH_SCORE, 0) >= COALESCE(im.EDIT_DISTANCE_SCORE, 0)
                     AND COALESCE(im.CORTEX_SEARCH_SCORE, 0) >= COALESCE(im.JACCARD_SCORE, 0)
                THEN 'SEARCH'
                WHEN COALESCE(im.COSINE_SCORE, 0) >= COALESCE(im.CORTEX_SEARCH_SCORE, 0)
                     AND COALESCE(im.COSINE_SCORE, 0) >= COALESCE(im.EDIT_DISTANCE_SCORE, 0)
                     AND COALESCE(im.COSINE_SCORE, 0) >= COALESCE(im.JACCARD_SCORE, 0)
                THEN 'COSINE'
                WHEN COALESCE(im.EDIT_DISTANCE_SCORE, 0) >= COALESCE(im.CORTEX_SEARCH_SCORE, 0)
                     AND COALESCE(im.EDIT_DISTANCE_SCORE, 0) >= COALESCE(im.COSINE_SCORE, 0)
                     AND COALESCE(im.EDIT_DISTANCE_SCORE, 0) >= COALESCE(im.JACCARD_SCORE, 0)
                THEN 'EDIT'
                ELSE 'JACCARD'
            END = '{self._safe(match_source)}'
        )"""

    def _build_review_where(
        self,
        *,
        status: str,
        source: str,
        category: str,
        match_source: str,
        boost_level: str,
    ) -> str:
        """Build combined WHERE clause for the review queue."""
        where = ["1=1"]
        if status != "All":
            where.append(self._build_status_filter(status))
        if source != "All":
            where.append(f"ri.SOURCE_SYSTEM = '{self._safe(source)}'")
        if category != "All":
            where.append(f"ri.INFERRED_CATEGORY = '{self._safe(category)}'")
        if match_source != "All":
            where.append(self._build_match_source_filter(match_source))
        if boost_level != "All":
            boost_val = int(boost_level) if boost_level.isdigit() else 1
            where.append(f"AGREEMENT_LEVEL = {boost_val}")
        return " AND ".join(where)

    def _build_order_clause(
        self,
        sort_col: str,
        sort_dir: str,
        sort: str,
        *,
        use_cte: bool = False,
    ) -> str:
        """Build ORDER BY clause from column sort or dropdown sort.

        Args:
            sort_col: Column key for header-based sorting.
            sort_dir: Direction ('asc' or 'desc').
            sort: Dropdown sort key fallback.
            use_cte: If True, use CTE-compatible column names (no aliases).
        """
        columns = _SORT_COLUMNS_CTE if use_cte else _SORT_COLUMNS
        if sort_col in columns:
            direction = "DESC" if sort_dir == "desc" else "ASC"
            nulls = "NULLS LAST" if sort_dir == "desc" else "NULLS FIRST"
            return f"{columns[sort_col]} {direction} {nulls}"

        if use_cte:
            order_map = {
                "confidence_asc": "ENSEMBLE_SCORE ASC NULLS FIRST",
                "confidence_desc": "ENSEMBLE_SCORE DESC NULLS LAST",
                "source": "SOURCE_SYSTEM ASC, ENSEMBLE_SCORE DESC",
                "category": "INFERRED_CATEGORY ASC, ENSEMBLE_SCORE DESC",
            }
        else:
            order_map = {
                "confidence_asc": "im.ENSEMBLE_SCORE ASC NULLS FIRST",
                "confidence_desc": "im.ENSEMBLE_SCORE DESC NULLS LAST",
                "source": "ri.SOURCE_SYSTEM ASC, im.ENSEMBLE_SCORE DESC",
                "category": "ri.INFERRED_CATEGORY ASC, im.ENSEMBLE_SCORE DESC",
            }
        return order_map.get(sort, order_map["confidence_asc"])

    async def get_review_items(
        self,
        *,
        status: str = "PENDING_REVIEW",
        source: str = "All",
        category: str = "All",
        match_source: str = "All",
        boost_level: str = "All",
        sort: str = "confidence_desc",
        page: int = 1,
        sort_col: str = "ensemble_score",
        sort_dir: str = "desc",
        group_by: str = "unique_description",
    ) -> ReviewResult:
        """Get paginated review queue items with filters and sorting.

        Args:
            status: Filter by effective match status.
            source: Filter by source system.
            category: Filter by inferred category.
            match_source: Filter by primary match source.
            boost_level: Filter by agreement level.
            sort: Dropdown sort key.
            page: Page number (1-based).
            sort_col: Column key for header sorting.
            sort_dir: Sort direction ('asc' or 'desc').
            group_by: Grouping mode ('unique_description' or 'none').

        Returns:
            ReviewResult with items and pagination metadata.
        """
        db = self.db_name
        where_sql = self._build_review_where(
            status=status,
            source=source,
            category=category,
            match_source=match_source,
            boost_level=boost_level,
        )
        offset = (page - 1) * self.PAGE_SIZE

        # Get total count
        if group_by == "unique_description":
            count_result = await self.sf.query(f"""
                SELECT COUNT(DISTINCT UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\\\s+', ' ')))) AS total
                FROM {db}.RAW.RAW_RETAIL_ITEMS ri
                LEFT JOIN {db}.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
                WHERE {where_sql}
            """)
        else:
            count_result = await self.sf.query(f"""
                SELECT COUNT(*) AS total
                FROM {db}.RAW.RAW_RETAIL_ITEMS ri
                LEFT JOIN {db}.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
                WHERE {where_sql}
            """)

        total_items = int(count_result[0].get("TOTAL", 0) if count_result else 0)
        total_pages = max(1, (total_items + self.PAGE_SIZE - 1) // self.PAGE_SIZE)
        page = min(page, total_pages)
        offset = (page - 1) * self.PAGE_SIZE

        # Get auto-refresh config
        config_result = await self.sf.query(
            f"SELECT CONFIG_KEY, CONFIG_VALUE FROM {db}.ANALYTICS.CONFIG"
            " WHERE CONFIG_KEY = 'DASHBOARD_AUTO_REFRESH' AND IS_ACTIVE = TRUE"
        )
        config = {row.get("CONFIG_KEY", ""): row.get("CONFIG_VALUE", "") for row in config_result}
        auto_refresh_enabled = config.get("DASHBOARD_AUTO_REFRESH", "off").lower() == "on"

        # Fetch items
        if group_by == "unique_description":
            order_cte = self._build_order_clause(sort_col, sort_dir, sort, use_cte=True)
            # Use the same sort column for ROW_NUMBER to pick the "best" row per group
            # based on the user's requested sort, not hardcoded ENSEMBLE_SCORE
            inner_order = self._build_order_clause(sort_col, sort_dir, sort, use_cte=False)
            items = await self.sf.query(f"""
                WITH ranked_items AS (
                    SELECT
                        {_BASE_SELECT},
                        UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\\\s+', ' '))) AS NORMALIZED_DESCRIPTION,
                        ROW_NUMBER() OVER (
                            PARTITION BY UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\\\s+', ' ')))
                            ORDER BY {inner_order}
                        ) AS rn
                    FROM {db}.RAW.RAW_RETAIL_ITEMS ri
                    LEFT JOIN {db}.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
                    LEFT JOIN {db}.RAW.STANDARD_ITEMS si ON im.SUGGESTED_STANDARD_ID = si.STANDARD_ITEM_ID
                    WHERE {where_sql}
                )
                SELECT *
                FROM ranked_items
                WHERE rn = 1
                ORDER BY {order_cte}
                LIMIT {self.PAGE_SIZE}
                OFFSET {offset}
            """)
        else:
            order = self._build_order_clause(sort_col, sort_dir, sort)
            items = await self.sf.query(f"""
                SELECT
                    {_BASE_SELECT}
                FROM {db}.RAW.RAW_RETAIL_ITEMS ri
                LEFT JOIN {db}.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
                LEFT JOIN {db}.RAW.STANDARD_ITEMS si ON im.SUGGESTED_STANDARD_ID = si.STANDARD_ITEM_ID
                WHERE {where_sql}
                ORDER BY {order}
                LIMIT {self.PAGE_SIZE}
                OFFSET {offset}
            """)

        return ReviewResult(
            items=items,
            total_items=total_items,
            total_pages=total_pages,
            page=page,
            page_size=self.PAGE_SIZE,
            auto_refresh_enabled=auto_refresh_enabled,
        )

    async def submit_review(
        self,
        *,
        item_id: str,
        matched_id: str,
        match_id: str,
        action: str,
    ) -> SubmitReviewResult:
        """Submit a single review action (confirm/reject/skip).

        Args:
            item_id: Raw retail item ID.
            matched_id: Matched standard item ID.
            match_id: Match record ID.
            action: Review action ('CONFIRMED', 'REJECTED', or 'SKIP').

        Returns:
            SubmitReviewResult with success status and propagation count.
        """
        db = self.db_name

        if action == "SKIP":
            with suppress(Exception):
                await self.sf.execute(f"CALL {db}.HARMONIZED.RELEASE_LOCK('{self._safe(item_id)}', CURRENT_USER())")
            return SubmitReviewResult(success=True, used_fallback=False, propagated=0)

        if action not in ("CONFIRMED", "REJECTED"):
            return SubmitReviewResult(success=False, used_fallback=False, propagated=0)

        proc_action = "CONFIRM" if action == "CONFIRMED" else "REJECT"
        use_fallback = False
        propagated = 0

        if not match_id or match_id.strip() == "":
            use_fallback = True
        else:
            try:
                result = await self.sf.query(f"""
                    CALL {db}.HARMONIZED.SUBMIT_REVIEW(
                        '{self._safe(match_id)}', '{self._safe(proc_action)}', NULL,
                        CURRENT_USER(), '{self._safe(proc_action)}', NULL
                    )
                """)
                if result and len(result) > 0:
                    try:
                        proc_response = json.loads(result[0].get("SUBMIT_REVIEW", "{}"))
                        propagated = proc_response.get("propagated_items", 0)
                    except (json.JSONDecodeError, KeyError, TypeError):
                        propagated = 0
            except Exception:
                use_fallback = True

        if use_fallback:
            await self.sf.execute(f"""
                UPDATE {db}.RAW.RAW_RETAIL_ITEMS
                SET MATCH_STATUS = '{self._safe(action)}',
                    MATCHED_STANDARD_ID = '{self._safe(matched_id)}',
                    UPDATED_AT = CURRENT_TIMESTAMP()
                WHERE ITEM_ID = '{self._safe(item_id)}'
            """)
            await self.sf.execute(f"""
                INSERT INTO {db}.ANALYTICS.MATCH_AUDIT_LOG
                    (AUDIT_ID, MATCH_ID, ACTION, OLD_STATUS, NEW_STATUS, REVIEWED_BY, CREATED_AT)
                SELECT
                    UUID_STRING(), '{self._safe(item_id)}', 'STATUS_CHANGE', NULL, '{self._safe(action)}',
                     CURRENT_USER(), CURRENT_TIMESTAMP()
            """)

        # Release lock
        with suppress(Exception):
            await self.sf.execute(f"CALL {db}.HARMONIZED.RELEASE_LOCK('{self._safe(item_id)}', CURRENT_USER())")

        return SubmitReviewResult(
            success=True,
            used_fallback=use_fallback,
            propagated=propagated,
        )

    async def bulk_submit_review(
        self,
        items: list[dict[str, str]],
    ) -> dict[str, Any]:
        """Process multiple review actions in a single stored procedure call.

        Args:
            items: List of dicts with 'match_id' and 'action' keys.
                   Actions should be 'CONFIRMED' or 'REJECTED'.

        Returns:
            Response dict from BULK_SUBMIT_REVIEW procedure.
        """
        db = self.db_name

        if not items:
            return {"status": "error", "message": "No items provided"}

        items_array = []
        for item in items:
            proc_action = "CONFIRM" if item["action"] == "CONFIRMED" else "REJECT"
            items_array.append({"match_id": item["match_id"], "action": proc_action})

        items_json = json.dumps(items_array).replace("'", "''")

        try:
            result = await self.sf.query(f"""
                CALL {db}.HARMONIZED.BULK_SUBMIT_REVIEW(
                    PARSE_JSON('{items_json}'),
                    CURRENT_USER(),
                    NULL
                )
            """)

            if result and len(result) > 0:
                response_data = result[0].get("BULK_SUBMIT_REVIEW")
                if isinstance(response_data, str):
                    return json.loads(response_data)
                if isinstance(response_data, dict):
                    return response_data
            return {"status": "success", "message": "Bulk action completed"}
        except Exception as exc:
            logger.error(f"Bulk review action failed: {exc}")
            return {"status": "error", "message": str(exc)}

    async def get_filter_options(self) -> dict[str, list[str]]:
        """Get distinct sources and categories for filter dropdowns.

        Returns:
            Dict with 'sources' and 'categories' lists.
        """
        db = self.db_name

        sources = await self.sf.query(f"SELECT DISTINCT SOURCE_SYSTEM FROM {db}.RAW.RAW_RETAIL_ITEMS ORDER BY 1")
        categories = await self.sf.query(f"""
            SELECT DISTINCT INFERRED_CATEGORY
            FROM {db}.RAW.RAW_RETAIL_ITEMS
            WHERE INFERRED_CATEGORY IS NOT NULL ORDER BY 1
        """)

        return {
            "sources": [r.get("SOURCE_SYSTEM", "") for r in sources],
            "categories": [r.get("INFERRED_CATEGORY", "") for r in categories],
        }
