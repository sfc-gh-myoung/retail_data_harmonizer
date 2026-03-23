"""Comparison API response schemas for modular endpoints."""

from __future__ import annotations

from pydantic import BaseModel, Field

# ============================================================================
# Individual data models
# ============================================================================


class Algorithm(BaseModel):
    """Algorithm description for the method overview section."""

    name: str
    description: str
    features: list[str]


class AgreementData(BaseModel):
    """Agreement analysis data point."""

    level: str = Field(..., description="e.g., '4 of 4 Agree', '3 of 4 Agree'")
    count: int
    avgConfidence: float


class SourcePerformance(BaseModel):
    """Source system performance metrics."""

    source: str
    itemCount: int
    avgSearch: float
    avgCosine: float
    avgEdit: float
    avgJaccard: float
    avgEnsemble: float


class MethodAccuracy(BaseModel):
    """Method accuracy metrics based on confirmed matches."""

    totalConfirmed: int = Field(..., description="Total confirmed matches used for accuracy calc")
    searchCorrect: int
    searchAccuracyPct: float
    cosineCorrect: int
    cosineAccuracyPct: float
    editCorrect: int
    editAccuracyPct: float
    jaccardCorrect: int
    jaccardAccuracyPct: float
    ensembleCorrect: int
    ensembleAccuracyPct: float


# ============================================================================
# Endpoint response schemas
# ============================================================================


class AlgorithmsResponse(BaseModel):
    """Response for GET /api/v2/comparison/algorithms endpoint."""

    algorithms: list[Algorithm]


class AgreementResponse(BaseModel):
    """Response for GET /api/v2/comparison/agreement endpoint."""

    agreement: list[AgreementData]


class SourcePerformanceResponse(BaseModel):
    """Response for GET /api/v2/comparison/source-performance endpoint."""

    sourcePerformance: list[SourcePerformance]


class MethodAccuracyResponse(BaseModel):
    """Response for GET /api/v2/comparison/method-accuracy endpoint."""

    methodAccuracy: MethodAccuracy
