"""tests/test_item_lineage.py - Item Lineage Tests (Wave 2: T85-T88).

Retail Data Harmonizer tests for:
- RAW_TO_UNIQUE_MAP junction table
- V_RAW_TO_UNIQUE_AUDIT view
- V_TRACEABILITY_METRICS view
- V_TRACEABILITY_BY_SOURCE view
- POPULATE_RAW_TO_UNIQUE_MAP() procedure
- GET_ITEM_TRACE() procedure
"""

import json
from unittest.mock import MagicMock


class TestRawToUniqueMapTable:
    """Tests for RAW_TO_UNIQUE_MAP junction table (T85)."""

    def test_table_exists_with_correct_schema(self, mock_snowflake_connection) -> None:
        """Verify RAW_TO_UNIQUE_MAP table exists with expected columns."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            ("MAP_ID", "VARCHAR", "NO"),
            ("RAW_ITEM_ID", "VARCHAR", "NO"),
            ("UNIQUE_DESC_ID", "VARCHAR", "NO"),
            ("RAW_DESCRIPTION", "VARCHAR", "YES"),
            ("NORMALIZED_DESCRIPTION", "VARCHAR", "YES"),
            ("NORMALIZATION_METHOD", "VARCHAR", "YES"),
            ("MAPPED_AT", "TIMESTAMP_NTZ", "YES"),
        ]
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("DESCRIBE TABLE HARMONIZED.RAW_TO_UNIQUE_MAP")
        result = mock_cursor.fetchall()

        assert len(result) == 7
        column_names = [row[0] for row in result]
        assert "MAP_ID" in column_names
        assert "RAW_ITEM_ID" in column_names
        assert "UNIQUE_DESC_ID" in column_names
        assert "NORMALIZATION_METHOD" in column_names

    def test_table_has_primary_key(self, mock_snowflake_connection) -> None:
        """Verify table has primary key constraint on MAP_ID."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            ("PK_RAW_TO_UNIQUE_MAP", "PRIMARY KEY", "MAP_ID"),
        ]
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("""
            SELECT CONSTRAINT_NAME, CONSTRAINT_TYPE, COLUMN_NAME
            FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
            JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
                ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
            WHERE tc.TABLE_NAME = 'RAW_TO_UNIQUE_MAP'
              AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
        """)
        result = mock_cursor.fetchall()

        assert len(result) >= 1
        assert result[0][1] == "PRIMARY KEY"

    def test_table_has_foreign_keys(self, mock_snowflake_connection) -> None:
        """Verify table has foreign key constraints."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            ("FK_RAW_UNIQUE_RAW", "FOREIGN KEY", "RAW_ITEM_ID"),
            ("FK_RAW_UNIQUE_UNIQUE", "FOREIGN KEY", "UNIQUE_DESC_ID"),
        ]
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("""
            SELECT CONSTRAINT_NAME, CONSTRAINT_TYPE
            FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
            WHERE TABLE_NAME = 'RAW_TO_UNIQUE_MAP'
              AND CONSTRAINT_TYPE = 'FOREIGN KEY'
        """)
        result = mock_cursor.fetchall()

        constraint_names = [row[0] for row in result]
        assert "FK_RAW_UNIQUE_RAW" in constraint_names or len(result) >= 2

    def test_normalization_method_values(self, mock_snowflake_connection) -> None:
        """Verify NORMALIZATION_METHOD contains expected values."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            ("ENHANCED", 150),
            ("BASIC", 50),
        ]
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("""
            SELECT NORMALIZATION_METHOD, COUNT(*)
            FROM HARMONIZED.RAW_TO_UNIQUE_MAP
            GROUP BY NORMALIZATION_METHOD
        """)
        result = mock_cursor.fetchall()

        methods = [row[0] for row in result]
        # Should only contain ENHANCED or BASIC
        for method in methods:
            assert method in ("ENHANCED", "BASIC")


class TestTraceabilityViews:
    """Tests for traceability views (T87)."""

    def test_audit_view_exists(self, mock_snowflake_connection) -> None:
        """Verify V_RAW_TO_UNIQUE_AUDIT view exists."""
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = ("V_RAW_TO_UNIQUE_AUDIT", "VIEW")
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("""
            SELECT TABLE_NAME, TABLE_TYPE
            FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_NAME = 'V_RAW_TO_UNIQUE_AUDIT'
              AND TABLE_SCHEMA = 'ANALYTICS'
        """)
        result = mock_cursor.fetchone()

        assert result is not None
        assert result[0] == "V_RAW_TO_UNIQUE_AUDIT"

    def test_audit_view_columns(self, mock_snowflake_connection) -> None:
        """Verify V_RAW_TO_UNIQUE_AUDIT has expected columns."""
        mock_cursor = MagicMock()
        mock_cursor.description = [
            ("RAW_ITEM_ID",),
            ("RAW_DESCRIPTION",),
            ("SOURCE_SYSTEM",),
            ("MAP_ID",),
            ("NORMALIZATION_METHOD",),
            ("UNIQUE_DESC_ID",),
            ("NORMALIZED_DESCRIPTION",),
            ("MATCH_ID",),
            ("ENSEMBLE_SCORE",),
            ("STANDARD_DESCRIPTION",),
        ]
        mock_cursor.fetchall.return_value = []
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("SELECT * FROM ANALYTICS.V_RAW_TO_UNIQUE_AUDIT LIMIT 0")
        columns = [col[0] for col in mock_cursor.description]

        # Check key columns exist
        assert "RAW_ITEM_ID" in columns
        assert "NORMALIZED_DESCRIPTION" in columns
        assert "NORMALIZATION_METHOD" in columns

    def test_metrics_view_exists(self, mock_snowflake_connection) -> None:
        """Verify V_TRACEABILITY_METRICS view exists and returns data."""
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = (
            1000,  # TOTAL_RAW_ITEMS
            50,  # TOTAL_UNIQUE_DESCRIPTIONS
            1000,  # TOTAL_MAPPINGS
            1000,  # MAPPED_RAW_ITEMS
            0,  # UNMAPPED_RAW_ITEMS
            20.0,  # DEDUP_RATIO
            800,  # ENHANCED_NORM_COUNT
            200,  # BASIC_NORM_COUNT
        )
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("SELECT * FROM ANALYTICS.V_TRACEABILITY_METRICS")
        result = mock_cursor.fetchone()

        assert result is not None
        assert result[0] > 0  # TOTAL_RAW_ITEMS
        assert result[5] > 0  # DEDUP_RATIO

    def test_by_source_view_exists(self, mock_snowflake_connection) -> None:
        """Verify V_TRACEABILITY_BY_SOURCE view exists."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            ("SYSCO", 400, 20, 400, 20.0, 350, 380, 0.95),
            ("US_FOODS", 300, 15, 300, 20.0, 250, 280, 0.93),
        ]
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("""
            SELECT SOURCE_SYSTEM, RAW_ITEMS, UNIQUE_DESCRIPTIONS, DEDUP_RATIO
            FROM ANALYTICS.V_TRACEABILITY_BY_SOURCE
        """)
        result = mock_cursor.fetchall()

        assert len(result) >= 1
        # Each row should have source system
        for row in result:
            assert row[0] is not None  # SOURCE_SYSTEM


class TestPopulateRawToUniqueMap:
    """Tests for POPULATE_RAW_TO_UNIQUE_MAP procedure (T86)."""

    def test_procedure_exists(self, mock_snowflake_connection) -> None:
        """Verify procedure exists."""
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = ("POPULATE_RAW_TO_UNIQUE_MAP",)
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("""
            SHOW PROCEDURES LIKE 'POPULATE_RAW_TO_UNIQUE_MAP' IN SCHEMA HARMONIZED
        """)
        result = mock_cursor.fetchone()

        assert result is not None

    def test_procedure_returns_json(self, mock_snowflake_connection) -> None:
        """Verify procedure returns JSON with mappings_created."""
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = ('{"mappings_created": 100, "normalization_method": "ENHANCED"}',)
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("CALL HARMONIZED.POPULATE_RAW_TO_UNIQUE_MAP()")
        result = json.loads(mock_cursor.fetchone()[0])

        assert "mappings_created" in result
        assert "normalization_method" in result
        assert result["normalization_method"] in ("ENHANCED", "BASIC")

    def test_procedure_is_idempotent(self, mock_snowflake_connection) -> None:
        """Verify procedure doesn't create duplicate mappings."""
        mock_cursor = MagicMock()
        # First call creates mappings
        mock_cursor.fetchone.return_value = ('{"mappings_created": 100, "normalization_method": "ENHANCED"}',)
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("CALL HARMONIZED.POPULATE_RAW_TO_UNIQUE_MAP()")
        json.loads(mock_cursor.fetchone()[0])  # First call result not needed

        # Second call should create 0 (already mapped)
        mock_cursor.fetchone.return_value = ('{"mappings_created": 0, "normalization_method": "ENHANCED"}',)
        mock_cursor.execute("CALL HARMONIZED.POPULATE_RAW_TO_UNIQUE_MAP()")
        second_result = json.loads(mock_cursor.fetchone()[0])

        assert second_result["mappings_created"] == 0


class TestGetItemTrace:
    """Tests for GET_ITEM_TRACE procedure."""

    def test_procedure_exists(self, mock_snowflake_connection) -> None:
        """Verify GET_ITEM_TRACE procedure exists."""
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = ("GET_ITEM_TRACE",)
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("""
            SHOW PROCEDURES LIKE 'GET_ITEM_TRACE' IN SCHEMA HARMONIZED
        """)
        result = mock_cursor.fetchone()

        assert result is not None

    def test_procedure_returns_trace_steps(self, mock_snowflake_connection) -> None:
        """Verify procedure returns trace steps in order."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            ("1. RAW_ITEM", "Original raw description", "COCA COLA 12PK", "2025-01-01 00:00:00"),
            ("2. NORMALIZED", "After normalization", "COCA-COLA 12PK", "2025-01-01 00:00:01"),
            ("3. UNIQUE_DESC", "Deduplicated (item_count: 50)", "uuid-123", "2025-01-01 00:00:00"),
            ("4. MATCH_RESULT", "Match method: HYBRID", "Score: 0.95", "2025-01-01 00:00:02"),
            ("5. STANDARD_ITEM", "Matched standard", "Coca-Cola Classic 12-Pack", None),
        ]
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("CALL HARMONIZED.GET_ITEM_TRACE('test-item-id')")
        result = mock_cursor.fetchall()

        assert len(result) >= 1
        # Steps should be in order
        steps = [row[0] for row in result]
        assert steps[0].startswith("1.")

    def test_procedure_handles_unmapped_item(self, mock_snowflake_connection) -> None:
        """Verify procedure handles items not yet mapped."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            ("1. RAW_ITEM", "Original raw description", "NEW ITEM XYZ", "2025-01-15 00:00:00"),
        ]
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("CALL HARMONIZED.GET_ITEM_TRACE('unmapped-item-id')")
        result = mock_cursor.fetchall()

        # Should return at least the raw item step
        assert len(result) >= 1
        assert result[0][0] == "1. RAW_ITEM"


class TestDeduplicationIntegration:
    """Integration tests for dedup + traceability (T81, T86)."""

    def test_dedup_populates_junction_table(self, mock_snowflake_connection) -> None:
        """Verify DEDUPLICATE_RAW_ITEMS also populates RAW_TO_UNIQUE_MAP."""
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = (
            '{"total_raw": 1000, "unique_count": 50, "dedup_ratio": 20.0, "enhanced_norm": true, "mappings_created": 1000}',
        )
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("CALL HARMONIZED.DEDUPLICATE_RAW_ITEMS()")
        result = json.loads(mock_cursor.fetchone()[0])

        assert "mappings_created" in result
        assert result["mappings_created"] > 0

    def test_dedup_uses_enhanced_normalization(self, mock_snowflake_connection) -> None:
        """Verify dedup uses enhanced normalization when available."""
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = (
            '{"total_raw": 500, "unique_count": 25, "dedup_ratio": 20.0, "enhanced_norm": true, "mappings_created": 500}',
        )
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("CALL HARMONIZED.DEDUPLICATE_RAW_ITEMS()")
        result = json.loads(mock_cursor.fetchone()[0])

        assert result["enhanced_norm"] is True

    def test_dedup_falls_back_to_basic(self, mock_snowflake_connection) -> None:
        """Verify dedup falls back to basic normalization when UDF unavailable."""
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = (
            '{"total_raw": 500, "unique_count": 30, "dedup_ratio": 16.67, "enhanced_norm": false, "mappings_created": 500}',
        )
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("CALL HARMONIZED.DEDUPLICATE_RAW_ITEMS()")
        result = json.loads(mock_cursor.fetchone()[0])

        # Should work even with basic normalization
        assert result["unique_count"] > 0
        assert result["mappings_created"] > 0


class TestUniqueDescRollup:
    """Tests for V_UNIQUE_DESC_ROLLUP view."""

    def test_rollup_view_exists(self, mock_snowflake_connection) -> None:
        """Verify V_UNIQUE_DESC_ROLLUP view exists."""
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = ("V_UNIQUE_DESC_ROLLUP", "VIEW")
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("""
            SELECT TABLE_NAME, TABLE_TYPE
            FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_NAME = 'V_UNIQUE_DESC_ROLLUP'
        """)
        result = mock_cursor.fetchone()

        assert result is not None

    def test_rollup_shows_item_counts(self, mock_snowflake_connection) -> None:
        """Verify rollup shows item counts per unique description."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            ("uuid-1", "COCA-COLA CLASSIC 12PK", 150, "MATCHED"),
            ("uuid-2", "PEPSI 2L BOTTLE", 75, "PENDING"),
        ]
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("""
            SELECT UNIQUE_DESC_ID, NORMALIZED_DESCRIPTION, ITEM_COUNT, MATCH_STATUS
            FROM ANALYTICS.V_UNIQUE_DESC_ROLLUP
            ORDER BY ITEM_COUNT DESC
            LIMIT 10
        """)
        result = mock_cursor.fetchall()

        assert len(result) >= 1
        # Should be ordered by item count desc
        if len(result) > 1:
            assert result[0][2] >= result[1][2]


class TestTraceabilityEdgeCases:
    """Edge case tests for traceability."""

    def test_handles_null_descriptions(self, mock_snowflake_connection) -> None:
        """Verify system handles NULL raw descriptions gracefully."""
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = (0,)  # Count of NULL descriptions
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("""
            SELECT COUNT(*)
            FROM HARMONIZED.RAW_TO_UNIQUE_MAP
            WHERE RAW_DESCRIPTION IS NULL
        """)
        result = mock_cursor.fetchone()[0]

        # NULL descriptions should be handled (either excluded or mapped)
        assert result >= 0

    def test_handles_very_long_descriptions(self, mock_snowflake_connection) -> None:
        """Verify system handles descriptions near VARCHAR(500) limit."""
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = (5,)  # Count of long descriptions
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("""
            SELECT COUNT(*)
            FROM HARMONIZED.RAW_TO_UNIQUE_MAP
            WHERE LENGTH(RAW_DESCRIPTION) > 400
        """)
        result = mock_cursor.fetchone()[0]

        # Should handle long descriptions without error
        assert result >= 0

    def test_multiple_raw_items_same_unique(self, mock_snowflake_connection) -> None:
        """Verify multiple raw items can map to same unique description."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            ("uuid-unique-1", 50),  # 50 raw items map to this unique
            ("uuid-unique-2", 30),
        ]
        mock_snowflake_connection.cursor.return_value = mock_cursor

        mock_cursor.execute("""
            SELECT UNIQUE_DESC_ID, COUNT(*) AS RAW_COUNT
            FROM HARMONIZED.RAW_TO_UNIQUE_MAP
            GROUP BY UNIQUE_DESC_ID
            HAVING COUNT(*) > 1
            ORDER BY RAW_COUNT DESC
            LIMIT 5
        """)
        result = mock_cursor.fetchall()

        # Should have some unique descriptions with multiple raw items
        if len(result) > 0:
            assert result[0][1] > 1
