"""Shared pytest fixtures for retail_harmonizer tests.

Provides:
- session: Snowpark session for integration tests (skips if unavailable)
- mock_snowflake_connection: Mock connection for unit tests
- mock_sf: AsyncMock Snowflake client for service tests
- mock_cache: MagicMock TTLCache for caching tests
- app_client: FastAPI TestClient with mocked Snowflake backend
"""

from __future__ import annotations

import os
from collections.abc import Generator
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def mock_snowflake_connection() -> Generator[MagicMock, None, None]:
    """Create a mock Snowflake connection for unit tests."""
    with patch("snowflake.connector.connect") as mock_connect:
        mock_conn = MagicMock()
        mock_connect.return_value = mock_conn
        yield mock_conn


@pytest.fixture
def session() -> Generator[Any, None, None]:
    """Create a Snowpark session for integration tests.

    Skips tests if SNOWFLAKE_CONNECTION environment variable is not set
    or if connection cannot be established.
    """
    connection_name = os.environ.get("SNOWFLAKE_CONNECTION", "")

    if not connection_name:
        pytest.skip("SNOWFLAKE_CONNECTION not set - skipping integration test")

    try:
        from snowflake.snowpark import Session

        session = Session.builder.config("connection_name", connection_name).create()
        yield session
        session.close()
    except ImportError:
        pytest.skip("snowflake-snowpark-python not installed")
    except Exception as e:
        pytest.skip(f"Could not create Snowpark session: {e}")


@pytest.fixture
def mock_sf() -> AsyncMock:
    """Create a mock Snowflake client for unit tests.

    Returns an AsyncMock with pre-configured query and execute methods.
    """
    sf = AsyncMock()
    sf.query = AsyncMock(return_value=[])
    sf.execute = AsyncMock(return_value="Statement executed successfully.")
    return sf


@pytest.fixture
def mock_cache() -> MagicMock:
    """Create a mock TTLCache for caching tests.

    Returns a MagicMock with pre-configured get, set, and get_or_fetch methods.
    """
    cache = MagicMock()
    cache.get = MagicMock(return_value=None)
    cache.set = MagicMock()
    cache.get_or_fetch = AsyncMock(return_value=[])
    return cache


@pytest.fixture
def app_client() -> Generator[TestClient, None, None]:
    """Create TestClient with mocked Snowflake client.

    Yields a FastAPI TestClient with all Snowflake backend calls mocked.
    Use this fixture instead of module-level patching for better test isolation.
    """
    with patch("backend.api.snowflake_client") as mock_sf:
        mock_sf.get_database.return_value = "HARMONIZER_DEMO"
        mock_sf.query = AsyncMock(return_value=[])
        mock_sf.execute = AsyncMock(return_value="OK")
        mock_sf.test_connection = AsyncMock(return_value=True)

        from backend.api import app

        yield TestClient(app)
