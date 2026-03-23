"""Settings API response schemas.

Defines Pydantic models for pipeline configuration settings including
algorithm weights, match thresholds, performance tuning, cost tracking,
and automation controls. Settings are read from the ANALYTICS.CONFIG table.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class WeightsConfig(BaseModel):
    """Algorithm weight configuration for ensemble scoring.

    Weights control how individual algorithm scores are combined into the
    final ensemble score. All weights should sum to 1.0 for normalized scoring.

    Attributes:
        cortexSearch: Weight for Cortex Search results (0.0-1.0).
        cosine: Weight for cosine similarity (0.0-1.0).
        editDistance: Weight for edit distance (0.0-1.0).
        jaccard: Weight for Jaccard similarity (0.0-1.0).
    """

    cortexSearch: float = Field(..., ge=0, le=1, description="Cortex Search weight (0.0-1.0)")
    cosine: float = Field(..., ge=0, le=1, description="Cosine similarity weight (0.0-1.0)")
    editDistance: float = Field(..., ge=0, le=1, description="Edit distance weight (0.0-1.0)")
    jaccard: float = Field(..., ge=0, le=1, description="Jaccard similarity weight (0.0-1.0)")


class ThresholdsConfig(BaseModel):
    """Match threshold configuration for automated decision boundaries.

    Thresholds define score ranges for automatic accept/reject decisions.
    Must satisfy: reject < reviewMin < reviewMax < autoAccept.
    Scores between reviewMin and reviewMax require manual review.

    Attributes:
        autoAccept: Minimum score for automatic acceptance (0-100).
        reject: Maximum score for automatic rejection (0-100).
        reviewMin: Lower bound of manual review range (0-100).
        reviewMax: Upper bound of manual review range (0-100).
    """

    autoAccept: float = Field(..., ge=0, le=100, description="Auto-accept threshold (0-100)")
    reject: float = Field(..., ge=0, le=100, description="Auto-reject threshold (0-100)")
    reviewMin: float = Field(..., ge=0, le=100, description="Review range lower bound (0-100)")
    reviewMax: float = Field(..., ge=0, le=100, description="Review range upper bound (0-100)")


class PerformanceConfig(BaseModel):
    """Performance tuning configuration for pipeline execution.

    Controls batch processing and parallelism settings. Higher values
    increase throughput but consume more warehouse resources.

    Attributes:
        batchSize: Items per batch (100-10000, recommended: 1000).
        parallelism: Concurrent threads (1-16, recommended: 4).
        cacheEnabled: Whether to cache intermediate results.
    """

    batchSize: int = Field(..., ge=100, le=10000, description="Items per batch (100-10000)")
    parallelism: int = Field(..., ge=1, le=16, description="Concurrent threads (1-16)")
    cacheEnabled: bool = Field(..., description="Cache intermediate results")


class CostConfig(BaseModel):
    """Cost tracking configuration for ROI monitoring.

    All monetary values are in USD. Used to track Cortex AI costs and
    calculate return on investment compared to manual matching.

    Attributes:
        cortexCostPerCall: Cost per Cortex AI call in USD (e.g., 0.002).
        targetROI: Target return on investment percentage (e.g., 200 for 2x).
        maxDailyCost: Maximum daily spend limit in USD.
    """

    cortexCostPerCall: float = Field(..., ge=0, description="Cortex AI cost per call (USD)")
    targetROI: float = Field(..., ge=0, description="Target ROI percentage")
    maxDailyCost: float = Field(..., ge=0, description="Max daily cost (USD)")


class AutomationConfig(BaseModel):
    """Automation settings for hands-off pipeline operation.

    Controls automatic acceptance/rejection based on threshold scores
    and algorithm agreement levels.

    Attributes:
        autoAcceptEnabled: Enable automatic acceptance above autoAccept threshold.
        autoRejectEnabled: Enable automatic rejection below reject threshold.
        minAgreementLevel: Minimum algorithms that must agree for auto-decisions (1-4).
    """

    autoAcceptEnabled: bool = Field(..., description="Enable automatic acceptance")
    autoRejectEnabled: bool = Field(..., description="Enable automatic rejection")
    minAgreementLevel: int = Field(..., ge=1, le=4, description="Min algorithms agreeing (1-4)")


class SettingsResponse(BaseModel):
    """Complete settings response."""

    weights: WeightsConfig
    thresholds: ThresholdsConfig
    performance: PerformanceConfig
    cost: CostConfig
    automation: AutomationConfig
