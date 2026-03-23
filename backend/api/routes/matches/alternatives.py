"""Match alternatives endpoint.

Provides alternative match candidates for manual re-matching. First checks
cached candidates from MATCH_CANDIDATES, then falls back to live Cortex Search.

Endpoints:
    GET /{item_id}/alternatives: Retrieve up to 10 alternative standard items.
"""

from __future__ import annotations

import json as json_mod

from fastapi import APIRouter

from backend.api import snowflake_client as sf
from backend.api.schemas.matches import AlternativesResponse

router = APIRouter(tags=["matches"])


@router.get("/{item_id}/alternatives", response_model=AlternativesResponse)
async def get_alternatives(item_id: str):
    """Get alternative match candidates for an item (React frontend).

    Returns cached candidates from MATCH_CANDIDATES table, or performs
    a live Cortex Search if no cached candidates exist.
    """
    db = sf.get_database()

    try:
        # First try cached candidates from MATCH_CANDIDATES table
        candidates = await sf.query(f"""
            SELECT
                mc.CANDIDATE_ID,
                mc.STANDARD_ITEM_ID,
                mc.STANDARD_DESCRIPTION AS CANDIDATE_DESCRIPTION,
                mc.RANK,
                mc.CONFIDENCE_SCORE,
                mc.MATCH_METHOD,
                si.STANDARD_DESCRIPTION,
                si.BRAND,
                si.SRP
            FROM {db}.HARMONIZED.MATCH_CANDIDATES mc
            LEFT JOIN {db}.RAW.STANDARD_ITEMS si
                ON mc.STANDARD_ITEM_ID = si.STANDARD_ITEM_ID
            WHERE mc.RAW_ITEM_ID = '{item_id}'
            ORDER BY mc.CONFIDENCE_SCORE DESC
            LIMIT 10
        """)

        # Fallback: Live Cortex Search if no cached candidates
        if not candidates:
            raw_item = await sf.query(f"""
                SELECT RAW_DESCRIPTION
                FROM {db}.RAW.RAW_RETAIL_ITEMS
                WHERE ITEM_ID = '{item_id}'
                LIMIT 1
            """)

            if raw_item and raw_item[0].get("RAW_DESCRIPTION"):
                description = raw_item[0]["RAW_DESCRIPTION"]
                safe_desc = description.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")

                try:
                    search_results = await sf.query(f"""
                        SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                            '{db}.HARMONIZED.STANDARD_ITEM_SEARCH',
                            '{{"query": "{safe_desc}", "columns": ["STANDARD_ITEM_ID", "STANDARD_DESCRIPTION", "BRAND", "SRP"], "limit": 10}}'
                        ) AS results
                    """)

                    if search_results and search_results[0].get("RESULTS"):
                        results_data = search_results[0]["RESULTS"]
                        if isinstance(results_data, str):
                            results_data = json_mod.loads(results_data)

                        if "results" in results_data and results_data["results"]:
                            candidates = []
                            for rank, r in enumerate(results_data["results"]):
                                scores = r.get("@scores", {})
                                cosine_sim = scores.get("cosine_similarity", 0)
                                normalized_score = (cosine_sim + 1) / 2 if cosine_sim else 0.5

                                candidates.append(
                                    {
                                        "STANDARD_ITEM_ID": r.get("STANDARD_ITEM_ID", ""),
                                        "STANDARD_DESCRIPTION": r.get("STANDARD_DESCRIPTION", ""),
                                        "BRAND": r.get("BRAND", ""),
                                        "SRP": r.get("SRP", ""),
                                        "CONFIDENCE_SCORE": normalized_score,
                                        "MATCH_METHOD": "Live Search",
                                        "RANK": rank + 1,
                                    }
                                )
                except Exception:
                    pass

        # Format response for React frontend
        alternatives = []
        for c in candidates:
            alternatives.append(
                {
                    "standardItemId": c.get("STANDARD_ITEM_ID", ""),
                    "description": c.get("STANDARD_DESCRIPTION", "") or c.get("CANDIDATE_DESCRIPTION", ""),
                    "brand": c.get("BRAND", "") or "",
                    "price": float(c.get("SRP", 0) or 0),
                    "score": float(c.get("CONFIDENCE_SCORE", 0) or 0),
                    "method": c.get("MATCH_METHOD", ""),
                    "rank": int(c.get("RANK", 0) or 0),
                }
            )

        return {"alternatives": alternatives}
    except Exception as e:
        return {"alternatives": [], "error": str(e)}
