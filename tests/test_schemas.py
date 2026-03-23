"""Tests for Pydantic schemas in backend/api/schemas/matches.py.

Covers model instantiation, field validation, serialization, and edge cases.
"""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from backend.api.schemas.matches import (
    AgreementLevelOption,
    AlternativeMatch,
    AlternativesResponse,
    BoostLevelOption,
    BulkActionRequest,
    BulkActionResponse,
    FilterOptionsResponse,
    GroupByOption,
    MatchItem,
    MatchSearchRequest,
    MatchSearchResponse,
    StatusUpdateRequest,
    StatusUpdateResponse,
)

# ---------------------------------------------------------------------------
# MatchSearchRequest Tests
# ---------------------------------------------------------------------------


class TestMatchSearchRequest:
    """Test MatchSearchRequest model validation and defaults."""

    def test_defaults(self) -> None:
        """Test default values are applied correctly."""
        request = MatchSearchRequest()
        assert request.page == 1
        assert request.pageSize == 25
        assert request.status is None
        assert request.source is None
        assert request.category is None
        assert request.matchSource is None
        assert request.sortBy == "ensemble_score"
        assert request.sortOrder == "desc"
        assert request.groupBy == "unique_description"

    def test_custom_values(self) -> None:
        """Test model accepts custom valid values."""
        request = MatchSearchRequest(
            page=5,
            pageSize=50,
            status="CONFIRMED",
            source="POS_SYSTEM_A",
            category="Beverages",
            matchSource="CORTEX_SEARCH",
            sortBy="score",
            sortOrder="asc",
            groupBy="none",
        )
        assert request.page == 5
        assert request.pageSize == 50
        assert request.status == "CONFIRMED"
        assert request.source == "POS_SYSTEM_A"
        assert request.category == "Beverages"
        assert request.matchSource == "CORTEX_SEARCH"
        assert request.sortBy == "score"
        assert request.sortOrder == "asc"
        assert request.groupBy == "none"

    def test_page_minimum_validation(self) -> None:
        """Test page must be >= 1."""
        with pytest.raises(ValidationError) as exc_info:
            MatchSearchRequest(page=0)
        assert "greater than or equal to 1" in str(exc_info.value)

    def test_page_size_minimum_validation(self) -> None:
        """Test pageSize must be >= 1."""
        with pytest.raises(ValidationError) as exc_info:
            MatchSearchRequest(pageSize=0)
        assert "greater than or equal to 1" in str(exc_info.value)

    def test_page_size_maximum_validation(self) -> None:
        """Test pageSize must be <= 100."""
        with pytest.raises(ValidationError) as exc_info:
            MatchSearchRequest(pageSize=101)
        assert "less than or equal to 100" in str(exc_info.value)

    def test_sort_order_literal_validation(self) -> None:
        """Test sortOrder must be 'asc' or 'desc'."""
        with pytest.raises(ValidationError) as exc_info:
            MatchSearchRequest(sortOrder="invalid")  # type: ignore[arg-type]
        assert "Input should be 'asc' or 'desc'" in str(exc_info.value)

    def test_serialization(self) -> None:
        """Test model serializes to dict correctly."""
        request = MatchSearchRequest(page=2, status="PENDING")
        data = request.model_dump()
        assert data["page"] == 2
        assert data["status"] == "PENDING"
        assert data["sortBy"] == "ensemble_score"

    def test_json_serialization(self) -> None:
        """Test model serializes to JSON correctly."""
        request = MatchSearchRequest(page=3, category="Produce")
        json_str = request.model_dump_json()
        assert '"page":3' in json_str or '"page": 3' in json_str
        assert '"category":"Produce"' in json_str or '"category": "Produce"' in json_str


# ---------------------------------------------------------------------------
# MatchItem Tests
# ---------------------------------------------------------------------------


class TestMatchItem:
    """Test MatchItem model validation."""

    @pytest.fixture
    def valid_match_item_data(self):
        """Provide valid data for MatchItem."""
        return {
            "id": "row-123",
            "itemId": "ITEM-456",
            "matchId": "MATCH-789",
            "rawName": "Organic Apples 3lb",
            "matchedName": "Organic Gala Apples 3 lb Bag",
            "standardItemId": "STD-001",
            "status": "PENDING",
            "source": "POS_SYSTEM_A",
            "category": "Produce",
            "subcategory": "Fruits",
            "brand": "Organic Valley",
            "price": 5.99,
            "searchScore": 0.95,
            "cosineScore": 0.88,
            "editScore": 0.72,
            "jaccardScore": 0.81,
            "ensembleScore": 87.5,
            "maxRawScore": 0.95,
            "score": 87.5,
            "matchSource": "CORTEX_SEARCH",
            "matchMethod": "ENSEMBLE",
            "agreementLevel": 4,
            "boostLevel": "HIGH",
            "boostPercent": 15,
            "duplicateCount": 3,
            "createdAt": "2024-01-15T10:30:00Z",
        }

    def test_valid_match_item(self, valid_match_item_data) -> None:
        """Test creating a valid MatchItem."""
        item = MatchItem(**valid_match_item_data)
        assert item.id == "row-123"
        assert item.rawName == "Organic Apples 3lb"
        assert item.ensembleScore == 87.5

    def test_missing_required_field(self, valid_match_item_data) -> None:
        """Test that missing required fields raise ValidationError."""
        del valid_match_item_data["id"]
        with pytest.raises(ValidationError) as exc_info:
            MatchItem(**valid_match_item_data)
        assert "id" in str(exc_info.value)

    def test_serialization(self, valid_match_item_data) -> None:
        """Test MatchItem serializes correctly."""
        item = MatchItem(**valid_match_item_data)
        data = item.model_dump()
        assert data["id"] == "row-123"
        assert data["price"] == 5.99
        assert data["agreementLevel"] == 4


# ---------------------------------------------------------------------------
# MatchSearchResponse Tests
# ---------------------------------------------------------------------------


class TestMatchSearchResponse:
    """Test MatchSearchResponse model."""

    @pytest.fixture
    def match_item_data(self):
        """Minimal valid MatchItem data."""
        return {
            "id": "1",
            "itemId": "I1",
            "matchId": "M1",
            "rawName": "Test",
            "matchedName": "Test Item",
            "standardItemId": "S1",
            "status": "PENDING",
            "source": "SRC",
            "category": "Cat",
            "subcategory": "Sub",
            "brand": "Brand",
            "price": 1.0,
            "searchScore": 0.9,
            "cosineScore": 0.8,
            "editScore": 0.7,
            "jaccardScore": 0.6,
            "llmScore": 0.5,
            "ensembleScore": 80.0,
            "maxRawScore": 0.9,
            "score": 80.0,
            "matchSource": "CORTEX_SEARCH",
            "matchMethod": "ENSEMBLE",
            "agreementLevel": 3,
            "boostLevel": "MEDIUM",
            "boostPercent": 10,
            "duplicateCount": 1,
            "isLlmSkipped": False,
            "createdAt": "2024-01-01T00:00:00Z",
        }

    def test_valid_response(self, match_item_data) -> None:
        """Test valid MatchSearchResponse."""
        response = MatchSearchResponse(
            items=[MatchItem(**match_item_data)],
            total=100,
            page=1,
            pageSize=25,
            totalPages=4,
        )
        assert len(response.items) == 1
        assert response.total == 100
        assert response.error is None

    def test_empty_items(self) -> None:
        """Test response with empty items list."""
        response = MatchSearchResponse(
            items=[],
            total=0,
            page=1,
            pageSize=25,
            totalPages=0,
        )
        assert response.items == []
        assert response.total == 0

    def test_with_error(self) -> None:
        """Test response with error field set."""
        response = MatchSearchResponse(
            items=[],
            total=0,
            page=1,
            pageSize=25,
            totalPages=0,
            error="Database connection failed",
        )
        assert response.error == "Database connection failed"


# ---------------------------------------------------------------------------
# BoostLevelOption and GroupByOption Tests
# ---------------------------------------------------------------------------


class TestFilterOptions:
    """Test filter option models."""

    def test_boost_level_option(self) -> None:
        """Test BoostLevelOption model."""
        option = BoostLevelOption(value="HIGH", label="High Confidence")
        assert option.value == "HIGH"
        assert option.label == "High Confidence"

    def test_group_by_option(self) -> None:
        """Test GroupByOption model."""
        option = GroupByOption(value="unique_description", label="Group Duplicates")
        assert option.value == "unique_description"
        assert option.label == "Group Duplicates"

    def test_filter_options_response(self) -> None:
        """Test FilterOptionsResponse model."""
        response = FilterOptionsResponse(
            sources=["POS_A", "POS_B"],
            categories=["Produce", "Dairy"],
            subcategoriesByCategory={"Produce": ["Apples", "Bananas"], "Dairy": ["Milk", "Cheese"]},
            matchSources=["CORTEX_SEARCH", "COSINE"],
            agreementLevels=[
                AgreementLevelOption(value="4", label="4-way"),
                AgreementLevelOption(value="3", label="3-way"),
            ],
            groupByOptions=[
                GroupByOption(value="unique_description", label="Group"),
                GroupByOption(value="none", label="No Group"),
            ],
        )
        assert len(response.sources) == 2
        assert len(response.agreementLevels) == 2
        assert response.error is None

    def test_filter_options_with_error(self) -> None:
        """Test FilterOptionsResponse with error."""
        response = FilterOptionsResponse(
            sources=[],
            categories=[],
            subcategoriesByCategory={},
            matchSources=[],
            agreementLevels=[],
            groupByOptions=[],
            error="Failed to load options",
        )
        assert response.error == "Failed to load options"


# ---------------------------------------------------------------------------
# AlternativeMatch and AlternativesResponse Tests
# ---------------------------------------------------------------------------


class TestAlternatives:
    """Test alternative match models."""

    def test_alternative_match(self) -> None:
        """Test AlternativeMatch model."""
        alt = AlternativeMatch(
            standardItemId="STD-002",
            description="Organic Fuji Apples 3 lb",
            brand="Nature's Best",
            price=6.49,
            score=0.85,
            method="COSINE",
            rank=2,
        )
        assert alt.standardItemId == "STD-002"
        assert alt.score == 0.85
        assert alt.rank == 2

    def test_alternatives_response(self) -> None:
        """Test AlternativesResponse with alternatives."""
        response = AlternativesResponse(
            alternatives=[
                AlternativeMatch(
                    standardItemId="S1",
                    description="Item 1",
                    brand="B1",
                    price=1.0,
                    score=0.9,
                    method="SEARCH",
                    rank=1,
                ),
                AlternativeMatch(
                    standardItemId="S2",
                    description="Item 2",
                    brand="B2",
                    price=2.0,
                    score=0.8,
                    method="COSINE",
                    rank=2,
                ),
            ]
        )
        assert len(response.alternatives) == 2
        assert response.error is None

    def test_alternatives_response_empty(self) -> None:
        """Test AlternativesResponse with no alternatives."""
        response = AlternativesResponse(alternatives=[])
        assert response.alternatives == []

    def test_alternatives_response_with_error(self) -> None:
        """Test AlternativesResponse with error."""
        response = AlternativesResponse(alternatives=[], error="Item not found")
        assert response.error == "Item not found"


# ---------------------------------------------------------------------------
# BulkActionRequest and BulkActionResponse Tests
# ---------------------------------------------------------------------------


class TestBulkAction:
    """Test bulk action models."""

    def test_bulk_action_request_accept(self) -> None:
        """Test BulkActionRequest with accept action."""
        request = BulkActionRequest(
            ids=["id1", "id2", "id3"],
            action="accept",
        )
        assert len(request.ids) == 3
        assert request.action == "accept"

    def test_bulk_action_request_reject(self) -> None:
        """Test BulkActionRequest with reject action."""
        request = BulkActionRequest(
            ids=["id1"],
            action="reject",
        )
        assert request.action == "reject"

    def test_bulk_action_request_invalid_action(self) -> None:
        """Test BulkActionRequest rejects invalid action."""
        with pytest.raises(ValidationError) as exc_info:
            BulkActionRequest(ids=["id1"], action="invalid")  # type: ignore[arg-type]
        assert "Input should be 'accept' or 'reject'" in str(exc_info.value)

    def test_bulk_action_response_success(self) -> None:
        """Test BulkActionResponse success case."""
        response = BulkActionResponse(success=True, updated=5)
        assert response.success is True
        assert response.updated == 5
        assert response.error is None

    def test_bulk_action_response_failure(self) -> None:
        """Test BulkActionResponse failure case."""
        response = BulkActionResponse(success=False, error="Permission denied")
        assert response.success is False
        assert response.updated is None
        assert response.error == "Permission denied"


# ---------------------------------------------------------------------------
# StatusUpdateRequest and StatusUpdateResponse Tests
# ---------------------------------------------------------------------------


class TestStatusUpdate:
    """Test status update models."""

    def test_status_update_request_defaults(self) -> None:
        """Test StatusUpdateRequest default values."""
        request = StatusUpdateRequest(status="CONFIRMED")
        assert request.status == "CONFIRMED"
        assert request.updateRelated is False

    def test_status_update_request_with_related(self) -> None:
        """Test StatusUpdateRequest with updateRelated=True."""
        request = StatusUpdateRequest(status="REJECTED", updateRelated=True)
        assert request.status == "REJECTED"
        assert request.updateRelated is True

    def test_status_update_response_success(self) -> None:
        """Test StatusUpdateResponse success case."""
        response = StatusUpdateResponse(
            success=True,
            matchId="M123",
            status="CONFIRMED",
            updatedCount=1,
            variantCount=5,
        )
        assert response.success is True
        assert response.matchId == "M123"
        assert response.status == "CONFIRMED"
        assert response.updatedCount == 1
        assert response.variantCount == 5
        assert response.error is None

    def test_status_update_response_with_error(self) -> None:
        """Test StatusUpdateResponse with error."""
        response = StatusUpdateResponse(success=False, error="Match not found")
        assert response.success is False
        assert response.error == "Match not found"

    def test_status_update_response_minimal(self) -> None:
        """Test StatusUpdateResponse with minimal fields."""
        response = StatusUpdateResponse(success=True)
        assert response.success is True
        assert response.matchId is None
        assert response.status is None
        assert response.updatedCount is None
        assert response.variantCount is None


# ---------------------------------------------------------------------------
# Edge Cases and Serialization Tests
# ---------------------------------------------------------------------------


class TestEdgeCases:
    """Test edge cases and JSON serialization."""

    def test_match_search_request_boundary_values(self) -> None:
        """Test boundary values for page and pageSize."""
        # Minimum valid values
        request = MatchSearchRequest(page=1, pageSize=1)
        assert request.page == 1
        assert request.pageSize == 1

        # Maximum valid pageSize
        request = MatchSearchRequest(pageSize=100)
        assert request.pageSize == 100

    def test_match_item_special_characters(self) -> None:
        """Test MatchItem handles special characters in strings."""
        data = {
            "id": "1",
            "itemId": "I1",
            "matchId": "M1",
            "rawName": "O'Brien's \"Special\" Sauce & More",
            "matchedName": "Special Sauce <test>",
            "standardItemId": "S1",
            "status": "PENDING",
            "source": "SRC",
            "category": "Condiments/Sauces",
            "subcategory": "Sub",
            "brand": "O'Brien's",
            "price": 1.0,
            "searchScore": 0.9,
            "cosineScore": 0.8,
            "editScore": 0.7,
            "jaccardScore": 0.6,
            "llmScore": 0.5,
            "ensembleScore": 80.0,
            "maxRawScore": 0.9,
            "score": 80.0,
            "matchSource": "CORTEX_SEARCH",
            "matchMethod": "ENSEMBLE",
            "agreementLevel": 3,
            "boostLevel": "MEDIUM",
            "boostPercent": 10,
            "duplicateCount": 1,
            "isLlmSkipped": False,
            "createdAt": "2024-01-01T00:00:00Z",
        }
        item = MatchItem(**data)
        assert "O'Brien" in item.rawName
        assert '"Special"' in item.rawName

    def test_model_from_dict_and_back(self) -> None:
        """Test round-trip serialization."""
        original = MatchSearchRequest(
            page=5,
            pageSize=50,
            status="CONFIRMED",
            sortOrder="asc",
        )
        data = original.model_dump()
        restored = MatchSearchRequest(**data)
        assert restored.page == original.page
        assert restored.pageSize == original.pageSize
        assert restored.status == original.status
        assert restored.sortOrder == original.sortOrder

    def test_json_round_trip(self) -> None:
        """Test JSON serialization round trip."""
        original = BulkActionRequest(ids=["a", "b", "c"], action="accept")
        json_str = original.model_dump_json()
        restored = BulkActionRequest.model_validate_json(json_str)
        assert restored.ids == original.ids
        assert restored.action == original.action
