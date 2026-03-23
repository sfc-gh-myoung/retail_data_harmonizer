"""Shared dependencies for API routes.

This module provides FastAPI dependency injection for common resources
like the Snowflake client and domain services, enabling consistent access
across all routes.
"""

from __future__ import annotations

import asyncio
from collections.abc import Callable
from typing import Annotated

from fastapi import Depends

from backend.api import snowflake_client as sf
from backend.api.snowflake_client import SnowflakeClientWrapper, get_client_wrapper
from backend.services import (
    ComparisonService,
    DashboardService,
    LogsService,
    PipelineService,
    ReviewService,
    SettingsService,
    TestingService,
)
from backend.services.cache import SyncTTLCache, TTLCache, get_async_cache, get_sync_cache
from backend.snowflake import get_client

# ---------------------------------------------------------------------------
# Core dependencies
# ---------------------------------------------------------------------------


async def get_snowflake_client():
    """Get configured Snowflake client for dependency injection.

    Returns the singleton Snowflake client instance configured via
    environment variables. Used as a FastAPI dependency.

    Returns:
        Configured SnowflakeClient instance.
    """
    return get_client()


def get_database_name() -> str:
    """Get the configured database name."""
    return sf.get_database()


def get_cache_invalidate() -> Callable[[], None]:
    """Get the cache invalidation function."""
    import backend.api as api_mod

    return api_mod.cache_invalidate


def get_background_tasks() -> set[asyncio.Task]:
    """Get the shared background tasks set."""
    import backend.api as api_mod

    return api_mod._background_tasks


SnowflakeDep = Annotated[object, Depends(get_snowflake_client)]
"""Type alias for Snowflake client dependency injection in route signatures."""

DatabaseDep = Annotated[str, Depends(get_database_name)]
"""Type alias for database name dependency injection."""

CacheDep = Annotated[TTLCache, Depends(get_async_cache)]
"""Type alias for async TTL cache dependency injection."""

CacheInvalidateDep = Annotated[Callable[[], None], Depends(get_cache_invalidate)]
"""Type alias for cache invalidation function dependency injection."""

BackgroundTasksDep = Annotated[set[asyncio.Task], Depends(get_background_tasks)]
"""Type alias for background tasks set dependency injection."""

SfClientDep = Annotated[SnowflakeClientWrapper, Depends(get_client_wrapper)]
"""Type alias for Snowflake client wrapper dependency injection."""


# ---------------------------------------------------------------------------
# Service dependencies
# ---------------------------------------------------------------------------


SyncCacheDep = Annotated[SyncTTLCache, Depends(get_sync_cache)]
"""Type alias for sync TTL cache dependency injection."""


def get_dashboard_service(
    db_name: DatabaseDep,
    sf_client: SfClientDep,
    cache: SyncCacheDep,
) -> DashboardService:
    """Factory for DashboardService with injected dependencies."""
    return DashboardService(db_name=db_name, sf=sf_client, cache=cache)


def get_review_service(
    db_name: DatabaseDep,
    sf_client: SfClientDep,
    cache: CacheDep,
) -> ReviewService:
    """Factory for ReviewService with injected dependencies."""
    return ReviewService(db_name=db_name, sf=sf_client, cache=cache)


def get_pipeline_service(
    db_name: DatabaseDep,
    sf_client: SfClientDep,
    cache: CacheDep,
) -> PipelineService:
    """Factory for PipelineService with injected dependencies."""
    return PipelineService(db_name=db_name, sf=sf_client, cache=cache)


def get_comparison_service(
    db_name: DatabaseDep,
    sf_client: SfClientDep,
    cache: CacheDep,
) -> ComparisonService:
    """Factory for ComparisonService with injected dependencies."""
    return ComparisonService(db_name=db_name, sf=sf_client, cache=cache)


def get_testing_service(
    db_name: DatabaseDep,
    sf_client: SfClientDep,
    cache: CacheDep,
) -> TestingService:
    """Factory for TestingService with injected dependencies."""
    return TestingService(db_name=db_name, sf=sf_client, cache=cache)


def get_logs_service(
    db_name: DatabaseDep,
    sf_client: SfClientDep,
    cache: CacheDep,
) -> LogsService:
    """Factory for LogsService with injected dependencies."""
    return LogsService(db_name=db_name, sf=sf_client, cache=cache)


def get_settings_service(
    db_name: DatabaseDep,
    sf_client: SfClientDep,
    cache: CacheDep,
) -> SettingsService:
    """Factory for SettingsService with injected dependencies."""
    return SettingsService(db_name=db_name, sf=sf_client, cache=cache)


# ---------------------------------------------------------------------------
# Service type aliases for route injection
# ---------------------------------------------------------------------------

DashboardServiceDep = Annotated[DashboardService, Depends(get_dashboard_service)]
ReviewServiceDep = Annotated[ReviewService, Depends(get_review_service)]
PipelineServiceDep = Annotated[PipelineService, Depends(get_pipeline_service)]
ComparisonServiceDep = Annotated[ComparisonService, Depends(get_comparison_service)]
TestingServiceDep = Annotated[TestingService, Depends(get_testing_service)]
LogsServiceDep = Annotated[LogsService, Depends(get_logs_service)]
SettingsServiceDep = Annotated[SettingsService, Depends(get_settings_service)]
