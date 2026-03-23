"""Settings service for configuration data access.

Extracts SQL queries from settings route handlers into a reusable service layer.
Reads from and writes to the ANALYTICS.CONFIG table.

Public API:
    - get_all_config: Fetch all config key-value pairs
    - get_config_paginated: Fetch paginated config rows with total count
    - update_settings: Bulk upsert config values via MERGE (WRITE)

Side Effects:
    update_settings performs MERGE on ANALYTICS.CONFIG table (INSERT or UPDATE).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from backend.services.base import BaseService


@dataclass
class SettingsService(BaseService):
    """Service for configuration table queries.

    Provides read and write access to the ANALYTICS.CONFIG key-value store.

    Side Effects:
        update_settings: Performs MERGE (upsert) on ANALYTICS.CONFIG table.
        Sets UPDATED_AT timestamp on existing rows when values change.

    Thread Safety:
        Safe for concurrent use (no shared mutable state).
    """

    async def get_all_config(self) -> list[dict[str, Any]]:
        """Fetch all config key-value pairs, ordered by key."""
        return await self.sf.query(f"""
            SELECT CONFIG_KEY, CONFIG_VALUE
            FROM {self.db_name}.ANALYTICS.CONFIG
            ORDER BY CONFIG_KEY
        """)

    async def get_config_paginated(self, page: int, page_size: int) -> tuple[list[dict[str, Any]], int]:
        """Fetch a page of config rows with total count.

        Returns:
            Tuple of (rows, total_count).
        """
        count_result = await self.sf.query(f"""
            SELECT COUNT(*) AS CNT FROM {self.db_name}.ANALYTICS.CONFIG
        """)
        total = count_result[0]["CNT"] if count_result else 0

        total_pages = max(1, (total + page_size - 1) // page_size)
        page = min(page, total_pages)
        offset = (page - 1) * page_size

        rows = await self.sf.query(f"""
            SELECT CONFIG_KEY, CONFIG_VALUE
            FROM {self.db_name}.ANALYTICS.CONFIG
            ORDER BY CONFIG_KEY
            LIMIT {page_size} OFFSET {offset}
        """)

        return rows, total

    async def update_settings(self, updates: list[tuple[str, str]]) -> None:
        """Bulk upsert config values via MERGE.

        Performs a MERGE operation that either inserts new keys or updates
        existing keys with new values and refreshes UPDATED_AT timestamp.

        Args:
            updates: List of (key, value) pairs to upsert.

        Side Effects:
            - Inserts new rows into ANALYTICS.CONFIG for new keys
            - Updates CONFIG_VALUE and UPDATED_AT for existing keys
        """
        values_rows = ",\n            ".join(
            [f"('{self._safe(key)}', '{self._safe(value)}')" for key, value in updates]
        )
        await self.sf.execute(f"""
            MERGE INTO {self.db_name}.ANALYTICS.CONFIG AS target
            USING (
                SELECT column1 AS CONFIG_KEY, column2 AS CONFIG_VALUE
                FROM VALUES
                {values_rows}
            ) AS source
            ON target.CONFIG_KEY = source.CONFIG_KEY
            WHEN MATCHED THEN
                UPDATE SET
                    CONFIG_VALUE = source.CONFIG_VALUE,
                    UPDATED_AT = CURRENT_TIMESTAMP()
            WHEN NOT MATCHED THEN
                INSERT (CONFIG_KEY, CONFIG_VALUE)
                VALUES (source.CONFIG_KEY, source.CONFIG_VALUE)
        """)
