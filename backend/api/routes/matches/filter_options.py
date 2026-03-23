"""Match filter options endpoint.

Provides dropdown filter values for the React review page. Queries distinct
source systems and categories from Snowflake and returns static match source
and grouping options.

Endpoints:
    GET /filter-options: Available filter values for search dropdowns.
"""

from __future__ import annotations

from fastapi import APIRouter

from backend.api import snowflake_client as sf
from backend.api.schemas.matches import FilterOptionsResponse

router = APIRouter(tags=["matches"])


@router.get("/filter-options", response_model=FilterOptionsResponse)
async def get_filter_options():
    """Get filter options for the React review page dropdowns.

    Queries distinct SOURCE_SYSTEM, INFERRED_CATEGORY, and INFERRED_SUBCATEGORY
    values from RAW_RETAIL_ITEMS, and returns static lists for match sources,
    agreement levels, and group-by options.
    """
    db = sf.get_database()

    try:
        sources = await sf.query(f"""
            SELECT DISTINCT SOURCE_SYSTEM
            FROM {db}.RAW.RAW_RETAIL_ITEMS
            WHERE SOURCE_SYSTEM IS NOT NULL
            ORDER BY 1
        """)

        categories = await sf.query(f"""
            SELECT DISTINCT INFERRED_CATEGORY
            FROM {db}.RAW.RAW_RETAIL_ITEMS
            WHERE INFERRED_CATEGORY IS NOT NULL
            ORDER BY 1
        """)

        subcategories = await sf.query(f"""
            SELECT DISTINCT INFERRED_CATEGORY, INFERRED_SUBCATEGORY
            FROM {db}.RAW.RAW_RETAIL_ITEMS
            WHERE INFERRED_CATEGORY IS NOT NULL
              AND INFERRED_SUBCATEGORY IS NOT NULL
            ORDER BY 1, 2
        """)

        subcategories_by_category: dict[str, list[str]] = {}
        for row in subcategories:
            cat = row.get("INFERRED_CATEGORY", "")
            subcat = row.get("INFERRED_SUBCATEGORY", "")
            if cat and subcat:
                if cat not in subcategories_by_category:
                    subcategories_by_category[cat] = []
                subcategories_by_category[cat].append(subcat)

        return {
            "sources": [r.get("SOURCE_SYSTEM", "") for r in sources if r.get("SOURCE_SYSTEM")],
            "categories": [r.get("INFERRED_CATEGORY", "") for r in categories if r.get("INFERRED_CATEGORY")],
            "subcategoriesByCategory": subcategories_by_category,
            "matchSources": ["SEARCH", "COSINE", "EDIT", "JACCARD"],
            "agreementLevels": [
                {"value": "1", "label": "1-way (Single)"},
                {"value": "2", "label": "2-way: 10%"},
                {"value": "3", "label": "3-way: 15%"},
                {"value": "4", "label": "4-way: 20%"},
            ],
            "groupByOptions": [
                {"value": "none", "label": "None (Flat List)"},
                {"value": "unique_description", "label": "Unique Description (Deduplicated)"},
                {"value": "source_system", "label": "Source System"},
                {"value": "category", "label": "Category"},
                {"value": "match_source", "label": "Match Source"},
                {"value": "agreement", "label": "Agreement"},
            ],
        }
    except Exception as e:
        return {
            "sources": [],
            "categories": [],
            "subcategoriesByCategory": {},
            "matchSources": [],
            "agreementLevels": [],
            "groupByOptions": [],
            "error": str(e),
        }
