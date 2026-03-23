"""Unit tests for matches API endpoints.

Covers search, filter-options, alternatives, status, and bulk endpoints.
Uses mocked Snowflake queries to test each endpoint independently.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

# Patch the snowflake_client module before importing the app
with patch("backend.api.snowflake_client") as mock_sf:
    mock_sf.get_database.return_value = "HARMONIZER_DEMO"
    mock_sf.query = AsyncMock(return_value=[])
    mock_sf.execute = AsyncMock(return_value="OK")
    mock_sf.test_connection = AsyncMock(return_value=True)
    from backend.api import app

client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_cache():
    """Clear cache before each test to ensure isolation."""
    from backend.services.cache import get_async_cache, get_sync_cache

    async_cache = get_async_cache()
    sync_cache = get_sync_cache()
    async_cache.invalidate()
    sync_cache.invalidate()
    yield
    async_cache.invalidate()
    sync_cache.invalidate()


# ---------------------------------------------------------------------------
# Helper function tests (search.py)
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestSafeFunction:
    """Test the _safe helper function for SQL escaping."""

    def test_safe_escapes_single_quotes(self) -> None:
        """Test that single quotes are doubled."""
        from backend.api.routes.matches.search import _safe

        assert _safe("O'Brien") == "O''Brien"
        assert _safe("test") == "test"
        assert _safe("it's a test's test") == "it''s a test''s test"

    def test_safe_handles_empty_string(self) -> None:
        """Test _safe with empty string."""
        from backend.api.routes.matches.search import _safe

        assert _safe("") == ""

    def test_safe_handles_no_quotes(self) -> None:
        """Test _safe with no quotes to escape."""
        from backend.api.routes.matches.search import _safe

        assert _safe("normal text") == "normal text"


# ---------------------------------------------------------------------------
# GET /api/v2/matches/filter-options Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestFilterOptions:
    """Test GET /api/v2/matches/filter-options endpoint."""

    @patch("backend.api.routes.matches.filter_options.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.filter_options.sf.get_database")
    def test_filter_options_returns_all_fields(self, mock_db, mock_query) -> None:
        """Test filter-options returns sources, categories, subcategories, and static options."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"SOURCE_SYSTEM": "POS_A"}, {"SOURCE_SYSTEM": "POS_B"}],  # sources
            [{"INFERRED_CATEGORY": "Produce"}, {"INFERRED_CATEGORY": "Dairy"}],  # categories
            [  # subcategories
                {"INFERRED_CATEGORY": "Produce", "INFERRED_SUBCATEGORY": "Fruits"},
                {"INFERRED_CATEGORY": "Produce", "INFERRED_SUBCATEGORY": "Vegetables"},
                {"INFERRED_CATEGORY": "Dairy", "INFERRED_SUBCATEGORY": "Milk"},
            ],
        ]

        resp = client.get("/api/v2/matches/filter-options")
        assert resp.status_code == 200
        data = resp.json()

        assert data["sources"] == ["POS_A", "POS_B"]
        assert data["categories"] == ["Produce", "Dairy"]
        assert data["subcategoriesByCategory"]["Produce"] == ["Fruits", "Vegetables"]
        assert data["subcategoriesByCategory"]["Dairy"] == ["Milk"]
        assert data["matchSources"] == ["SEARCH", "COSINE", "EDIT", "JACCARD"]
        assert len(data["agreementLevels"]) == 4
        assert len(data["groupByOptions"]) == 6
        assert "error" not in data or data["error"] is None

    @patch("backend.api.routes.matches.filter_options.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.filter_options.sf.get_database")
    def test_filter_options_handles_empty_results(self, mock_db, mock_query) -> None:
        """Test filter-options handles empty database results."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [[], [], []]  # sources, categories, subcategories

        resp = client.get("/api/v2/matches/filter-options")
        assert resp.status_code == 200
        data = resp.json()

        assert data["sources"] == []
        assert data["categories"] == []
        assert data["subcategoriesByCategory"] == {}
        # Static options should still be present
        assert len(data["matchSources"]) == 4

    @patch("backend.api.routes.matches.filter_options.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.filter_options.sf.get_database")
    def test_filter_options_handles_null_values(self, mock_db, mock_query) -> None:
        """Test filter-options filters out null values."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"SOURCE_SYSTEM": "POS_A"}, {"SOURCE_SYSTEM": None}, {"SOURCE_SYSTEM": ""}],
            [{"INFERRED_CATEGORY": "Produce"}, {"INFERRED_CATEGORY": None}],
            [{"INFERRED_CATEGORY": "Produce", "INFERRED_SUBCATEGORY": "Fruits"}],
        ]

        resp = client.get("/api/v2/matches/filter-options")
        assert resp.status_code == 200
        data = resp.json()

        assert data["sources"] == ["POS_A"]
        assert data["categories"] == ["Produce"]
        assert data["subcategoriesByCategory"]["Produce"] == ["Fruits"]

    @patch("backend.api.routes.matches.filter_options.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.filter_options.sf.get_database")
    def test_filter_options_handles_exception(self, mock_db, mock_query) -> None:
        """Test filter-options returns error on exception."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = Exception("Database connection failed")

        resp = client.get("/api/v2/matches/filter-options")
        assert resp.status_code == 200
        data = resp.json()

        assert data["sources"] == []
        assert data["categories"] == []
        assert data["subcategoriesByCategory"] == {}
        assert "error" in data
        assert "Database connection failed" in data["error"]


# ---------------------------------------------------------------------------
# POST /api/v2/matches/search Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestMatchSearch:
    """Test POST /api/v2/matches/search endpoint."""

    @pytest.fixture
    def sample_match_row(self):
        """Provide a sample match row from database."""
        return {
            "ITEM_ID": "ITEM-001",
            "MATCH_ID": "MATCH-001",
            "RAW_DESCRIPTION": "Organic Apples",
            "STANDARD_DESCRIPTION": "Organic Gala Apples 3lb",
            "SUGGESTED_STANDARD_ID": "STD-001",
            "EFFECTIVE_STATUS": "PENDING",
            "MATCH_STATUS": "PENDING",
            "SOURCE_SYSTEM": "POS_A",
            "INFERRED_CATEGORY": "Produce",
            "INFERRED_SUBCATEGORY": "Fruits",
            "BRAND": "Nature's Best",
            "SRP": 5.99,
            "CORTEX_SEARCH_SCORE": 0.95,
            "COSINE_SCORE": 0.88,
            "EDIT_DISTANCE_SCORE": 0.72,
            "JACCARD_SCORE": 0.81,
            "LLM_SCORE": 0.92,
            "ENSEMBLE_SCORE": 87.5,
            "MATCH_METHOD": "ENSEMBLE",
            "IS_LLM_SKIPPED": False,
            "PRIMARY_MATCH_SOURCE": "SEARCH",
            "MAX_RAW_SCORE": 0.95,
            "AGREEMENT_LEVEL": 4,
            "DUPLICATE_COUNT": 3,
        }

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_returns_paginated_results(self, mock_db, mock_query, sample_match_row) -> None:
        """Test search returns paginated match results."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"TOTAL": 100}],  # Count query
            [sample_match_row],  # Data query
        ]

        resp = client.post("/api/v2/matches/search", json={"page": 1, "pageSize": 25})
        assert resp.status_code == 200
        data = resp.json()

        assert data["total"] == 100
        assert data["page"] == 1
        assert data["pageSize"] == 25
        assert data["totalPages"] == 4
        assert len(data["items"]) == 1

        item = data["items"][0]
        assert item["id"] == "MATCH-001"
        assert item["itemId"] == "ITEM-001"
        assert item["rawName"] == "Organic Apples"
        assert item["matchedName"] == "Organic Gala Apples 3lb"
        assert item["searchScore"] == 0.95
        assert item["ensembleScore"] == 87.5
        assert item["agreementLevel"] == 4
        assert item["boostLevel"] == "4-way (+20%)"
        assert item["boostPercent"] == 20

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_with_status_filter(self, mock_db, mock_query, sample_match_row) -> None:
        """Test search with status filter."""
        mock_db.return_value = "HARMONIZER_DEMO"
        sample_match_row["EFFECTIVE_STATUS"] = "CONFIRMED"
        mock_query.side_effect = [
            [{"TOTAL": 50}],
            [sample_match_row],
        ]

        resp = client.post("/api/v2/matches/search", json={"status": "CONFIRMED"})
        assert resp.status_code == 200
        data = resp.json()

        assert data["total"] == 50
        assert data["items"][0]["status"] == "CONFIRMED"

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_with_source_filter(self, mock_db, mock_query, sample_match_row) -> None:
        """Test search with source filter."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"TOTAL": 25}],
            [sample_match_row],
        ]

        resp = client.post("/api/v2/matches/search", json={"source": "POS_A"})
        assert resp.status_code == 200
        assert resp.json()["total"] == 25

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_with_category_filter(self, mock_db, mock_query, sample_match_row) -> None:
        """Test search with category filter."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"TOTAL": 30}],
            [sample_match_row],
        ]

        resp = client.post("/api/v2/matches/search", json={"category": "Produce"})
        assert resp.status_code == 200
        assert resp.json()["total"] == 30

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_with_match_source_filter(self, mock_db, mock_query, sample_match_row) -> None:
        """Test search with matchSource filter."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"TOTAL": 40}],
            [sample_match_row],
        ]

        resp = client.post("/api/v2/matches/search", json={"matchSource": "SEARCH"})
        assert resp.status_code == 200
        assert resp.json()["total"] == 40

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_ignores_all_filter(self, mock_db, mock_query, sample_match_row) -> None:
        """Test search ignores 'all' and 'All' filter values."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"TOTAL": 100}],
            [sample_match_row],
        ]

        resp = client.post(
            "/api/v2/matches/search",
            json={"status": "all", "source": "All", "category": "all"},
        )
        assert resp.status_code == 200
        assert resp.json()["total"] == 100

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_with_sorting(self, mock_db, mock_query, sample_match_row) -> None:
        """Test search with custom sorting."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"TOTAL": 10}],
            [sample_match_row],
        ]

        resp = client.post(
            "/api/v2/matches/search",
            json={"sortBy": "rawName", "sortOrder": "asc"},
        )
        assert resp.status_code == 200

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_with_groupby_none(self, mock_db, mock_query, sample_match_row) -> None:
        """Test search without grouping (flat list)."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"TOTAL": 100}],
            [sample_match_row],
        ]

        resp = client.post("/api/v2/matches/search", json={"groupBy": "none"})
        assert resp.status_code == 200

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_with_groupby_unique_description(self, mock_db, mock_query, sample_match_row) -> None:
        """Test search with unique_description grouping (default)."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"TOTAL": 50}],  # Distinct count
            [sample_match_row],
        ]

        resp = client.post("/api/v2/matches/search", json={"groupBy": "unique_description"})
        assert resp.status_code == 200
        assert resp.json()["total"] == 50

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_handles_empty_results(self, mock_db, mock_query) -> None:
        """Test search handles empty results gracefully."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"TOTAL": 0}],
            [],
        ]

        resp = client.post("/api/v2/matches/search", json={})
        assert resp.status_code == 200
        data = resp.json()

        assert data["total"] == 0
        assert data["items"] == []
        assert data["totalPages"] == 1

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_handles_exception(self, mock_db, mock_query) -> None:
        """Test search returns error on exception."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = Exception("Query failed")

        resp = client.post("/api/v2/matches/search", json={})
        assert resp.status_code == 200
        data = resp.json()

        assert data["items"] == []
        assert data["total"] == 0
        assert "error" in data
        assert "Query failed" in data["error"]

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_handles_null_scores(self, mock_db, mock_query) -> None:
        """Test search handles null score values."""
        mock_db.return_value = "HARMONIZER_DEMO"
        null_score_row = {
            "ITEM_ID": "ITEM-001",
            "MATCH_ID": None,
            "RAW_DESCRIPTION": "Test Item",
            "STANDARD_DESCRIPTION": None,
            "SUGGESTED_STANDARD_ID": None,
            "EFFECTIVE_STATUS": None,
            "MATCH_STATUS": "PENDING",
            "SOURCE_SYSTEM": "POS_A",
            "INFERRED_CATEGORY": None,
            "INFERRED_SUBCATEGORY": None,
            "BRAND": None,
            "SRP": None,
            "CORTEX_SEARCH_SCORE": None,
            "COSINE_SCORE": None,
            "EDIT_DISTANCE_SCORE": None,
            "JACCARD_SCORE": None,
            "LLM_SCORE": None,
            "ENSEMBLE_SCORE": None,
            "MATCH_METHOD": None,
            "IS_LLM_SKIPPED": None,
            "PRIMARY_MATCH_SOURCE": None,
            "MAX_RAW_SCORE": None,
            "AGREEMENT_LEVEL": None,
            "DUPLICATE_COUNT": None,
        }
        mock_query.side_effect = [
            [{"TOTAL": 1}],
            [null_score_row],
        ]

        resp = client.post("/api/v2/matches/search", json={})
        assert resp.status_code == 200
        data = resp.json()

        assert len(data["items"]) == 1
        item = data["items"][0]
        assert item["searchScore"] == 0
        assert item["ensembleScore"] == 0
        assert item["price"] == 0
        assert item["duplicateCount"] == 1
        assert item["agreementLevel"] == 1

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_pagination_boundary(self, mock_db, mock_query, sample_match_row) -> None:
        """Test search with page beyond total pages."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"TOTAL": 10}],  # Only 10 items
            [],  # No results for page 100
        ]

        resp = client.post("/api/v2/matches/search", json={"page": 100, "pageSize": 25})
        assert resp.status_code == 200
        data = resp.json()

        # Should adjust page to max valid page
        assert data["page"] == 1  # Adjusted from 100 to 1


# ---------------------------------------------------------------------------
# GET /api/v2/matches/{item_id}/alternatives Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestAlternatives:
    """Test GET /api/v2/matches/{item_id}/alternatives endpoint."""

    @patch("backend.api.routes.matches.alternatives.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.alternatives.sf.get_database")
    def test_alternatives_returns_cached_candidates(self, mock_db, mock_query) -> None:
        """Test alternatives returns cached candidates from MATCH_CANDIDATES."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.return_value = [
            {
                "STANDARD_ITEM_ID": "STD-001",
                "STANDARD_DESCRIPTION": "Organic Gala Apples",
                "CANDIDATE_DESCRIPTION": None,
                "BRAND": "Nature's Best",
                "SRP": 5.99,
                "CONFIDENCE_SCORE": 0.95,
                "MATCH_METHOD": "COSINE",
                "RANK": 1,
            },
            {
                "STANDARD_ITEM_ID": "STD-002",
                "STANDARD_DESCRIPTION": "Organic Fuji Apples",
                "CANDIDATE_DESCRIPTION": None,
                "BRAND": "Farm Fresh",
                "SRP": 6.49,
                "CONFIDENCE_SCORE": 0.88,
                "MATCH_METHOD": "SEARCH",
                "RANK": 2,
            },
        ]

        resp = client.get("/api/v2/matches/ITEM-001/alternatives")
        assert resp.status_code == 200
        data = resp.json()

        assert len(data["alternatives"]) == 2
        assert data["alternatives"][0]["standardItemId"] == "STD-001"
        assert data["alternatives"][0]["score"] == 0.95
        assert data["alternatives"][0]["rank"] == 1
        assert "error" not in data or data["error"] is None

    @patch("backend.api.routes.matches.alternatives.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.alternatives.sf.get_database")
    def test_alternatives_fallback_to_live_search(self, mock_db, mock_query) -> None:
        """Test alternatives falls back to live Cortex Search when no cached candidates."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [],  # No cached candidates
            [{"RAW_DESCRIPTION": "Organic Apples"}],  # Raw item lookup
            [
                {
                    "RESULTS": {
                        "results": [
                            {
                                "STANDARD_ITEM_ID": "STD-001",
                                "STANDARD_DESCRIPTION": "Organic Gala Apples",
                                "BRAND": "Nature's Best",
                                "SRP": 5.99,
                                "@scores": {"cosine_similarity": 0.8},
                            }
                        ]
                    }
                }
            ],  # Live search results
        ]

        resp = client.get("/api/v2/matches/ITEM-001/alternatives")
        assert resp.status_code == 200
        data = resp.json()

        assert len(data["alternatives"]) == 1
        assert data["alternatives"][0]["method"] == "Live Search"

    @patch("backend.api.routes.matches.alternatives.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.alternatives.sf.get_database")
    def test_alternatives_handles_no_raw_item(self, mock_db, mock_query) -> None:
        """Test alternatives handles case when raw item not found."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [],  # No cached candidates
            [],  # Raw item not found
        ]

        resp = client.get("/api/v2/matches/NONEXISTENT/alternatives")
        assert resp.status_code == 200
        data = resp.json()

        assert data["alternatives"] == []

    @patch("backend.api.routes.matches.alternatives.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.alternatives.sf.get_database")
    def test_alternatives_handles_exception(self, mock_db, mock_query) -> None:
        """Test alternatives returns error on exception."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = Exception("Database error")

        resp = client.get("/api/v2/matches/ITEM-001/alternatives")
        assert resp.status_code == 200
        data = resp.json()

        assert data["alternatives"] == []
        assert "error" in data
        assert "Database error" in data["error"]

    @patch("backend.api.routes.matches.alternatives.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.alternatives.sf.get_database")
    def test_alternatives_handles_json_string_results(self, mock_db, mock_query) -> None:
        """Test alternatives handles JSON string in RESULTS field."""
        mock_db.return_value = "HARMONIZER_DEMO"
        import json

        mock_query.side_effect = [
            [],  # No cached candidates
            [{"RAW_DESCRIPTION": "Test Item"}],  # Raw item
            [
                {
                    "RESULTS": json.dumps(
                        {
                            "results": [
                                {
                                    "STANDARD_ITEM_ID": "STD-001",
                                    "STANDARD_DESCRIPTION": "Test Standard",
                                    "BRAND": "Brand",
                                    "SRP": 1.99,
                                    "@scores": {"cosine_similarity": 0.9},
                                }
                            ]
                        }
                    )
                }
            ],
        ]

        resp = client.get("/api/v2/matches/ITEM-001/alternatives")
        assert resp.status_code == 200
        data = resp.json()

        assert len(data["alternatives"]) == 1

    @patch("backend.api.routes.matches.alternatives.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.alternatives.sf.get_database")
    def test_alternatives_handles_null_numeric_fields(self, mock_db, mock_query) -> None:
        """Test alternatives handles null numeric fields gracefully."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.return_value = [
            {
                "STANDARD_ITEM_ID": "STD-001",
                "STANDARD_DESCRIPTION": "Test Description",
                "CANDIDATE_DESCRIPTION": None,
                "BRAND": None,
                "SRP": None,
                "CONFIDENCE_SCORE": None,
                "MATCH_METHOD": "SEARCH",  # Required string field
                "RANK": None,
            },
        ]

        resp = client.get("/api/v2/matches/ITEM-001/alternatives")
        assert resp.status_code == 200
        data = resp.json()

        alt = data["alternatives"][0]
        assert alt["description"] == "Test Description"
        assert alt["brand"] == ""
        assert alt["price"] == 0
        assert alt["score"] == 0
        assert alt["rank"] == 0


# ---------------------------------------------------------------------------
# POST /api/v2/matches/{match_id}/status Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestStatusUpdate:
    """Test POST /api/v2/matches/{match_id}/status endpoint."""

    @patch("backend.api.routes.matches.status.sf.execute", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.status.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.status.sf.get_database")
    def test_status_update_single_item(self, mock_db, mock_query, mock_execute) -> None:
        """Test status update for a single item."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.return_value = [
            {
                "RAW_ITEM_ID": "ITEM-001",
                "SUGGESTED_STANDARD_ID": "STD-001",
                "NORMALIZED_DESCRIPTION": "ORGANIC APPLES",
            }
        ]
        mock_execute.return_value = "OK"

        resp = client.post(
            "/api/v2/matches/MATCH-001/status",
            json={"status": "CONFIRMED", "updateRelated": False},
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["success"] is True
        assert data["matchId"] == "MATCH-001"
        assert data["status"] == "CONFIRMED"
        assert data["updatedCount"] == 1

    @patch("backend.api.routes.matches.status.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.status.sf.get_database")
    def test_status_update_with_related(self, mock_db, mock_query) -> None:
        """Test status update with related items."""
        mock_db.return_value = "HARMONIZER_DEMO"
        # Mock stored procedure response with propagated items
        mock_query.return_value = [
            {
                "SUBMIT_REVIEW": {
                    "status": "success",
                    "rows_updated": 1,
                    "propagated_items": 4,
                }
            }
        ]

        resp = client.post(
            "/api/v2/matches/MATCH-001/status",
            json={"status": "CONFIRMED", "updateRelated": True},
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["success"] is True
        assert data["updatedCount"] == 5  # rows_updated + propagated_items
        assert data["variantCount"] == 2  # 1 + 1 (propagated > 0)

    def test_status_update_missing_status(self) -> None:
        """Test status update fails without status parameter."""
        resp = client.post("/api/v2/matches/MATCH-001/status", json={})
        # Pydantic validation fails with 422 when status is missing
        assert resp.status_code == 422

    @patch("backend.api.routes.matches.status.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.status.sf.get_database")
    def test_status_update_match_not_found(self, mock_db, mock_query) -> None:
        """Test status update fails when stored procedure returns empty result."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.return_value = []  # No response from stored procedure

        resp = client.post(
            "/api/v2/matches/NONEXISTENT/status",
            json={"status": "CONFIRMED"},
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["success"] is False
        assert "No response from stored procedure" in data["error"]

    @patch("backend.api.routes.matches.status.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.status.sf.get_database")
    def test_status_update_handles_exception(self, mock_db, mock_query) -> None:
        """Test status update returns error on exception."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = Exception("Update failed")

        resp = client.post(
            "/api/v2/matches/MATCH-001/status",
            json={"status": "CONFIRMED"},
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["success"] is False
        assert "Update failed" in data["error"]


# ---------------------------------------------------------------------------
# POST /api/v2/matches/bulk Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestBulkAction:
    """Test POST /api/v2/matches/bulk endpoint."""

    @patch("backend.api.routes.matches.bulk.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.bulk.sf.get_database")
    def test_bulk_accept(self, mock_db, mock_query) -> None:
        """Test bulk accept action."""
        mock_db.return_value = "HARMONIZER_DEMO"
        # Mock stored procedure response
        mock_query.return_value = [
            {
                "BULK_SUBMIT_REVIEW": {
                    "status": "success",
                    "success_count": 3,
                    "propagated_total": 0,
                }
            }
        ]

        resp = client.post(
            "/api/v2/matches/bulk",
            json={"action": "accept", "ids": ["M1", "M2", "M3"]},
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["success"] is True
        assert data["updated"] == 3

    @patch("backend.api.routes.matches.bulk.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.bulk.sf.get_database")
    def test_bulk_reject(self, mock_db, mock_query) -> None:
        """Test bulk reject action."""
        mock_db.return_value = "HARMONIZER_DEMO"
        # Mock stored procedure response
        mock_query.return_value = [
            {
                "BULK_SUBMIT_REVIEW": {
                    "status": "success",
                    "success_count": 2,
                    "propagated_total": 0,
                }
            }
        ]

        resp = client.post(
            "/api/v2/matches/bulk",
            json={"action": "reject", "ids": ["M1", "M2"]},
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["success"] is True
        assert data["updated"] == 2

    def test_bulk_no_ids(self) -> None:
        """Test bulk action fails without IDs."""
        resp = client.post(
            "/api/v2/matches/bulk",
            json={"action": "accept", "ids": []},
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["success"] is False
        assert "No IDs provided" in data["error"]

    def test_bulk_missing_ids(self) -> None:
        """Test bulk action fails when ids field is missing."""
        resp = client.post(
            "/api/v2/matches/bulk",
            json={"action": "accept"},
        )
        # FastAPI returns 422 for missing required field
        assert resp.status_code == 422

    @patch("backend.api.routes.matches.bulk.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.bulk.sf.get_database")
    def test_bulk_handles_exception(self, mock_db, mock_query) -> None:
        """Test bulk action returns error on exception."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = Exception("Bulk update failed")

        resp = client.post(
            "/api/v2/matches/bulk",
            json={"action": "accept", "ids": ["M1"]},
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["success"] is False
        assert "Bulk update failed" in data["error"]


# ---------------------------------------------------------------------------
# Integration Tests - Multiple filters combined
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestSearchIntegration:
    """Test search endpoint with multiple filters combined."""

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_with_all_filters(self, mock_db, mock_query) -> None:
        """Test search with all filters applied."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"TOTAL": 5}],
            [
                {
                    "ITEM_ID": "I1",
                    "MATCH_ID": "M1",
                    "RAW_DESCRIPTION": "Test",
                    "STANDARD_DESCRIPTION": "Test Standard",
                    "SUGGESTED_STANDARD_ID": "S1",
                    "EFFECTIVE_STATUS": "PENDING",
                    "MATCH_STATUS": "PENDING",
                    "SOURCE_SYSTEM": "POS_A",
                    "INFERRED_CATEGORY": "Produce",
                    "INFERRED_SUBCATEGORY": "Fruits",
                    "BRAND": "Brand",
                    "SRP": 1.99,
                    "CORTEX_SEARCH_SCORE": 0.9,
                    "COSINE_SCORE": 0.8,
                    "EDIT_DISTANCE_SCORE": 0.7,
                    "JACCARD_SCORE": 0.6,
                    "LLM_SCORE": 0.5,
                    "ENSEMBLE_SCORE": 75.0,
                    "MATCH_METHOD": "ENSEMBLE",
                    "IS_LLM_SKIPPED": False,
                    "PRIMARY_MATCH_SOURCE": "SEARCH",
                    "MAX_RAW_SCORE": 0.9,
                    "AGREEMENT_LEVEL": 3,
                    "DUPLICATE_COUNT": 2,
                }
            ],
        ]

        resp = client.post(
            "/api/v2/matches/search",
            json={
                "page": 1,
                "pageSize": 10,
                "status": "PENDING",
                "source": "POS_A",
                "category": "Produce",
                "matchSource": "SEARCH",
                "sortBy": "score",
                "sortOrder": "desc",
                "groupBy": "unique_description",
            },
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["total"] == 5
        assert len(data["items"]) == 1

    @patch("backend.api.routes.matches.search.sf.query", new_callable=AsyncMock)
    @patch("backend.api.routes.matches.search.sf.get_database")
    def test_search_sql_injection_prevention(self, mock_db, mock_query) -> None:
        """Test search escapes SQL injection attempts."""
        mock_db.return_value = "HARMONIZER_DEMO"
        mock_query.side_effect = [
            [{"TOTAL": 0}],
            [],
        ]

        # Attempt SQL injection in filter values
        resp = client.post(
            "/api/v2/matches/search",
            json={
                "status": "'; DROP TABLE users; --",
                "source": "test' OR '1'='1",
            },
        )
        assert resp.status_code == 200
        # Should not crash and should handle safely
        data = resp.json()
        assert "items" in data
