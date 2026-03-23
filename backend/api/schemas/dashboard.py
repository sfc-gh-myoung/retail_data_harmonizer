"""Dashboard API response schemas.

Defines Pydantic models for dashboard visualization endpoints including
KPIs, source system breakdowns, category rates, signal analysis,
and cost/ROI metrics. Powers the React dashboard UI.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class KPIData(BaseModel):
    """Key performance indicator data."""

    totalRaw: int = Field(..., description="Total raw items")
    totalUnique: int = Field(..., description="Unique item count")
    totalProcessed: int = Field(..., description="Total processed")
    autoAccepted: int = Field(..., description="Auto-accepted count")
    confirmed: int = Field(..., description="Confirmed count")
    pendingReview: int = Field(..., description="Pending review count")
    rejected: int = Field(..., description="Rejected count")
    needsCategorized: int = Field(..., description="Needs categorization")
    matchRate: float = Field(..., description="Match rate percentage")
    total: int = Field(..., description="Total items")


class SourceStatus(BaseModel):
    """Status breakdown by source system for bar chart visualization.

    Attributes:
        label: Status label (e.g., 'Pending', 'Confirmed', 'Rejected').
        count: Number of items in this status.
        color: Hex color code for UI rendering (e.g., '#4CAF50').
    """

    label: str = Field(..., description="Status label")
    count: int = Field(..., description="Item count in this status")
    color: str = Field(..., description="Hex color code (e.g., '#4CAF50')")


class CategoryRate(BaseModel):
    """Match rate by product category for category breakdown chart.

    Attributes:
        category: Product category name from standard catalog.
        total: Total items in this category.
        matched: Items successfully matched in this category.
        rate: Match rate as percentage (0-100).
    """

    category: str = Field(..., description="Product category name")
    total: int = Field(..., description="Total items in category")
    matched: int = Field(..., description="Matched items in category")
    rate: float = Field(..., description="Match rate percentage (0-100)")


class SignalDominance(BaseModel):
    """Signal dominance metrics showing which algorithm wins most often.

    Dominance = how often each scoring algorithm produces the highest score.
    Used to understand which algorithms are driving match decisions.

    Attributes:
        method: Algorithm name (CORTEX_SEARCH, COSINE, EDIT, JACCARD).
        count: Number of matches where this algorithm had highest score.
        pct: Percentage of total matches (0-100).
        color: Hex color code for chart visualization.
    """

    method: str = Field(..., description="Algorithm name")
    count: int = Field(..., description="Wins count")
    pct: float = Field(..., description="Win percentage (0-100)")
    color: str = Field(..., description="Hex color code")


class SignalAlignment(BaseModel):
    """Signal-ensemble alignment showing algorithm agreement with final score.

    Alignment = how often each algorithm agrees with the ensemble decision.
    High alignment indicates the algorithm correlates well with overall scoring.

    Attributes:
        method: Algorithm name (CORTEX_SEARCH, COSINE, EDIT, JACCARD).
        count: Matches where algorithm agreed with ensemble decision.
        pct: Agreement percentage (0-100).
        color: Hex color code for chart visualization.
    """

    method: str = Field(..., description="Algorithm name")
    count: int = Field(..., description="Agreement count")
    pct: float = Field(..., description="Agreement percentage (0-100)")
    color: str = Field(..., description="Hex color code")


class AgreementLevel(BaseModel):
    """Agreement level distribution showing algorithm consensus.

    Agreement = number of algorithms that chose the same standard item.
    Higher agreement indicates more confidence in the match.

    Attributes:
        level: Agreement tier (e.g., '4 algorithms', '3 algorithms', etc.).
        count: Number of matches at this agreement level.
        pct: Percentage of total matches (0-100).
        color: Hex color code for chart visualization.
    """

    level: str = Field(..., description="Agreement tier label")
    count: int = Field(..., description="Matches at this level")
    pct: float = Field(..., description="Percentage (0-100)")
    color: str = Field(..., description="Hex color code")


class ScaleMetrics(BaseModel):
    """Scale and deduplication metrics for throughput analysis.

    Tracks item volume and deduplication efficiency. Fast path = items
    that matched previously seen descriptions without full scoring.

    Attributes:
        total: Total raw items ingested.
        uniqueCount: Unique descriptions after deduplication.
        dedupRatio: Deduplication ratio (total / unique).
        fastPathCount: Items resolved via cached matches.
        fastPathRate: Fast path percentage (0-100).
    """

    total: int = Field(..., description="Total raw items")
    uniqueCount: int = Field(..., description="Unique descriptions")
    dedupRatio: float = Field(..., description="Dedup ratio")
    fastPathCount: int = Field(..., description="Cached match hits")
    fastPathRate: float = Field(..., description="Fast path rate (0-100)")


class CostMetrics(BaseModel):
    """Cost and ROI metrics for financial analysis.

    All monetary values are in USD. ROI compares automated matching cost
    against estimated manual matching cost based on hourly rate.

    Attributes:
        totalRuns: Number of pipeline runs.
        totalUsd: Total cost in USD.
        totalCredits: Total Snowflake credits consumed.
        totalItems: Items processed across all runs.
        costPerItem: Average cost per item (USD).
        baselineWeeklyCost: Estimated weekly manual matching cost (USD).
        hoursSaved: Estimated labor hours saved.
        roiPercentage: Return on investment percentage.
        creditRateUsd: Snowflake credit rate (USD per credit).
        manualHourlyRate: Manual labor hourly rate (USD).
        manualMinutesPerItem: Estimated minutes per manual match.
    """

    totalRuns: int = Field(..., description="Pipeline run count")
    totalUsd: float = Field(..., description="Total cost (USD)")
    totalCredits: float = Field(..., description="Snowflake credits used")
    totalItems: int = Field(..., description="Items processed")
    costPerItem: float = Field(..., description="Cost per item (USD)")
    baselineWeeklyCost: float = Field(..., description="Manual weekly cost (USD)")
    hoursSaved: float = Field(..., description="Labor hours saved")
    roiPercentage: float = Field(..., description="ROI percentage")
    creditRateUsd: float = Field(..., description="Credit rate (USD/credit)")
    manualHourlyRate: float = Field(..., description="Manual hourly rate (USD)")
    manualMinutesPerItem: float = Field(..., description="Minutes per manual match")


class SourceRate(BaseModel):
    """Match rate for a single source system."""

    source: str
    total: int
    matched: int
    rate: float


class KpisResponse(BaseModel):
    """Response for /api/v2/dashboard/kpis endpoint.

    Returns core KPIs and status distribution for the dashboard header.
    """

    stats: KPIData
    statuses: list[SourceStatus]
    status_colors_map: dict[str, str] = Field(..., description="Status to color mapping for UI")


class SourcesResponse(BaseModel):
    """Response for /api/v2/dashboard/sources endpoint.

    Returns source system breakdown with status distribution.
    """

    source_systems: dict[str, dict[str, int]] = Field(..., description="Status counts per source system")
    source_rates: list[SourceRate] = Field(..., description="Match rates per source system")
    source_max: int = Field(..., description="Max items for normalization")


class CategoriesResponse(BaseModel):
    """Response for /api/v2/dashboard/categories endpoint."""

    category_rates: list[CategoryRate]


class SignalsResponse(BaseModel):
    """Response for /api/v2/dashboard/signals endpoint.

    Returns signal dominance and ensemble alignment metrics.
    """

    signal_dominance: list[SignalDominance]
    signal_alignment: list[SignalAlignment]
    agreements: list[AgreementLevel]


class CostResponse(BaseModel):
    """Response for /api/v2/dashboard/cost endpoint."""

    cost_data: CostMetrics | None
    scale_data: ScaleMetrics
