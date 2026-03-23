"""Matches API response schemas.

Defines Pydantic models for the matches search, filter, and review API endpoints.
These schemas provide type-safe request/response validation and automatic
OpenAPI documentation for the React frontend integration.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class MatchSearchRequest(BaseModel):
    """Request parameters for paginated match search with filtering and sorting.

    Supports filtering by status, source system, category, and match source.
    Results can be grouped by unique description to deduplicate variant items.
    """

    page: int = Field(1, ge=1)
    pageSize: int = Field(25, ge=1, le=100)
    status: str | None = None
    source: str | None = None
    category: str | None = None
    subcategory: str | None = None
    matchSource: str | None = None
    agreement: str | None = None
    sortBy: str = Field("ensemble_score", description="Column to sort by")
    sortOrder: Literal["asc", "desc"] = Field("desc", description="Sort direction")
    groupBy: str = "unique_description"


class MatchItem(BaseModel):
    """Complete match result with all scoring components and metadata.

    Contains raw item info, matched standard item, individual algorithm
    scores (search, cosine, edit distance, jaccard), and ensemble
    scoring metadata including agreement level and boost percentage.
    """

    id: str = Field(..., description="Unique row identifier")
    itemId: str = Field(..., description="Raw item identifier from source system")
    matchId: str = Field(..., description="Match record identifier")
    rawName: str = Field(..., description="Original item description from source")
    matchedName: str = Field(..., description="Matched standard item description")
    standardItemId: str = Field(..., description="Standard catalog item identifier")
    status: str = Field(..., description="Match status: PENDING, AUTO_ACCEPTED, CONFIRMED, REJECTED")
    source: str = Field(..., description="Source system identifier (e.g., POS_SYSTEM_A)")
    category: str = Field(..., description="Product category from standard catalog")
    subcategory: str = Field(..., description="Product subcategory from standard catalog")
    brand: str = Field(..., description="Brand name from standard catalog")
    price: float = Field(..., description="Product price in USD")
    searchScore: float = Field(..., description="Cortex Search score (0-1)")
    cosineScore: float = Field(..., description="Cosine similarity score (0-1)")
    editScore: float = Field(..., description="Edit distance normalized score (0-1)")
    jaccardScore: float = Field(..., description="Jaccard similarity score (0-1)")
    ensembleScore: float = Field(..., description="Weighted ensemble score (0-100)")
    maxRawScore: float = Field(..., description="Highest individual algorithm score (0-1)")
    score: float = Field(..., description="Final display score (0-100)")
    matchSource: str = Field(..., description="Winning algorithm: CORTEX_SEARCH, COSINE, EDIT, JACCARD")
    matchMethod: str = Field(..., description="How match was determined: ENSEMBLE, SINGLE_WINNER")
    agreementLevel: int = Field(..., description="Number of algorithms agreeing on match (1-4)")
    boostLevel: str = Field(..., description="Confidence tier: HIGH, MEDIUM, LOW, REVIEW")
    boostPercent: int = Field(..., description="Score boost percentage applied (0-100)")
    duplicateCount: int = Field(..., description="Number of duplicate raw items with same description")
    createdAt: str = Field(..., description="Match creation timestamp (ISO-8601 format)")


class MatchSearchResponse(BaseModel):
    """Paginated response for match search containing items and metadata."""

    items: list[MatchItem]
    total: int
    page: int
    pageSize: int
    totalPages: int
    error: str | None = None


class BoostLevelOption(BaseModel):
    """Boost level filter option for dropdown selection."""

    value: str
    label: str


class AgreementLevelOption(BaseModel):
    """Agreement level filter option for dropdown selection."""

    value: str
    label: str


class GroupByOption(BaseModel):
    """Group by filter option for dropdown selection."""

    value: str
    label: str


class FilterOptionsResponse(BaseModel):
    """Available filter options for the match search UI dropdowns."""

    sources: list[str]
    categories: list[str]
    subcategoriesByCategory: dict[str, list[str]]
    matchSources: list[str]
    agreementLevels: list[AgreementLevelOption]
    groupByOptions: list[GroupByOption]
    error: str | None = None


class AlternativeMatch(BaseModel):
    """Alternative match candidate for manual re-matching.

    Represents a potential standard item that could be selected instead
    of the current suggested match.
    """

    standardItemId: str
    description: str
    brand: str
    price: float
    score: float
    method: str
    rank: int


class AlternativesResponse(BaseModel):
    """Available alternative matches for a given raw item."""

    alternatives: list[AlternativeMatch]
    error: str | None = None


class BulkActionRequest(BaseModel):
    """Request for bulk status update on multiple matches.

    Used for batch accept/reject operations from the review queue.
    """

    ids: list[str] = Field(..., description="List of match IDs to update")
    action: Literal["accept", "reject"] = Field(..., description="Bulk action to perform")


class BulkActionResponse(BaseModel):
    """Response for bulk action indicating success and count updated."""

    success: bool
    updated: int | None = None
    error: str | None = None


class StatusUpdateRequest(BaseModel):
    """Request for single match status update.

    Optionally propagates the status change to related items with
    the same normalized description.
    """

    status: str
    updateRelated: bool = False


class StatusUpdateResponse(BaseModel):
    """Response for status update with affected item counts."""

    success: bool
    matchId: str | None = None
    status: str | None = None
    updatedCount: int | None = None
    variantCount: int | None = None
    error: str | None = None
