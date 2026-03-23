"""Multi-mode Snowflake client — supports CLI, Connector, and Snowpark Session.

Usage:
    from backend.snowflake import get_client

    client = get_client()          # auto-detects mode
    rows = client.query("SELECT 1")
    client.execute("CALL my_proc()")

Modes:
    - "connector": Uses snowflake-connector-python with persistent connection (fastest for local dev)
    - "cli": Spawns `snow sql` subprocess per query (slowest, but no extra deps)
    - "snowpark": Uses Snowpark Session (for SPCS / Snowflake-native apps)
"""

from __future__ import annotations

import asyncio
import json
import os
import shutil
import subprocess
import sys
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Any

try:
    import tomllib
except ImportError:
    import tomli as tomllib  # type: ignore[import-not-found,no-redef]


class SnowflakeClient(ABC):
    """Abstract base for Snowflake query execution."""

    def __init__(self, database: str = "HARMONIZER_DEMO") -> None:
        """Initialize client with target database.

        Args:
            database: Snowflake database name to use.
        """
        self.database = database

    @abstractmethod
    def query(self, sql: str) -> list[dict[str, Any]]:
        """Execute a SELECT and return rows as list of dicts."""

    @abstractmethod
    def execute(self, sql: str) -> str:
        """Execute a mutation/CALL and return raw output."""

    @abstractmethod
    async def async_query(self, sql: str) -> list[dict[str, Any]]:
        """Async version of query (for FastAPI)."""

    @abstractmethod
    async def async_execute(self, sql: str) -> str:
        """Async version of execute (for FastAPI)."""

    @abstractmethod
    def test_connection(self) -> bool:
        """Test connectivity."""


class SnowCLIClient(SnowflakeClient):
    """Executes SQL via the `snow sql` CLI command."""

    def __init__(
        self,
        connection: str = "default",
        database: str = "HARMONIZER_DEMO",
    ) -> None:
        """Initialize CLI client with connection settings.

        Args:
            connection: Named connection from ~/.snowflake/connections.toml.
            database: Snowflake database name to use.
        """
        super().__init__(database)
        self.connection = connection
        self._snow_cmd: list[str] | None = None

    def _get_snow_command(self) -> list[str]:
        """Get or cache the snow CLI command path.

        Returns:
            List of command components to invoke snow CLI.

        Raises:
            SystemExit: If snow CLI is not installed.
        """
        if self._snow_cmd is not None:
            return self._snow_cmd
        if shutil.which("snow"):
            self._snow_cmd = ["snow"]
        elif shutil.which("uvx"):
            self._snow_cmd = ["uvx", "--from", "snowflake-cli-labs", "snow"]
        else:
            print(
                "ERROR: Snowflake CLI not found. Install: pip install snowflake-cli-labs",
                file=sys.stderr,
            )
            sys.exit(1)
        return self._snow_cmd

    def _base_cmd(self, *, json_format: bool = False) -> list[str]:
        """Build base command with connection and optional JSON output.

        Args:
            json_format: If True, request JSON output format.

        Returns:
            Command list ready for subprocess execution.
        """
        cmd = [*self._get_snow_command(), "sql", "-c", self.connection]
        if json_format:
            cmd.extend(["--format", "json"])
        return cmd

    # --- Sync ---

    def query(self, sql: str) -> list[dict[str, Any]]:
        """Execute SELECT via CLI subprocess and return rows as dicts."""
        cmd = [*self._base_cmd(json_format=True), "-q", sql]
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            raise RuntimeError(f"snow sql failed (rc={result.returncode}): {result.stderr.strip()}")
        raw = result.stdout.strip()
        if not raw:
            return []
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            return []
        return data if isinstance(data, list) else []

    def execute(self, sql: str) -> str:
        """Execute mutation/CALL via CLI subprocess and return output."""
        cmd = [*self._base_cmd(), "-q", sql]
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            raise RuntimeError(f"snow sql failed (rc={result.returncode}): {result.stderr.strip()}")
        return result.stdout.strip()

    # --- Async ---

    async def async_query(self, sql: str) -> list[dict[str, Any]]:
        """Execute SELECT via async CLI subprocess."""
        cmd = [*self._base_cmd(json_format=True), "-q", sql]
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await proc.communicate()
        if proc.returncode != 0:
            raise RuntimeError(f"snow sql failed (rc={proc.returncode}): {stderr.decode().strip()}")
        raw = stdout.decode().strip()
        if not raw:
            return []
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            return []
        return data if isinstance(data, list) else []

    async def async_execute(self, sql: str) -> str:
        """Execute mutation/CALL via async CLI subprocess."""
        cmd = [*self._base_cmd(), "-q", sql]
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await proc.communicate()
        if proc.returncode != 0:
            raise RuntimeError(f"snow sql failed (rc={proc.returncode}): {stderr.decode().strip()}")
        return stdout.decode().strip()

    def test_connection(self) -> bool:
        """Test connectivity by running a simple query."""
        try:
            rows = self.query("SELECT 'ok' AS status")
            return len(rows) > 0
        except Exception:
            return False


class ConnectorClient(SnowflakeClient):
    """Executes SQL via snowflake-connector-python with a persistent connection.

    This is the fastest option for local development as it maintains a single
    connection that's reused across all queries, avoiding subprocess and
    re-authentication overhead.

    Reads connection config from ~/.snowflake/connections.toml (same as snow CLI).
    """

    def __init__(
        self,
        connection: str = "default",
        database: str = "HARMONIZER_DEMO",
    ) -> None:
        """Initialize connector client with connection settings.

        Args:
            connection: Named connection from ~/.snowflake/connections.toml.
            database: Snowflake database name to use.
        """
        super().__init__(database)
        self.connection_name = connection
        self._conn: Any = None

    def _load_connection_config(self) -> dict[str, Any]:
        """Load connection parameters from snow CLI config file."""
        config_path = Path.home() / ".snowflake" / "connections.toml"
        if not config_path.exists():
            raise RuntimeError(f"Snowflake connections config not found: {config_path}\nRun: snow connection add")

        with open(config_path, "rb") as f:
            config = tomllib.load(f)

        if self.connection_name not in config:
            available = ", ".join(config.keys())
            raise RuntimeError(
                f"Connection '{self.connection_name}' not found in {config_path}\nAvailable connections: {available}"
            )

        return config[self.connection_name]

    def _get_connection(self) -> Any:
        """Get or create the persistent connection."""
        if self._conn is not None:
            return self._conn

        try:
            import snowflake.connector
        except ImportError as exc:
            raise RuntimeError(
                "snowflake-connector-python is required for connector mode. "
                "Install: pip install snowflake-connector-python"
            ) from exc

        conn_config = self._load_connection_config()

        # Map snow CLI config keys to connector parameter names
        connect_params = {
            "account": conn_config.get("account"),
            "user": conn_config.get("user"),
            "password": conn_config.get("password"),
            "authenticator": conn_config.get("authenticator", "externalbrowser"),
            "warehouse": conn_config.get("warehouse"),
            "database": self.database,
            "schema": conn_config.get("schema"),
            "role": conn_config.get("role"),
        }

        # Remove None values
        connect_params = {k: v for k, v in connect_params.items() if v is not None}

        self._conn = snowflake.connector.connect(**connect_params)
        return self._conn

    def _rows_to_dicts(self, cursor: Any) -> list[dict[str, Any]]:
        """Convert cursor results to list of dicts."""
        columns = [desc[0] for desc in cursor.description] if cursor.description else []
        return [dict(zip(columns, row, strict=True)) for row in cursor.fetchall()]

    # --- Sync ---

    def query(self, sql: str) -> list[dict[str, Any]]:
        """Execute SELECT via connector and return rows as dicts."""
        conn = self._get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(sql)
            return self._rows_to_dicts(cursor)
        finally:
            cursor.close()

    def execute(self, sql: str) -> str:
        """Execute mutation/CALL via connector and return output."""
        conn = self._get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(sql)
            rows = cursor.fetchall()
            if rows:
                return str(rows[0][0]) if len(rows[0]) > 0 else ""
            return ""
        finally:
            cursor.close()

    # --- Async (wraps sync — connector is synchronous) ---

    async def async_query(self, sql: str) -> list[dict[str, Any]]:
        """Execute SELECT via connector in thread executor."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self.query, sql)

    async def async_execute(self, sql: str) -> str:
        """Execute mutation/CALL via connector in thread executor."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self.execute, sql)

    def test_connection(self) -> bool:
        """Test connectivity by running a simple query."""
        try:
            rows = self.query("SELECT 'ok' AS status")
            return len(rows) > 0
        except Exception:
            return False

    def close(self) -> None:
        """Close the connection."""
        if self._conn is not None:
            self._conn.close()
            self._conn = None


class SnowparkClient(SnowflakeClient):
    """Executes SQL via Snowpark Session (for SPCS / Snowflake-native apps)."""

    def __init__(self, database: str = "HARMONIZER_DEMO") -> None:
        """Initialize Snowpark client for SPCS environments.

        Args:
            database: Snowflake database name to use.
        """
        super().__init__(database)
        self._session: Any = None

    def _get_session(self) -> Any:
        """Get or create the Snowpark session.

        Returns:
            Active Snowpark Session instance.

        Raises:
            RuntimeError: If snowflake-snowpark-python is not installed.
        """
        if self._session is not None:
            return self._session
        try:
            from snowflake.snowpark import Session
        except ImportError as exc:
            raise RuntimeError(
                "snowflake-snowpark-python is required for Snowpark mode. "
                "Install: pip install snowflake-snowpark-python"
            ) from exc

        # In SPCS, Session.builder.getOrCreate() uses the container's credentials
        self._session = Session.builder.getOrCreate()
        self._session.sql(f"USE DATABASE {self.database}").collect()
        return self._session

    def _rows_to_dicts(self, rows: list[Any]) -> list[dict[str, Any]]:
        """Convert Snowpark Row objects to list of dicts."""
        return [row.as_dict() for row in rows]

    # --- Sync ---

    def query(self, sql: str) -> list[dict[str, Any]]:
        """Execute SELECT via Snowpark session and return rows as dicts."""
        session = self._get_session()
        rows = session.sql(sql).collect()
        return self._rows_to_dicts(rows)

    def execute(self, sql: str) -> str:
        """Execute mutation/CALL via Snowpark session and return output."""
        session = self._get_session()
        rows = session.sql(sql).collect()
        if rows:
            return str(rows[0][0]) if len(rows[0]) > 0 else ""
        return ""

    # --- Async (wraps sync for Snowpark — Snowpark is synchronous) ---

    async def async_query(self, sql: str) -> list[dict[str, Any]]:
        """Execute SELECT via Snowpark in thread executor."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self.query, sql)

    async def async_execute(self, sql: str) -> str:
        """Execute mutation/CALL via Snowpark in thread executor."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self.execute, sql)

    def test_connection(self) -> bool:
        """Test connectivity by running a simple query."""
        try:
            rows = self.query("SELECT 'ok' AS status")
            return len(rows) > 0
        except Exception:
            return False


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

_client: SnowflakeClient | None = None


def get_client(
    mode: str | None = None,
    connection: str = "default",
    database: str = "HARMONIZER_DEMO",
) -> SnowflakeClient:
    """Return (and cache) the appropriate Snowflake client.

    Mode detection priority:
    1. Explicit ``mode`` argument ("connector", "cli", or "snowpark")
    2. ``SNOWFLAKE_MODE`` env var
    3. Auto-detect: if ``SNOWFLAKE_HOST`` is set (SPCS), use Snowpark; else Connector

    Modes:
        - "connector": Persistent connection via snowflake-connector-python (default, fastest)
        - "cli": Spawns `snow sql` subprocess per query (slowest, fallback)
        - "snowpark": Uses Snowpark Session (for SPCS / Snowflake-native apps)
    """
    global _client  # noqa: PLW0603
    if _client is not None:
        return _client

    if mode is None:
        mode = os.environ.get("SNOWFLAKE_MODE", "").lower()

    if mode == "snowpark":
        _client = SnowparkClient(database=database)
    elif mode == "cli":
        _client = SnowCLIClient(connection=connection, database=database)
    elif mode == "connector":
        _client = ConnectorClient(connection=connection, database=database)
    elif os.environ.get("SNOWFLAKE_HOST"):
        # Running inside SPCS — Snowpark session available
        _client = SnowparkClient(database=database)
    else:
        # Default to ConnectorClient for fastest local development
        _client = ConnectorClient(connection=connection, database=database)

    return _client


def reset_client() -> None:
    """Reset the cached client (useful for testing)."""
    global _client  # noqa: PLW0603
    _client = None
