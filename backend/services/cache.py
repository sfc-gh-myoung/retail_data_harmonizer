"""TTL-based cache for service layer query results.

Provides both async and sync caching patterns to support different use cases.

Classes:
    TTLCache: Async cache with asyncio.Lock for thread-safe access.
    SyncTTLCache: Lightweight sync cache without async locks.

Singletons:
    get_async_cache(): FastAPI dependency returning shared TTLCache instance.
    get_sync_cache(): FastAPI dependency returning shared SyncTTLCache instance.

Side Effects:
    get_async_cache/get_sync_cache mutate module-level globals on first call.
"""

from __future__ import annotations

import asyncio
import logging
import time
from collections.abc import Callable, Coroutine
from dataclasses import dataclass, field
from typing import Any

logger = logging.getLogger(__name__)


@dataclass
class TTLCache:
    """Async TTL cache for query results to reduce Snowflake load.

    Used to cache slow-changing data like config and classification status
    while keeping real-time queries (SHOW TASKS, GET_PIPELINE_STATUS) uncached.

    Thread-safe via asyncio.Lock.
    """

    _cache: dict[str, tuple[float, Any]] = field(default_factory=dict)
    _lock: asyncio.Lock = field(default_factory=asyncio.Lock)

    async def get_or_fetch(
        self,
        key: str,
        ttl_seconds: float,
        fetch_fn: Callable[[], Coroutine[Any, Any, Any]],
    ) -> Any:
        """Return cached value if fresh, otherwise execute fetch_fn.

        Args:
            key: Cache key for this query.
            ttl_seconds: How long to cache the result.
            fetch_fn: Async function to call if cache miss/expired.

        Returns:
            Cached or freshly fetched result.
        """
        now = time.time()

        # Check cache under lock
        async with self._lock:
            if key in self._cache:
                expires, value = self._cache[key]
                if now < expires:
                    logger.debug(f"Cache HIT for {key}")
                    return value

        # Fetch fresh value (outside lock to allow parallel fetches for different keys)
        logger.debug(f"Cache MISS for {key}, fetching...")
        value = await fetch_fn()

        # Store in cache
        async with self._lock:
            self._cache[key] = (now + ttl_seconds, value)
        return value

    def get(self, key: str) -> Any | None:
        """Get cached value if not expired (sync access).

        Args:
            key: Cache key to retrieve.

        Returns:
            Cached value or None if expired/missing.
        """
        entry = self._cache.get(key)
        if entry:
            expires, value = entry
            if time.time() < expires:
                return value
        return None

    def set(self, key: str, value: Any, ttl_seconds: float = 30.0) -> None:
        """Store value in cache with TTL (sync access).

        Args:
            key: Cache key.
            value: Value to cache.
            ttl_seconds: How long to cache the result.
        """
        self._cache[key] = (time.time() + ttl_seconds, value)

    def invalidate(self, key: str | None = None) -> None:
        """Invalidate specific key or entire cache.

        Args:
            key: Specific key to invalidate, or None to clear all.
        """
        if key:
            self._cache.pop(key, None)
            logger.debug(f"Cache invalidated: {key}")
        else:
            self._cache.clear()
            logger.debug("Cache cleared (all keys)")


@dataclass
class SyncTTLCache:
    """Simple synchronous TTL cache for dashboard queries.

    A lighter-weight cache without async locks for simpler use cases.
    """

    ttl_seconds: float = 30.0
    _cache: dict[str, tuple[float, Any]] = field(default_factory=dict)

    def get(self, key: str) -> Any | None:
        """Get cached value if not expired.

        Args:
            key: Cache key to retrieve.

        Returns:
            Cached value or None if expired/missing.
        """
        entry = self._cache.get(key)
        if entry and (time.monotonic() - entry[0]) < self.ttl_seconds:
            return entry[1]
        return None

    def set(self, key: str, value: Any) -> None:
        """Store value in cache with current timestamp.

        Args:
            key: Cache key.
            value: Value to cache.
        """
        self._cache[key] = (time.monotonic(), value)

    def invalidate(self, key: str | None = None) -> None:
        """Invalidate specific key or entire cache.

        Args:
            key: Specific key to invalidate, or None to clear all.
        """
        if key:
            self._cache.pop(key, None)
        else:
            self._cache.clear()

    async def get_or_fetch(
        self,
        key: str,
        ttl_seconds: float,
        fetch_fn: Callable[[], Coroutine[Any, Any, Any]],
    ) -> Any:
        """Return cached value if fresh, otherwise execute fetch_fn.

        Args:
            key: Cache key for this query.
            ttl_seconds: How long to cache the result (uses instance ttl_seconds).
            fetch_fn: Async function to call if cache miss/expired.

        Returns:
            Cached or freshly fetched result.
        """
        cached = self.get(key)
        if cached is not None:
            return cached

        value = await fetch_fn()
        self.set(key, value)
        return value


# Singleton instances for FastAPI dependency injection
_async_cache_instance: TTLCache | None = None
_sync_cache_instance: SyncTTLCache | None = None


def get_async_cache() -> TTLCache:
    """FastAPI dependency for async cache injection.

    Returns a singleton TTLCache instance, creating it on first call.

    Side Effects:
        Mutates module-level _async_cache_instance global on first invocation.

    Returns:
        Shared TTLCache instance for the application.
    """
    global _async_cache_instance
    if _async_cache_instance is None:
        _async_cache_instance = TTLCache()
    return _async_cache_instance


def get_sync_cache() -> SyncTTLCache:
    """FastAPI dependency for sync cache injection.

    Returns a singleton SyncTTLCache instance, creating it on first call.

    Side Effects:
        Mutates module-level _sync_cache_instance global on first invocation.

    Returns:
        Shared SyncTTLCache instance for the application.
    """
    global _sync_cache_instance
    if _sync_cache_instance is None:
        _sync_cache_instance = SyncTTLCache()
    return _sync_cache_instance
