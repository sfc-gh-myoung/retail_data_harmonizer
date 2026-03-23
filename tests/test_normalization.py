"""Tests for enhanced normalization engine (T84).

Tests the APPLY_NORMALIZATION_RULES UDF and rule management procedures.
Uses mocked Snowpark session to test normalization logic without requiring
a real Snowflake connection.
"""

from __future__ import annotations

import pytest

from tests.mocks.normalization import MockNormalizationEngine, MockSession


@pytest.fixture
def mock_session() -> MockSession:
    """Provide a mock Snowpark session for normalization tests."""
    return MockSession()


# ---------------------------------------------------------------------------
# Test Classes
# ---------------------------------------------------------------------------


class TestNormalizationRules:
    """Test normalization rules table and management."""

    def test_normalization_rules_table_exists(self, mock_session) -> None:
        """Verify NORMALIZATION_RULES table exists with correct schema."""
        result = mock_session.sql("""
            SELECT COUNT(*) AS CNT
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = 'HARMONIZED'
              AND TABLE_NAME = 'NORMALIZATION_RULES'
        """).collect()

        assert result[0]["CNT"] >= 10, "NORMALIZATION_RULES should have expected columns"

    def test_seed_rules_loaded(self, mock_session) -> None:
        """Verify seed rules are populated."""
        result = mock_session.sql("""
            SELECT COUNT(*) AS RULE_COUNT
            FROM HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES
            WHERE IS_ACTIVE = TRUE
        """).collect()

        assert result[0]["RULE_COUNT"] >= 20, "Should have at least 20 seed rules"

    def test_rule_types_present(self, mock_session) -> None:
        """Verify all expected rule types are present."""
        result = mock_session.sql("""
            SELECT DISTINCT RULE_TYPE
            FROM HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES
            ORDER BY RULE_TYPE
        """).collect()

        rule_types = [row["RULE_TYPE"] for row in result]
        expected_types = ["ABBREVIATION", "BRAND", "PUNCTUATION", "UNIT", "VARIANT", "WHITESPACE"]

        for expected in expected_types:
            assert expected in rule_types, f"Expected rule type {expected} not found"


class TestNormalizationUDF:
    """Test APPLY_NORMALIZATION_RULES UDF functionality."""

    def test_udf_exists(self, mock_session) -> None:
        """Verify UDF is callable."""
        result = mock_session.sql("""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES('TEST') AS RESULT
        """).collect()

        assert result[0]["RESULT"] is not None

    def test_basic_uppercase(self, mock_session) -> None:
        """Test basic uppercase conversion."""
        result = mock_session.sql("""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES('hello world') AS RESULT
        """).collect()

        assert result[0]["RESULT"].isupper(), "Output should be uppercase"

    def test_whitespace_normalization(self, mock_session) -> None:
        """Test multiple spaces collapsed to single space."""
        result = mock_session.sql("""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES('hello    world') AS RESULT
        """).collect()

        assert "  " not in result[0]["RESULT"], "Multiple spaces should be collapsed"

    def test_abbreviation_expansion_oz(self, mock_session) -> None:
        """Test OZ abbreviation expansion."""
        result = mock_session.sql("""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES('WATER 20 OZ BOTTLE') AS RESULT
        """).collect()

        # After unit standardization, should contain normalized form
        assert result[0]["RESULT"] is not None

    def test_brand_standardization_coca_cola(self, mock_session) -> None:
        """Test Coca-Cola brand standardization."""
        result = mock_session.sql("""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES('COKE CL 12PK') AS RESULT
        """).collect()

        assert "COCA-COLA" in result[0]["RESULT"], "COKE CL should expand to COCA-COLA"

    def test_brand_standardization_mountain_dew(self, mock_session) -> None:
        """Test Mountain Dew brand standardization."""
        result = mock_session.sql("""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES('MTN DEW 20OZ') AS RESULT
        """).collect()

        assert "MOUNTAIN DEW" in result[0]["RESULT"], "MTN DEW should expand to MOUNTAIN DEW"

    def test_brand_standardization_gatorade(self, mock_session) -> None:
        """Test Gatorade abbreviation expansion."""
        result = mock_session.sql("""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES('GTRD FRT PNCH 20Z') AS RESULT
        """).collect()

        assert "GATORADE" in result[0]["RESULT"], "GTRD should expand to GATORADE"

    def test_null_handling(self, mock_session) -> None:
        """Test NULL input returns NULL."""
        result = mock_session.sql("""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES(NULL) AS RESULT
        """).collect()

        assert result[0]["RESULT"] is None, "NULL input should return NULL"

    def test_empty_string(self, mock_session) -> None:
        """Test empty string handling."""
        result = mock_session.sql("""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES('') AS RESULT
        """).collect()

        assert result[0]["RESULT"] == "", "Empty string should return empty string"

    def test_leading_trailing_whitespace_trim(self, mock_session) -> None:
        """Test leading and trailing whitespace is trimmed."""
        result = mock_session.sql("""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES('  HELLO WORLD  ') AS RESULT
        """).collect()

        output = result[0]["RESULT"]
        assert not output.startswith(" "), "Leading whitespace should be trimmed"
        assert not output.endswith(" "), "Trailing whitespace should be trimmed"


class TestNormalizationProcedures:
    """Test normalization management procedures."""

    def test_add_rule_procedure(self, mock_session) -> None:
        """Test ADD_NORMALIZATION_RULE procedure."""
        # Add a test rule
        result = mock_session.sql("""
            CALL HARMONIZER_DEMO.HARMONIZED.ADD_NORMALIZATION_RULE(
                'ABBREVIATION',
                'TESTABBR',
                'TEST ABBREVIATION',
                99,
                FALSE,
                'Test rule for unit testing'
            )
        """).collect()

        assert "successfully" in result[0][0].lower()

        # Verify rule was added
        verify = mock_session.sql("""
            SELECT COUNT(*) AS CNT
            FROM HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES
            WHERE PATTERN = 'TESTABBR'
        """).collect()

        assert verify[0]["CNT"] >= 1, "Test rule should be added"

    def test_toggle_rule_procedure(self, mock_session) -> None:
        """Test TOGGLE_NORMALIZATION_RULE procedure."""
        # Get a rule to toggle
        rule = mock_session.sql("""
            SELECT RULE_ID, IS_ACTIVE
            FROM HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES
            LIMIT 1
        """).collect()

        rule_id = rule[0]["RULE_ID"]
        original_status = rule[0]["IS_ACTIVE"]

        # Toggle off
        mock_session.sql(f"""
            CALL HARMONIZER_DEMO.HARMONIZED.TOGGLE_NORMALIZATION_RULE('{rule_id}', FALSE)
        """).collect()

        # Verify toggled
        check = mock_session.sql(f"""
            SELECT IS_ACTIVE
            FROM HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES
            WHERE RULE_ID = '{rule_id}'
        """).collect()

        assert check[0]["IS_ACTIVE"] is False, "Rule should be deactivated"

        # Restore original status
        mock_session.sql(f"""
            CALL HARMONIZER_DEMO.HARMONIZED.TOGGLE_NORMALIZATION_RULE('{rule_id}', {original_status})
        """).collect()

    def test_export_rules_procedure(self, mock_session) -> None:
        """Test EXPORT_NORMALIZATION_RULES procedure."""
        result = mock_session.sql("""
            CALL HARMONIZER_DEMO.HARMONIZED.EXPORT_NORMALIZATION_RULES()
        """).collect()

        # Result should be a VARIANT containing an array
        assert result[0][0] is not None, "Export should return data"

    def test_test_normalization_procedure(self, mock_session) -> None:
        """Test TEST_NORMALIZATION procedure."""
        result = mock_session.sql("""
            CALL HARMONIZER_DEMO.HARMONIZED.TEST_NORMALIZATION('GTRD FRT PNCH')
        """).collect()

        output = result[0][0]
        assert "Input:" in output, "Should contain input text"
        assert "Output:" in output, "Should contain output text"
        assert "GATORADE" in output, "Output should contain expanded brand"


class TestDeduplicationIntegration:
    """Test integration with DEDUPLICATE_RAW_ITEMS procedure."""

    def test_dedup_uses_enhanced_normalization(self, mock_session) -> None:
        """Test that dedup procedure detects enhanced normalization."""
        # Insert test item with abbreviations
        mock_session.sql("""
            INSERT INTO HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
                (ITEM_ID, RAW_DESCRIPTION, SOURCE_SYSTEM, MATCH_STATUS, CREATED_AT, UPDATED_AT)
            SELECT
                UUID_STRING(),
                'TEST NORM GTRD FRT PNCH 20Z',
                'TEST_SYSTEM',
                'PENDING',
                CURRENT_TIMESTAMP(),
                CURRENT_TIMESTAMP()
        """).collect()

        # Run dedup
        result = mock_session.sql("""
            CALL HARMONIZER_DEMO.HARMONIZED.DEDUPLICATE_RAW_ITEMS()
        """).collect()

        output = result[0][0]
        assert "enhanced_norm" in output.lower(), "Should report enhanced normalization status"


class TestNormalizationEdgeCases:
    """Test edge cases and special characters."""

    def test_special_characters_handling(self, mock_session) -> None:
        """Test handling of special characters."""
        result = mock_session.sql("""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES(
                'PRODUCT (12PK) [NEW] #123'
            ) AS RESULT
        """).collect()

        output = result[0]["RESULT"]
        # Parentheses and brackets should be removed based on rules
        assert "(" not in output and ")" not in output, "Parentheses should be handled"

    def test_multiple_spaces_and_punctuation(self, mock_session) -> None:
        """Test combination of multiple spaces and punctuation."""
        result = mock_session.sql("""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES(
                '  COCA   COLA,  12  PK;  12  OZ  '
            ) AS RESULT
        """).collect()

        output = result[0]["RESULT"]
        assert "  " not in output, "Multiple spaces should be collapsed"
        assert not output.startswith(" "), "Should be trimmed"
        assert not output.endswith(" "), "Should be trimmed"

    def test_unicode_handling(self, mock_session) -> None:
        """Test handling of unicode characters."""
        result = mock_session.sql("""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES('CAFE LATTE') AS RESULT
        """).collect()

        # Should handle basic ASCII without issues
        assert result[0]["RESULT"] is not None

    def test_very_long_string(self, mock_session) -> None:
        """Test handling of very long strings."""
        long_text = "PRODUCT " * 50  # 400+ characters
        safe_text = long_text.replace("'", "''")

        result = mock_session.sql(f"""
            SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES('{safe_text}') AS RESULT
        """).collect()

        assert result[0]["RESULT"] is not None, "Should handle long strings"


# ---------------------------------------------------------------------------
# Additional Unit Tests for MockNormalizationEngine
# ---------------------------------------------------------------------------


class TestMockNormalizationEngine:
    """Test the mock normalization engine directly."""

    def test_apply_rules_uppercase(self) -> None:
        """Test uppercase conversion."""
        result = MockNormalizationEngine.apply_rules("hello world")
        assert result == "HELLO WORLD"

    def test_apply_rules_whitespace(self) -> None:
        """Test whitespace normalization."""
        result = MockNormalizationEngine.apply_rules("  hello    world  ")
        assert result == "HELLO WORLD"

    def test_apply_rules_brand_coke(self) -> None:
        """Test COKE brand expansion."""
        result = MockNormalizationEngine.apply_rules("COKE CLASSIC")
        assert result is not None
        assert "COCA-COLA" in result

    def test_apply_rules_brand_gatorade(self) -> None:
        """Test GTRD brand expansion."""
        result = MockNormalizationEngine.apply_rules("GTRD FRUIT PUNCH")
        assert result is not None
        assert "GATORADE" in result

    def test_apply_rules_null(self) -> None:
        """Test NULL handling."""
        result = MockNormalizationEngine.apply_rules(None)
        assert result is None

    def test_apply_rules_empty(self) -> None:
        """Test empty string handling."""
        result = MockNormalizationEngine.apply_rules("")
        assert result == ""

    def test_apply_rules_punctuation(self) -> None:
        """Test punctuation removal."""
        result = MockNormalizationEngine.apply_rules("PRODUCT (NEW) [ITEM] #123")
        assert result is not None
        assert "(" not in result
        assert ")" not in result
        assert "[" not in result
        assert "]" not in result
        assert "#" not in result
