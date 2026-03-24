"""Match search endpoint for the React frontend.

Provides paginated match search with filtering by status, source, category,
and match source. Supports grouping by unique description to deduplicate
variant items and returns comprehensive scoring data for each match.

Endpoints:
    POST /search: Paginated match search with multi-column filtering and sorting.
"""

from __future__ import annotations

from fastapi import APIRouter

from backend.api import snowflake_client as sf
from backend.api.schemas.matches import MatchSearchRequest, MatchSearchResponse

router = APIRouter(tags=["matches"])

# Build boost labels
BOOST_LABELS = {4: "4-way (+20%)", 3: "3-way (+15%)", 2: "2-way (+10%)", 1: "No Boost"}
BOOST_PERCENTS = {4: 20, 3: 15, 2: 10, 1: 0}


def _safe(value: str) -> str:
    """Escape single-quotes for safe SQL interpolation."""
    return value.replace("'", "''")


@router.post("/search", response_model=MatchSearchResponse)
async def search_matches(body: MatchSearchRequest):
    """Search matches with filters for the React frontend.

    Returns comprehensive match data including all individual algorithm scores,
    agreement levels, boost metadata, and duplicate counts. Supports grouping
    by unique normalized description to deduplicate variant items.

    Side Effects:
        Executes SELECT queries against RAW.RAW_RETAIL_ITEMS,
        HARMONIZED.ITEM_MATCHES, and RAW.STANDARD_ITEMS.
    """
    db = sf.get_database()

    page = body.page
    page_size = body.pageSize
    status_filter = body.status
    source_filter = body.source
    category_filter = body.category
    subcategory_filter = body.subcategory
    match_source_filter = body.matchSource
    agreement_filter = body.agreement
    sort_col = body.sortBy
    sort_dir = body.sortOrder
    group_by = body.groupBy

    offset = (page - 1) * page_size

    # Build WHERE clauses (using _safe() to escape user input)
    where_clauses = ["1=1"]
    if status_filter and status_filter not in ("all", "All"):
        safe_status = _safe(status_filter)
        where_clauses.append(f"""(
            CASE
                WHEN ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'CONFIRMED', 'REJECTED') THEN ri.MATCH_STATUS
                ELSE COALESCE(im.STATUS, ri.MATCH_STATUS)
            END = '{safe_status}'
            OR ('{safe_status}' = 'CONFIRMED' AND COALESCE(im.STATUS, ri.MATCH_STATUS) = 'USER_CONFIRMED')
        )""")
    if source_filter and source_filter not in ("all", "All"):
        where_clauses.append(f"ri.SOURCE_SYSTEM = '{_safe(source_filter)}'")
    if category_filter and category_filter not in ("all", "All"):
        where_clauses.append(f"ri.INFERRED_CATEGORY = '{_safe(category_filter)}'")
    if subcategory_filter and subcategory_filter not in ("all", "All"):
        where_clauses.append(f"ri.INFERRED_SUBCATEGORY = '{_safe(subcategory_filter)}'")
    if match_source_filter and match_source_filter not in ("all", "All"):
        where_clauses.append(f"""(
            CASE
                WHEN COALESCE(im.CORTEX_SEARCH_SCORE, 0) >= GREATEST(COALESCE(im.COSINE_SCORE, 0), COALESCE(im.EDIT_DISTANCE_SCORE, 0), COALESCE(im.JACCARD_SCORE, 0)) THEN 'SEARCH'
                WHEN COALESCE(im.COSINE_SCORE, 0) >= GREATEST(COALESCE(im.CORTEX_SEARCH_SCORE, 0), COALESCE(im.EDIT_DISTANCE_SCORE, 0), COALESCE(im.JACCARD_SCORE, 0)) THEN 'COSINE'
                WHEN COALESCE(im.EDIT_DISTANCE_SCORE, 0) >= GREATEST(COALESCE(im.CORTEX_SEARCH_SCORE, 0), COALESCE(im.COSINE_SCORE, 0), COALESCE(im.JACCARD_SCORE, 0)) THEN 'EDIT'
                ELSE 'JACCARD'
            END = '{_safe(match_source_filter)}'
        )""")

    where_sql = " AND ".join(where_clauses)

    # Sort column mapping
    sort_columns = {
        "pos_item": "RAW_DESCRIPTION",
        "rawName": "RAW_DESCRIPTION",
        "source": "SOURCE_SYSTEM",
        "category": "INFERRED_CATEGORY",
        "matched": "STANDARD_DESCRIPTION",
        "matchedName": "STANDARD_DESCRIPTION",
        "match_score": "MAX_RAW_SCORE",
        "maxRawScore": "MAX_RAW_SCORE",
        "ensemble_score": "ENSEMBLE_SCORE",
        "ensembleScore": "ENSEMBLE_SCORE",
        "score": "ENSEMBLE_SCORE",
        "match_source": "PRIMARY_MATCH_SOURCE",
        "matchSource": "PRIMARY_MATCH_SOURCE",
        "boost": "AGREEMENT_LEVEL",
        "boostLevel": "AGREEMENT_LEVEL",
        "agreementLevel": "AGREEMENT_LEVEL",
    }
    order_col = sort_columns.get(sort_col, "ENSEMBLE_SCORE")
    order_dir = "DESC" if sort_dir == "desc" else "ASC"
    nulls = "NULLS LAST" if sort_dir == "desc" else "NULLS FIRST"

    try:
        agreement_count_filter = (
            f" AND AGREEMENT_LEVEL = {int(agreement_filter)}"
            if agreement_filter and agreement_filter not in ("all", "All")
            else ""
        )

        # Get total count
        if group_by == "unique_description":
            count_result = await sf.query(f"""
                WITH filtered_data AS (
                    SELECT
                        UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\\\s+', ' '))) AS NORMALIZED_DESCRIPTION,
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
                        END AS AGREEMENT_LEVEL
                    FROM {db}.RAW.RAW_RETAIL_ITEMS ri
                    LEFT JOIN {db}.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
                    WHERE {where_sql}
                )
                SELECT COUNT(DISTINCT NORMALIZED_DESCRIPTION) AS TOTAL
                FROM filtered_data
                WHERE 1=1{agreement_count_filter}
            """)
        else:
            count_result = await sf.query(f"""
                WITH filtered_data AS (
                    SELECT
                        ri.ITEM_ID,
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
                        END AS AGREEMENT_LEVEL
                    FROM {db}.RAW.RAW_RETAIL_ITEMS ri
                    LEFT JOIN {db}.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
                    WHERE {where_sql}
                )
                SELECT COUNT(*) AS TOTAL
                FROM filtered_data
                WHERE 1=1{agreement_count_filter}
            """)
        total = int(count_result[0].get("TOTAL", 0)) if count_result else 0
        total_pages = max(1, (total + page_size - 1) // page_size)
        page = min(page, total_pages)
        offset = (page - 1) * page_size

        # Get matches with full details
        if group_by == "unique_description":
            matches = await sf.query(f"""
                WITH ranked_items AS (
                    SELECT
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
                        si.STANDARD_DESCRIPTION,
                        si.SRP,
                        si.BRAND,
                        CASE
                            WHEN ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'CONFIRMED', 'REJECTED') THEN ri.MATCH_STATUS
                            WHEN COALESCE(im.STATUS, ri.MATCH_STATUS) = 'USER_CONFIRMED' THEN 'CONFIRMED'
                            ELSE COALESCE(im.STATUS, ri.MATCH_STATUS)
                        END AS EFFECTIVE_STATUS,
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
                        END AS AGREEMENT_LEVEL,
                        CASE
                            WHEN COALESCE(im.CORTEX_SEARCH_SCORE, 0) >= GREATEST(COALESCE(im.COSINE_SCORE, 0), COALESCE(im.EDIT_DISTANCE_SCORE, 0), COALESCE(im.JACCARD_SCORE, 0)) THEN 'SEARCH'
                            WHEN COALESCE(im.COSINE_SCORE, 0) >= GREATEST(COALESCE(im.CORTEX_SEARCH_SCORE, 0), COALESCE(im.EDIT_DISTANCE_SCORE, 0), COALESCE(im.JACCARD_SCORE, 0)) THEN 'COSINE'
                            WHEN COALESCE(im.EDIT_DISTANCE_SCORE, 0) >= GREATEST(COALESCE(im.CORTEX_SEARCH_SCORE, 0), COALESCE(im.COSINE_SCORE, 0), COALESCE(im.JACCARD_SCORE, 0)) THEN 'EDIT'
                            ELSE 'JACCARD'
                        END AS PRIMARY_MATCH_SOURCE,
                        GREATEST(
                            COALESCE(im.CORTEX_SEARCH_SCORE, 0),
                            COALESCE(im.COSINE_SCORE, 0),
                            COALESCE(im.EDIT_DISTANCE_SCORE, 0),
                            COALESCE(im.JACCARD_SCORE, 0)
                        ) AS MAX_RAW_SCORE,
                        COUNT(*) OVER (PARTITION BY UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\\\s+', ' ')))) AS DUPLICATE_COUNT,
                        UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\\\s+', ' '))) AS NORMALIZED_DESCRIPTION,
                        ROW_NUMBER() OVER (
                            PARTITION BY UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\\\s+', ' ')))
                            ORDER BY im.ENSEMBLE_SCORE DESC NULLS LAST
                        ) AS rn
                    FROM {db}.RAW.RAW_RETAIL_ITEMS ri
                    LEFT JOIN {db}.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
                    LEFT JOIN {db}.RAW.STANDARD_ITEMS si ON im.SUGGESTED_STANDARD_ID = si.STANDARD_ITEM_ID
                    WHERE {where_sql}
                )
                SELECT *
                FROM ranked_items
                WHERE rn = 1{f" AND AGREEMENT_LEVEL = {int(agreement_filter)}" if agreement_filter and agreement_filter not in ("all", "All") else ""}
                ORDER BY {order_col} {order_dir} {nulls}
                LIMIT {page_size} OFFSET {offset}
            """)
        else:
            agreement_filter_sql = (
                f" WHERE AGREEMENT_LEVEL = {int(agreement_filter)}"
                if agreement_filter and agreement_filter not in ("all", "All")
                else ""
            )
            matches = await sf.query(f"""
                WITH base_data AS (
                    SELECT
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
                        si.STANDARD_DESCRIPTION,
                        si.SRP,
                        si.BRAND,
                        CASE
                            WHEN ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'CONFIRMED', 'REJECTED') THEN ri.MATCH_STATUS
                            WHEN COALESCE(im.STATUS, ri.MATCH_STATUS) = 'USER_CONFIRMED' THEN 'CONFIRMED'
                            ELSE COALESCE(im.STATUS, ri.MATCH_STATUS)
                        END AS EFFECTIVE_STATUS,
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
                        END AS AGREEMENT_LEVEL,
                        CASE
                            WHEN COALESCE(im.CORTEX_SEARCH_SCORE, 0) >= GREATEST(COALESCE(im.COSINE_SCORE, 0), COALESCE(im.EDIT_DISTANCE_SCORE, 0), COALESCE(im.JACCARD_SCORE, 0)) THEN 'SEARCH'
                            WHEN COALESCE(im.COSINE_SCORE, 0) >= GREATEST(COALESCE(im.CORTEX_SEARCH_SCORE, 0), COALESCE(im.EDIT_DISTANCE_SCORE, 0), COALESCE(im.JACCARD_SCORE, 0)) THEN 'COSINE'
                            WHEN COALESCE(im.EDIT_DISTANCE_SCORE, 0) >= GREATEST(COALESCE(im.CORTEX_SEARCH_SCORE, 0), COALESCE(im.COSINE_SCORE, 0), COALESCE(im.JACCARD_SCORE, 0)) THEN 'EDIT'
                            ELSE 'JACCARD'
                        END AS PRIMARY_MATCH_SOURCE,
                        GREATEST(
                            COALESCE(im.CORTEX_SEARCH_SCORE, 0),
                            COALESCE(im.COSINE_SCORE, 0),
                            COALESCE(im.EDIT_DISTANCE_SCORE, 0),
                            COALESCE(im.JACCARD_SCORE, 0)
                        ) AS MAX_RAW_SCORE,
                        COUNT(*) OVER (PARTITION BY UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\\\s+', ' ')))) AS DUPLICATE_COUNT
                    FROM {db}.RAW.RAW_RETAIL_ITEMS ri
                    LEFT JOIN {db}.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
                    LEFT JOIN {db}.RAW.STANDARD_ITEMS si ON im.SUGGESTED_STANDARD_ID = si.STANDARD_ITEM_ID
                    WHERE {where_sql}
                )
                SELECT * FROM base_data{agreement_filter_sql}
                ORDER BY {order_col} {order_dir} {nulls}
                LIMIT {page_size} OFFSET {offset}
            """)
    except Exception as e:
        return {"items": [], "total": 0, "page": page, "pageSize": page_size, "totalPages": 0, "error": str(e)}

    items = []
    for m in matches:
        agreement = int(m.get("AGREEMENT_LEVEL", 1) or 1)
        items.append(
            {
                "id": str(m.get("MATCH_ID") or m.get("ITEM_ID", "")),
                "itemId": str(m.get("ITEM_ID", "")),
                "matchId": str(m.get("MATCH_ID", "") or ""),
                "rawName": m.get("RAW_DESCRIPTION", "") or "",
                "matchedName": m.get("STANDARD_DESCRIPTION", "") or "",
                "standardItemId": m.get("SUGGESTED_STANDARD_ID", "") or "",
                "status": m.get("EFFECTIVE_STATUS", m.get("MATCH_STATUS", "")) or "",
                "source": m.get("SOURCE_SYSTEM", "") or "",
                "category": m.get("INFERRED_CATEGORY", "") or "",
                "subcategory": m.get("INFERRED_SUBCATEGORY", "") or "",
                "brand": m.get("BRAND", "") or "",
                "price": float(m.get("SRP", 0) or 0),
                # Individual scores
                "searchScore": float(m.get("CORTEX_SEARCH_SCORE", 0) or 0),
                "cosineScore": float(m.get("COSINE_SCORE", 0) or 0),
                "editScore": float(m.get("EDIT_DISTANCE_SCORE", 0) or 0),
                "jaccardScore": float(m.get("JACCARD_SCORE", 0) or 0),
                "ensembleScore": float(m.get("ENSEMBLE_SCORE", 0) or 0),
                "maxRawScore": float(m.get("MAX_RAW_SCORE", 0) or 0),
                # Legacy field for backward compatibility
                "score": float(m.get("ENSEMBLE_SCORE", 0) or 0),
                # Match metadata
                "matchSource": m.get("PRIMARY_MATCH_SOURCE", "") or "",
                "matchMethod": m.get("MATCH_METHOD", "") or "",
                "agreementLevel": agreement,
                "boostLevel": BOOST_LABELS.get(agreement, "No Boost"),
                "boostPercent": BOOST_PERCENTS.get(agreement, 0),
                "duplicateCount": int(m.get("DUPLICATE_COUNT", 1) or 1),
                "createdAt": "",
            }
        )

    return {
        "items": items,
        "total": total,
        "page": page,
        "pageSize": page_size,
        "totalPages": total_pages,
    }
