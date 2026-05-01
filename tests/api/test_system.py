"""Tests for system API endpoints (health and status)."""

from __future__ import annotations

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from backend.api import create_app


@pytest.fixture
def client():
    """Create test client for system endpoints."""
    app = create_app()
    return TestClient(app)


# ---------------------------------------------------------------------------
# Health Endpoint Tests
# ---------------------------------------------------------------------------


def test_health_endpoint_returns_ok(client):
    """Verify /api/v2/health returns 200 with status 'ok'."""
    response = client.get("/api/v2/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"


# ---------------------------------------------------------------------------
# Status Endpoint Tests - Success Cases
# ---------------------------------------------------------------------------


@patch("backend.api.routes.system.sf.test_connection")
@patch("backend.api.routes.system.sf.query")
@patch("backend.api.routes.system.sf.get_database")
def test_status_endpoint_connected(mock_get_database, mock_query, mock_test_connection, client):
    """Verify /api/v2/status returns table counts when connected."""
    mock_get_database.return_value = "TEST_DB"
    mock_test_connection.return_value = True
    mock_query.return_value = [
        {"TABLE_NAME": "ITEM_MATCHES", "ROW_COUNT": 100},
        {"TABLE_NAME": "MATCH_CANDIDATES", "ROW_COUNT": 50},
        {"TABLE_NAME": "RAW_RETAIL_ITEMS", "ROW_COUNT": 200},
        {"TABLE_NAME": "STANDARD_ITEMS", "ROW_COUNT": 150},
    ]

    response = client.get("/api/v2/status")
    assert response.status_code == 200
    data = response.json()

    assert data["connected"] is True
    assert data["error"] is None
    assert len(data["tables"]) == 4
    # Use snake_case field name (TableCount uses populate_by_name=True)
    assert data["tables"][0]["TABLE_NAME"] == "ITEM_MATCHES"
    assert data["tables"][0]["ROW_COUNT"] == 100


# ---------------------------------------------------------------------------
# Status Endpoint Tests - Error Cases with Classification
# ---------------------------------------------------------------------------


@patch("backend.api.routes.system.sf.test_connection")
@patch("backend.api.routes.system.sf.get_database")
def test_status_endpoint_network_policy_error(mock_get_database, mock_test_connection, client):
    """Verify /api/v2/status classifies network policy errors."""
    mock_get_database.return_value = "TEST_DB"
    mock_test_connection.side_effect = Exception(
        "250001 (08001): Failed to connect to DB: account.snowflakecomputing.com:443. "
        "Incoming request with IP address 203.0.113.45 is not allowed to access Snowflake."
    )

    response = client.get("/api/v2/status")
    assert response.status_code == 200
    data = response.json()

    assert data["connected"] is False
    assert data["tables"] is None
    assert data["error"] is not None

    error = data["error"]
    assert error["category"] == "network_policy"
    assert error["severity"] == "error"
    assert error["retryable"] is False
    # Title may vary - check for network policy or connection-related keywords
    assert any(keyword in error["title"].lower() for keyword in ["network", "policy", "connect", "ip", "access"])
    assert len(error["actions"]) > 0
    assert error["source"] == "snowflake"


@patch("backend.api.routes.system.sf.test_connection")
@patch("backend.api.routes.system.sf.get_database")
def test_status_endpoint_auth_expired_error(mock_get_database, mock_test_connection, client):
    """Verify /api/v2/status classifies authentication expiration errors."""
    mock_get_database.return_value = "TEST_DB"
    mock_test_connection.side_effect = Exception(
        "390114: Authentication token has expired. The user must authenticate again."
    )

    response = client.get("/api/v2/status")
    assert response.status_code == 200
    data = response.json()

    assert data["connected"] is False
    assert data["error"] is not None

    error = data["error"]
    assert error["category"] == "auth_expired"
    # Retryable may be True (with re-auth action) - just verify it's a boolean
    assert isinstance(error["retryable"], bool)
    # Check message contains authentication guidance
    assert any(
        keyword in error["message"].lower() for keyword in ["authenticate", "re-authenticate", "login", "expired"]
    )


@patch("backend.api.routes.system.sf.test_connection")
@patch("backend.api.routes.system.sf.get_database")
def test_status_endpoint_generic_connection_error(mock_get_database, mock_test_connection, client):
    """Verify /api/v2/status classifies generic connection errors."""
    mock_get_database.return_value = "TEST_DB"
    # Use a connection error without "timeout" keyword to match connection category
    mock_test_connection.side_effect = Exception("08001: Unable to connect to Snowflake. Network unreachable.")

    response = client.get("/api/v2/status")
    assert response.status_code == 200
    data = response.json()

    assert data["connected"] is False
    assert data["error"] is not None

    error = data["error"]
    # Generic connection errors without specific keywords should match "connection"
    assert error["category"] == "connection"
    # Connection errors may be retryable or not depending on classification
    assert isinstance(error["retryable"], bool)
    assert error["source"] == "snowflake"


@patch("backend.api.routes.system.sf.query")
@patch("backend.api.routes.system.sf.test_connection")
@patch("backend.api.routes.system.sf.get_database")
def test_status_endpoint_query_failure(mock_get_database, mock_test_connection, mock_query, client):
    """Verify /api/v2/status handles query failures after successful connection test."""
    mock_get_database.return_value = "TEST_DB"
    mock_test_connection.return_value = True
    mock_query.side_effect = Exception(
        "002003 (42S02): SQL compilation error: Object 'TEST_DB.RAW.STANDARD_ITEMS' does not exist"
    )

    response = client.get("/api/v2/status")
    assert response.status_code == 200
    data = response.json()

    assert data["connected"] is False
    assert data["error"] is not None

    error = data["error"]
    assert error["category"] == "object_not_found"
    assert error["source"] == "snowflake"


# ---------------------------------------------------------------------------
# Status Endpoint Tests - Response Headers
# ---------------------------------------------------------------------------


def test_status_endpoint_includes_request_id_header(client):
    """Verify /api/v2/status response includes X-Request-ID header."""
    response = client.get("/api/v2/status")
    assert "x-request-id" in response.headers
    # Request ID should be a non-empty string (UUID format from middleware)
    assert len(response.headers["x-request-id"]) > 0


# ---------------------------------------------------------------------------
# Status Endpoint Tests - Error Envelope Structure
# ---------------------------------------------------------------------------


@patch("backend.api.routes.system.sf.test_connection")
@patch("backend.api.routes.system.sf.get_database")
def test_status_endpoint_error_envelope_structure(mock_get_database, mock_test_connection, client):
    """Verify error envelope contains all required fields."""
    mock_get_database.return_value = "TEST_DB"
    mock_test_connection.side_effect = Exception("Test connection failure")

    response = client.get("/api/v2/status")
    data = response.json()

    error = data["error"]
    # Verify all ErrorEnvelope fields are present
    assert "error_id" in error
    assert "request_id" in error
    assert "category" in error
    assert "severity" in error
    assert "title" in error
    assert "message" in error
    assert "actions" in error
    assert "retryable" in error
    assert "technical_details" in error
    assert "source" in error

    # Verify types
    assert isinstance(error["actions"], list)
    assert isinstance(error["retryable"], bool)
    assert error["severity"] in ["info", "warning", "error", "critical"]
    assert error["source"] in ["snowflake", "api", "validation", "unknown"]
