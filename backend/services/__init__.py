"""Service layer for business logic.

This module provides domain services that encapsulate business logic,
separating it from HTTP route handlers. Services handle SQL queries,
caching, data transformation, and validation.

Usage:
    from backend.services import DashboardService, ReviewService
    from backend.services.cache import get_async_cache
"""

from backend.services.base import BaseService
from backend.services.cache import (
    SyncTTLCache,
    TTLCache,
    get_async_cache,
    get_sync_cache,
)
from backend.services.comparison import ComparisonService
from backend.services.dashboard import DashboardService
from backend.services.logs import LogsService
from backend.services.pipeline import PipelineService
from backend.services.review import ReviewService
from backend.services.settings import SettingsService
from backend.services.testing import TestingService

__all__ = [
    "BaseService",
    "ComparisonService",
    "DashboardService",
    "LogsService",
    "PipelineService",
    "ReviewService",
    "SettingsService",
    "TestingService",
    "TTLCache",
    "SyncTTLCache",
    "get_async_cache",
    "get_sync_cache",
]
