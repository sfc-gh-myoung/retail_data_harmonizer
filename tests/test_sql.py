"""SQL file validation — syntax and column-name consistency checks.

These tests do NOT require a Snowflake connection. They validate:
1. Every SQL file is parseable (no stray characters, balanced quotes)
2. Column names used in ITEM_MATCHES and MATCH_CANDIDATES are consistent
   with the DDL in 02_schema_and_tables.sql
3. Config keys are UPPER_CASE
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

SQL_DIR = Path(__file__).resolve().parent.parent / "sql"

# Collect all SQL files recursively from sql/ and subdirectories
SQL_FILES = sorted(SQL_DIR.rglob("*.sql"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _read_sql(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _strip_comments(sql: str) -> str:
    """Remove -- line comments and /* block comments */."""
    sql = re.sub(r"--[^\n]*", "", sql)
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.DOTALL)
    return sql


# ---------------------------------------------------------------------------
# Basic file integrity
# ---------------------------------------------------------------------------


class TestSQLFileIntegrity:
    """Test basic SQL file integrity and formatting."""

    @pytest.mark.parametrize("sql_file", SQL_FILES, ids=[f.name for f in SQL_FILES])
    def test_file_readable(self, sql_file: Path) -> None:
        """Every SQL file should be readable as UTF-8."""
        content = _read_sql(sql_file)
        assert len(content) > 0, f"{sql_file.name} is empty"

    @pytest.mark.parametrize("sql_file", SQL_FILES, ids=[f.name for f in SQL_FILES])
    def test_balanced_single_quotes(self, sql_file: Path) -> None:
        """Single quotes should be balanced (accounting for escaped '')."""
        content = _strip_comments(_read_sql(sql_file))
        # Remove $$ blocks (Snowflake Python UDFs contain Python string literals)
        content = re.sub(r"\$\$.*?\$\$", "", content, flags=re.DOTALL)
        # Remove escaped quotes ('')
        cleaned = content.replace("''", "")
        # Count single quotes — should be even
        count = cleaned.count("'")
        assert count % 2 == 0, f"{sql_file.name} has unbalanced single quotes ({count})"

    @pytest.mark.parametrize("sql_file", SQL_FILES, ids=[f.name for f in SQL_FILES])
    def test_balanced_parentheses(self, sql_file: Path) -> None:
        """Parentheses should be balanced."""
        content = _strip_comments(_read_sql(sql_file))
        # Remove $$ blocks (Snowflake scripting) which contain embedded SQL
        content = re.sub(r"\$\$.*?\$\$", "", content, flags=re.DOTALL)
        # Remove string literals to avoid false positives
        content = re.sub(r"'[^']*'", "", content)
        opens = content.count("(")
        closes = content.count(")")
        assert opens == closes, f"{sql_file.name} has unbalanced parentheses (opens={opens}, closes={closes})"

    @pytest.mark.parametrize("sql_file", SQL_FILES, ids=[f.name for f in SQL_FILES])
    def test_no_tabs(self, sql_file: Path) -> None:
        """SQL files should use spaces, not tabs."""
        content = _read_sql(sql_file)
        assert "\t" not in content, f"{sql_file.name} contains tab characters"


# ---------------------------------------------------------------------------
# Column name consistency
# ---------------------------------------------------------------------------


class TestColumnNameConsistency:
    """Verify SQL files use correct column names matching DDL."""

    # Old column names that should NOT appear (except in comments)
    # Note: SEARCH_SCORE is valid in staging tables (CORTEX_SEARCH_STAGING) and
    # as aliases in CTEs; only ITEM_MATCHES should use CORTEX_SEARCH_SCORE
    OLD_COLUMNS = [
        (r"\bENSEMBLE_CONFIDENCE\b", "Use ENSEMBLE_SCORE instead"),
    ]

    # Files where staging column SEARCH_SCORE is valid
    STAGING_FILES = {
        "02_schema_and_tables.sql",  # DDL for CORTEX_SEARCH_STAGING table
        "09c_matching_ensemble.sql",  # Reads from staging, writes to ITEM_MATCHES
        "12_parallel_matchers.sql",  # Batch processing uses staging
    }

    # Files where MATCHED_STANDARD_ID is valid (RAW_RETAIL_ITEMS table DDL)
    RAW_TABLE_FILES = {"02_schema_and_tables.sql", "05_seed_data", "05a_seed_config.sql"}

    @pytest.mark.parametrize("sql_file", SQL_FILES, ids=[f.name for f in SQL_FILES])
    def test_no_old_column_names(self, sql_file: Path) -> None:
        """Test that no deprecated column names appear in SQL files."""
        content = _strip_comments(_read_sql(sql_file))
        for pattern, msg in self.OLD_COLUMNS:
            matches = re.findall(pattern, content)
            assert not matches, f"{sql_file.name}: found deprecated column name '{matches[0]}'. {msg}"

    def test_item_matches_uses_raw_item_id(self) -> None:
        """ITEM_MATCHES should use RAW_ITEM_ID, not ITEM_ID as FK."""
        for sql_file in SQL_FILES:
            if sql_file.name in ("01_setup.sql", "91_teardown.sql"):
                continue
            content = _strip_comments(_read_sql(sql_file))
            # Look for im.ITEM_ID or ITEM_MATCHES...ITEM_ID patterns
            # (but not RAW_ITEM_ID)
            bad = re.findall(r"im\.ITEM_ID\b", content)
            assert not bad, f"{sql_file.name}: uses im.ITEM_ID — should be im.RAW_ITEM_ID"


# ---------------------------------------------------------------------------
# Config key casing
# ---------------------------------------------------------------------------


class TestConfigKeyCasing:
    """Config keys stored in CONFIG should be UPPER_CASE."""

    # Files that contain CONFIG seed data or procedures
    CONFIG_FILES = [
        f for f in SQL_FILES if f.name in ("05a_seed_config.sql", "13_admin_utilities.sql") or "seed" in f.name.lower()
    ]

    @pytest.mark.parametrize(
        "sql_file",
        CONFIG_FILES,
        ids=[f.name for f in CONFIG_FILES],
    )
    def test_config_keys_uppercase(self, sql_file: Path) -> None:
        """Test that config keys in seed data are UPPER_CASE."""
        content = _read_sql(sql_file)
        # Find INSERT INTO ... CONFIG ... VALUES ('key', ...)
        for match in re.finditer(r"CONFIG.*?VALUES\s*\(\s*'([^']+)'", content, re.DOTALL):
            key = match.group(1)
            assert key == key.upper(), f"{sql_file.name}: config key '{key}' should be UPPER_CASE"
