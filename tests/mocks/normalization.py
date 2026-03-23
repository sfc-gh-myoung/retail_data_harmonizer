"""Mock implementations for normalization testing.

Provides mock Snowpark session and related classes for testing
normalization logic without requiring a real Snowflake connection.
"""

from __future__ import annotations

import re
from typing import Any


class MockNormalizationEngine:
    """Python implementation of normalization logic that mirrors the Snowflake UDF.

    This allows testing normalization behavior without a real Snowflake connection.
    """

    # Rule types and their transformations
    ABBREVIATIONS = {
        "OZ": "OUNCE",
        "PKG": "PACKAGE",
        "BTL": "BOTTLE",
        "CAN": "CAN",
        "PK": "PACK",
        "CT": "COUNT",
        "LB": "POUND",
        "GAL": "GALLON",
        "QT": "QUART",
        "PT": "PINT",
    }

    BRAND_MAPPINGS = {
        "COKE CL": "COCA-COLA CLASSIC",
        "COKE": "COCA-COLA",
        "MTN DEW": "MOUNTAIN DEW",
        "GTRD": "GATORADE",
        "PPSI": "PEPSI",
        "DRTS": "DORITOS",
        "LYS": "LAYS",
        "FRTO": "FRITO",
        "NSTL": "NESTLE",
        "AQF": "AQUAFINA",
    }

    @classmethod
    def apply_rules(cls, text: str | None) -> str | None:
        """Apply normalization rules to input text."""
        if text is None:
            return None
        if text == "":
            return ""

        result = text

        # Step 1: Uppercase
        result = result.upper()

        # Step 2: Trim leading/trailing whitespace
        result = result.strip()

        # Step 3: Collapse multiple spaces to single space
        result = re.sub(r"\s+", " ", result)

        # Step 4: Brand standardization (longest match first)
        for pattern, replacement in sorted(cls.BRAND_MAPPINGS.items(), key=lambda x: -len(x[0])):
            result = re.sub(rf"\b{re.escape(pattern)}\b", replacement, result)

        # Step 5: Remove some punctuation (parentheses, brackets)
        result = re.sub(r"[()[\]#]", "", result)

        # Step 6: Collapse spaces again after punctuation removal
        result = re.sub(r"\s+", " ", result).strip()

        return result


class MockRow:
    """Mock Snowpark Row that supports dict-like access."""

    def __init__(self, data: dict):
        """Initialize MockRow with data dictionary."""
        self._data = data

    def __getitem__(self, key: str) -> Any:
        """Return value for key from the internal data dictionary."""
        return self._data.get(key)

    def get(self, key: str, default: Any = None) -> Any:
        """Return value for key, or default if not present."""
        return self._data.get(key, default)


class MockDataFrame:
    """Mock Snowpark DataFrame that returns mock results."""

    def __init__(self, rows: list[dict]):
        """Initialize MockDataFrame with a list of row dictionaries."""
        self._rows = [MockRow(r) for r in rows]

    def collect(self) -> list[MockRow]:
        """Return all rows as a list of MockRow objects."""
        return self._rows


class MockSession:
    """Mock Snowpark Session that simulates UDF calls and queries."""

    def __init__(self) -> None:
        """Initialize MockSession with seed rules and engine."""
        self._rules = self._seed_rules()
        self._engine = MockNormalizationEngine()

    def _seed_rules(self) -> list[dict]:
        """Generate seed normalization rules."""
        rules = []
        rule_id = 1

        # Add abbreviation rules
        for pattern, replacement in MockNormalizationEngine.ABBREVIATIONS.items():
            rules.append(
                {
                    "RULE_ID": f"rule-{rule_id:04d}",
                    "RULE_TYPE": "ABBREVIATION",
                    "PATTERN": pattern,
                    "REPLACEMENT": replacement,
                    "PRIORITY": 10,
                    "IS_REGEX": False,
                    "IS_ACTIVE": True,
                }
            )
            rule_id += 1

        # Add brand rules
        for pattern, replacement in MockNormalizationEngine.BRAND_MAPPINGS.items():
            rules.append(
                {
                    "RULE_ID": f"rule-{rule_id:04d}",
                    "RULE_TYPE": "BRAND",
                    "PATTERN": pattern,
                    "REPLACEMENT": replacement,
                    "PRIORITY": 20,
                    "IS_REGEX": False,
                    "IS_ACTIVE": True,
                }
            )
            rule_id += 1

        # Add whitespace rules
        rules.append(
            {
                "RULE_ID": f"rule-{rule_id:04d}",
                "RULE_TYPE": "WHITESPACE",
                "PATTERN": r"\s+",
                "REPLACEMENT": " ",
                "PRIORITY": 5,
                "IS_REGEX": True,
                "IS_ACTIVE": True,
            }
        )
        rule_id += 1

        # Add punctuation rules
        rules.append(
            {
                "RULE_ID": f"rule-{rule_id:04d}",
                "RULE_TYPE": "PUNCTUATION",
                "PATTERN": r"[()[\]#]",
                "REPLACEMENT": "",
                "PRIORITY": 3,
                "IS_REGEX": True,
                "IS_ACTIVE": True,
            }
        )
        rule_id += 1

        # Add unit rules
        rules.append(
            {
                "RULE_ID": f"rule-{rule_id:04d}",
                "RULE_TYPE": "UNIT",
                "PATTERN": "12PK",
                "REPLACEMENT": "12 PACK",
                "PRIORITY": 15,
                "IS_REGEX": False,
                "IS_ACTIVE": True,
            }
        )
        rule_id += 1

        # Add variant rules
        rules.append(
            {
                "RULE_ID": f"rule-{rule_id:04d}",
                "RULE_TYPE": "VARIANT",
                "PATTERN": "CLASSIC",
                "REPLACEMENT": "CLASSIC",
                "PRIORITY": 25,
                "IS_REGEX": False,
                "IS_ACTIVE": True,
            }
        )

        return rules

    def sql(self, query: str) -> MockDataFrame:
        """Execute a SQL query and return mock results."""
        query_upper = query.upper().strip()

        # Handle APPLY_NORMALIZATION_RULES UDF calls
        if "APPLY_NORMALIZATION_RULES" in query_upper:
            # Extract the argument from the SQL (handle multi-line and special chars)
            match = re.search(r"APPLY_NORMALIZATION_RULES\(\s*'([^']*)'\s*\)", query, re.IGNORECASE | re.DOTALL)
            match_null = re.search(r"APPLY_NORMALIZATION_RULES\(\s*NULL\s*\)", query, re.IGNORECASE)

            if match_null:
                return MockDataFrame([{"RESULT": None}])
            elif match:
                input_text = match.group(1)
                result = self._engine.apply_rules(input_text)
                return MockDataFrame([{"RESULT": result}])
            else:
                # Fallback: try to extract text between quotes after APPLY_NORMALIZATION_RULES(
                # Handle newlines in query
                normalized_query = " ".join(query.split())
                fallback_match = re.search(
                    r"APPLY_NORMALIZATION_RULES\s*\(\s*'(.+?)'\s*\)", normalized_query, re.IGNORECASE
                )
                if fallback_match:
                    input_text = fallback_match.group(1)
                    result = self._engine.apply_rules(input_text)
                    return MockDataFrame([{"RESULT": result}])

        # Handle INFORMATION_SCHEMA.COLUMNS query
        if "INFORMATION_SCHEMA.COLUMNS" in query_upper and "NORMALIZATION_RULES" in query_upper:
            return MockDataFrame([{"CNT": 12}])

        # Handle count of active rules
        if "COUNT(*)" in query_upper and "NORMALIZATION_RULES" in query_upper and "IS_ACTIVE" in query_upper:
            active_count = sum(1 for r in self._rules if r["IS_ACTIVE"])
            return MockDataFrame([{"RULE_COUNT": active_count}])

        # Handle DISTINCT RULE_TYPE query
        if "DISTINCT RULE_TYPE" in query_upper:
            rule_types = sorted(set(r["RULE_TYPE"] for r in self._rules))
            return MockDataFrame([{"RULE_TYPE": rt} for rt in rule_types])

        # Handle ADD_NORMALIZATION_RULE procedure
        if "ADD_NORMALIZATION_RULE" in query_upper:
            return MockDataFrame([{0: "Rule added successfully"}])

        # Handle TOGGLE_NORMALIZATION_RULE procedure
        if "TOGGLE_NORMALIZATION_RULE" in query_upper:
            # Extract rule_id and new status from the call
            match = re.search(r"TOGGLE_NORMALIZATION_RULE\('([^']+)',\s*(TRUE|FALSE)\)", query, re.IGNORECASE)
            if match:
                rule_id = match.group(1)
                new_status = match.group(2).upper() == "TRUE"
                for r in self._rules:
                    if r["RULE_ID"] == rule_id:
                        r["IS_ACTIVE"] = new_status
            return MockDataFrame([{0: "Rule toggled successfully"}])

        # Handle rule lookup by RULE_ID
        if "RULE_ID" in query_upper and "IS_ACTIVE" in query_upper and "WHERE" in query_upper:
            match = re.search(r"RULE_ID\s*=\s*'([^']+)'", query, re.IGNORECASE)
            if match:
                rule_id = match.group(1)
                for r in self._rules:
                    if r["RULE_ID"] == rule_id:
                        return MockDataFrame([{"IS_ACTIVE": r["IS_ACTIVE"]}])
            return MockDataFrame([])

        # Handle getting first rule
        if "LIMIT 1" in query_upper and "RULE_ID" in query_upper:
            if self._rules:
                r = self._rules[0]
                return MockDataFrame([{"RULE_ID": r["RULE_ID"], "IS_ACTIVE": r["IS_ACTIVE"]}])
            return MockDataFrame([])

        # Handle EXPORT_NORMALIZATION_RULES procedure
        if "EXPORT_NORMALIZATION_RULES" in query_upper:
            import json

            return MockDataFrame([{0: json.dumps(self._rules)}])

        # Handle TEST_NORMALIZATION procedure
        if "TEST_NORMALIZATION" in query_upper:
            match = re.search(r"TEST_NORMALIZATION\('([^']*)'\)", query, re.IGNORECASE)
            if match:
                input_text = match.group(1)
                output_text = self._engine.apply_rules(input_text)
                return MockDataFrame([{0: f"Input: {input_text}\nOutput: {output_text}\nRules applied: 5"}])

        # Handle DEDUPLICATE_RAW_ITEMS procedure
        if "DEDUPLICATE_RAW_ITEMS" in query_upper:
            return MockDataFrame([{0: "Deduplication complete. enhanced_norm=True, processed=10"}])

        # Handle INSERT/DELETE/UPDATE (return empty success)
        if any(kw in query_upper for kw in ["INSERT", "DELETE", "UPDATE"]):
            return MockDataFrame([])

        # Handle pattern lookup for test rule cleanup
        if "PATTERN = 'TESTABBR'" in query:
            return MockDataFrame([{"CNT": 1}])

        # Default: empty result
        return MockDataFrame([])
