"""Dashboard categories endpoint.

Returns category match rate breakdown.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter

from backend.api.deps import CacheDep, DashboardServiceDep
from backend.api.schemas.dashboard import CategoriesResponse, CategoryRate

logger = logging.getLogger(__name__)

router = APIRouter()

CACHE_TTL_SECONDS = 10.0


@router.get("/categories", response_model=CategoriesResponse)
async def get_dashboard_categories(
    svc: DashboardServiceDep,
    cache: CacheDep,
) -> CategoriesResponse:
    """Get category match rate breakdown.

    Returns match rates per product category.

    Cache TTL: 10 seconds
    """

    async def fetch_categories() -> CategoriesResponse:
        try:
            combined = await svc.get_combined_data()
            category_rate_rows = combined["category_rate_rows"]

            category_rates = []
            for row in category_rate_rows:
                category = row.get("CATEGORY", "")
                if category and category.upper() != "UNKNOWN":
                    cat_total = int(row.get("TOTAL", 0) or 0)
                    cat_matched = int(row.get("MATCHED", 0) or 0)
                    rate = round(cat_matched / cat_total * 100, 1) if cat_total > 0 else 0.0
                    category_rates.append(
                        CategoryRate(
                            category=category,
                            total=cat_total,
                            matched=cat_matched,
                            rate=rate,
                        )
                    )

            return CategoriesResponse(category_rates=category_rates)
        except Exception as e:
            logger.warning(f"Failed to fetch categories: {e}")
            return CategoriesResponse(category_rates=[])

    return await cache.get_or_fetch("dashboard:categories", CACHE_TTL_SECONDS, fetch_categories)
