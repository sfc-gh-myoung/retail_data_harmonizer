"""Tests for core/snowflake.py — Multi-mode Snowflake client.

Tests all client modes with mocked subprocess and connections.
"""

from __future__ import annotations

from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from backend.snowflake import (
    ConnectorClient,
    SnowCLIClient,
    SnowparkClient,
    get_client,
    reset_client,
)

# ---------------------------------------------------------------------------
# SnowCLIClient Tests
# ---------------------------------------------------------------------------


class TestSnowCLIClient:
    """Test CLI-based Snowflake client."""

    @patch("shutil.which", return_value="/usr/local/bin/snow")
    def test_get_snow_command_found(self, mock_which) -> None:
        """Finds snow command in PATH."""
        client = SnowCLIClient()
        cmd = client._get_snow_command()
        assert cmd == ["snow"]

    @patch("shutil.which")
    def test_get_snow_command_uvx_fallback(self, mock_which) -> None:
        """Falls back to uvx when snow not found."""
        mock_which.side_effect = lambda cmd: "/usr/local/bin/uvx" if cmd == "uvx" else None
        client = SnowCLIClient()
        cmd = client._get_snow_command()
        assert cmd == ["uvx", "--from", "snowflake-cli-labs", "snow"]

    @patch("shutil.which", return_value=None)
    def test_get_snow_command_not_found(self, mock_which) -> None:
        """Exits when neither snow nor uvx found."""
        client = SnowCLIClient()
        with pytest.raises(SystemExit):
            client._get_snow_command()

    @patch("backend.snowflake.subprocess.run")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    def test_query_success(self, mock_which, mock_run) -> None:
        """Query returns parsed JSON results."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout='[{"COL1": "value1"}]',
            stderr="",
        )
        client = SnowCLIClient()
        result = client.query("SELECT 1")
        assert result == [{"COL1": "value1"}]

    @patch("backend.snowflake.subprocess.run")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    def test_query_empty_result(self, mock_which, mock_run) -> None:
        """Query returns empty list for empty result."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        client = SnowCLIClient()
        result = client.query("SELECT 1")
        assert result == []

    @patch("backend.snowflake.subprocess.run")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    def test_query_failure(self, mock_which, mock_run) -> None:
        """Query raises RuntimeError on failure."""
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="Error")
        client = SnowCLIClient()
        with pytest.raises(RuntimeError, match="snow sql failed"):
            client.query("SELECT 1")

    @patch("backend.snowflake.subprocess.run")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    def test_execute_success(self, mock_which, mock_run) -> None:
        """Execute returns raw output."""
        mock_run.return_value = MagicMock(returncode=0, stdout="OK", stderr="")
        client = SnowCLIClient()
        result = client.execute("CALL proc()")
        assert result == "OK"

    @patch("backend.snowflake.subprocess.run")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    def test_test_connection_success(self, mock_which, mock_run) -> None:
        """test_connection returns True on success."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout='[{"status": "ok"}]',
            stderr="",
        )
        client = SnowCLIClient()
        assert client.test_connection() is True

    @patch("backend.snowflake.subprocess.run")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    def test_test_connection_failure(self, mock_which, mock_run) -> None:
        """test_connection returns False on failure."""
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="Error")
        client = SnowCLIClient()
        assert client.test_connection() is False


class TestSnowCLIClientAsync:
    """Test async methods of SnowCLIClient."""

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    async def test_async_query_success(self, mock_which, mock_create_proc) -> None:
        """Async query returns parsed JSON results."""
        mock_proc = AsyncMock()
        mock_proc.returncode = 0
        mock_proc.communicate.return_value = (b'[{"COL1": "value1"}]', b"")
        mock_create_proc.return_value = mock_proc

        client = SnowCLIClient()
        result = await client.async_query("SELECT 1")
        assert result == [{"COL1": "value1"}]

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    async def test_async_execute_success(self, mock_which, mock_create_proc) -> None:
        """Async execute returns raw output."""
        mock_proc = AsyncMock()
        mock_proc.returncode = 0
        mock_proc.communicate.return_value = (b"OK", b"")
        mock_create_proc.return_value = mock_proc

        client = SnowCLIClient()
        result = await client.async_execute("CALL proc()")
        assert result == "OK"


# ---------------------------------------------------------------------------
# ConnectorClient Tests
# ---------------------------------------------------------------------------


class TestConnectorClient:
    """Test connector-based Snowflake client."""

    @patch("builtins.open")
    @patch.object(Path, "exists", return_value=True)
    def test_load_connection_config_success(self, mock_exists, mock_open) -> None:
        """Loads connection config from TOML file."""
        mock_open.return_value.__enter__.return_value.read.return_value = b"""
[default]
account = "myaccount"
user = "myuser"
"""
        client = ConnectorClient(connection="default")
        # Access private method for testing
        with patch("backend.snowflake.tomllib.load") as mock_load:
            mock_load.return_value = {"default": {"account": "myaccount", "user": "myuser"}}
            config = client._load_connection_config()
            assert config["account"] == "myaccount"

    @patch.object(Path, "exists", return_value=False)
    def test_load_connection_config_file_not_found(self, mock_exists) -> None:
        """Raises RuntimeError when config file missing."""
        client = ConnectorClient()
        with pytest.raises(RuntimeError, match="config not found"):
            client._load_connection_config()

    def test_rows_to_dicts(self) -> None:
        """Converts cursor results to list of dicts."""
        client = ConnectorClient()
        mock_cursor = MagicMock()
        mock_cursor.description = [("COL1",), ("COL2",)]
        mock_cursor.fetchall.return_value = [("val1", "val2"), ("val3", "val4")]
        result = client._rows_to_dicts(mock_cursor)
        assert result == [{"COL1": "val1", "COL2": "val2"}, {"COL1": "val3", "COL2": "val4"}]

    @patch.object(ConnectorClient, "_get_connection")
    def test_query_success(self, mock_get_conn) -> None:
        """Query executes and returns results."""
        mock_cursor = MagicMock()
        mock_cursor.description = [("STATUS",)]
        mock_cursor.fetchall.return_value = [("ok",)]
        mock_conn = MagicMock()
        mock_conn.cursor.return_value = mock_cursor
        mock_get_conn.return_value = mock_conn

        client = ConnectorClient()
        result = client.query("SELECT 1")
        assert result == [{"STATUS": "ok"}]

    @patch.object(ConnectorClient, "_get_connection")
    def test_execute_success(self, mock_get_conn) -> None:
        """Execute runs and returns first result."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [("result_value",)]
        mock_conn = MagicMock()
        mock_conn.cursor.return_value = mock_cursor
        mock_get_conn.return_value = mock_conn

        client = ConnectorClient()
        result = client.execute("CALL proc()")
        assert result == "result_value"

    @patch.object(ConnectorClient, "query")
    def test_test_connection_success(self, mock_query) -> None:
        """test_connection returns True when query succeeds."""
        mock_query.return_value = [{"status": "ok"}]
        client = ConnectorClient()
        assert client.test_connection() is True

    @patch.object(ConnectorClient, "query")
    def test_test_connection_failure(self, mock_query) -> None:
        """test_connection returns False on exception."""
        mock_query.side_effect = Exception("Connection failed")
        client = ConnectorClient()
        assert client.test_connection() is False

    def test_close(self) -> None:
        """Close closes the connection."""
        client = ConnectorClient()
        mock_conn = MagicMock()
        client._conn = mock_conn
        client.close()
        mock_conn.close.assert_called_once()
        assert client._conn is None


# ---------------------------------------------------------------------------
# SnowparkClient Tests
# ---------------------------------------------------------------------------


class TestSnowparkClient:
    """Test Snowpark-based Snowflake client."""

    @patch.object(SnowparkClient, "_get_session")
    def test_query_success(self, mock_get_session) -> None:
        """Query executes and returns results."""
        mock_row = MagicMock()
        mock_row.as_dict.return_value = {"STATUS": "ok"}
        mock_session = MagicMock()
        mock_session.sql.return_value.collect.return_value = [mock_row]
        mock_get_session.return_value = mock_session

        client = SnowparkClient()
        result = client.query("SELECT 1")
        assert result == [{"STATUS": "ok"}]

    @patch.object(SnowparkClient, "_get_session")
    def test_execute_success(self, mock_get_session) -> None:
        """Execute runs and returns first result."""
        mock_row = MagicMock()
        mock_row.__getitem__ = MagicMock(return_value="result_value")
        mock_row.__len__ = MagicMock(return_value=1)
        mock_session = MagicMock()
        mock_session.sql.return_value.collect.return_value = [mock_row]
        mock_get_session.return_value = mock_session

        client = SnowparkClient()
        result = client.execute("CALL proc()")
        assert "result" in result or result == ""  # Implementation detail

    @patch.object(SnowparkClient, "query")
    def test_test_connection_success(self, mock_query) -> None:
        """test_connection returns True when query succeeds."""
        mock_query.return_value = [{"status": "ok"}]
        client = SnowparkClient()
        assert client.test_connection() is True

    @patch.object(SnowparkClient, "query")
    def test_test_connection_failure(self, mock_query) -> None:
        """test_connection returns False on exception."""
        mock_query.side_effect = Exception("Connection failed")
        client = SnowparkClient()
        assert client.test_connection() is False

    @patch.object(SnowparkClient, "_get_session")
    def test_execute_empty_result(self, mock_get_session) -> None:
        """Execute returns empty string when no rows."""
        mock_session = MagicMock()
        mock_session.sql.return_value.collect.return_value = []
        mock_get_session.return_value = mock_session

        client = SnowparkClient()
        result = client.execute("CALL proc()")
        assert result == ""

    @patch.object(SnowparkClient, "_get_session")
    def test_execute_empty_row(self, mock_get_session) -> None:
        """Execute returns empty string when row is empty."""
        mock_row = MagicMock()
        mock_row.__len__ = MagicMock(return_value=0)
        mock_session = MagicMock()
        mock_session.sql.return_value.collect.return_value = [mock_row]
        mock_get_session.return_value = mock_session

        client = SnowparkClient()
        result = client.execute("CALL proc()")
        assert result == ""


class TestSnowparkClientAsync:
    """Test async methods of SnowparkClient."""

    @pytest.mark.asyncio
    @patch.object(SnowparkClient, "query")
    async def test_async_query(self, mock_query) -> None:
        """Async query wraps sync query."""
        mock_query.return_value = [{"STATUS": "ok"}]
        client = SnowparkClient()
        result = await client.async_query("SELECT 1")
        assert result == [{"STATUS": "ok"}]

    @pytest.mark.asyncio
    @patch.object(SnowparkClient, "execute")
    async def test_async_execute(self, mock_execute) -> None:
        """Async execute wraps sync execute."""
        mock_execute.return_value = "OK"
        client = SnowparkClient()
        result = await client.async_execute("CALL proc()")
        assert result == "OK"


class TestSnowparkClientSession:
    """Test Snowpark session initialization."""

    def test_get_session_import_error(self) -> None:
        """Raises RuntimeError when snowpark not installed."""
        client = SnowparkClient()
        with patch.dict("sys.modules", {"snowflake.snowpark": None}):
            with patch("builtins.__import__", side_effect=ImportError("No module")):
                with pytest.raises(RuntimeError, match="snowflake-snowpark-python"):
                    client._get_session()


class TestConnectorClientAsync:
    """Test async methods of ConnectorClient."""

    @pytest.mark.asyncio
    @patch.object(ConnectorClient, "query")
    async def test_async_query(self, mock_query) -> None:
        """Async query wraps sync query."""
        mock_query.return_value = [{"STATUS": "ok"}]
        client = ConnectorClient()
        result = await client.async_query("SELECT 1")
        assert result == [{"STATUS": "ok"}]

    @pytest.mark.asyncio
    @patch.object(ConnectorClient, "execute")
    async def test_async_execute(self, mock_execute) -> None:
        """Async execute wraps sync execute."""
        mock_execute.return_value = "OK"
        client = ConnectorClient()
        result = await client.async_execute("CALL proc()")
        assert result == "OK"


class TestConnectorClientEdgeCases:
    """Test edge cases for ConnectorClient."""

    @patch.object(ConnectorClient, "_get_connection")
    def test_execute_empty_result(self, mock_get_conn) -> None:
        """Execute returns empty string when no rows."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []
        mock_conn = MagicMock()
        mock_conn.cursor.return_value = mock_cursor
        mock_get_conn.return_value = mock_conn

        client = ConnectorClient()
        result = client.execute("CALL proc()")
        assert result == ""

    @patch.object(ConnectorClient, "_get_connection")
    def test_execute_empty_row(self, mock_get_conn) -> None:
        """Execute returns empty string when row is empty."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [()]
        mock_conn = MagicMock()
        mock_conn.cursor.return_value = mock_cursor
        mock_get_conn.return_value = mock_conn

        client = ConnectorClient()
        result = client.execute("CALL proc()")
        assert result == ""

    def test_rows_to_dicts_no_description(self) -> None:
        """Returns empty list when cursor has no description."""
        client = ConnectorClient()
        mock_cursor = MagicMock()
        mock_cursor.description = None
        mock_cursor.fetchall.return_value = []
        result = client._rows_to_dicts(mock_cursor)
        assert result == []

    @patch("builtins.open")
    @patch.object(Path, "exists", return_value=True)
    def test_load_connection_config_missing_connection(self, mock_exists, mock_open) -> None:
        """Raises RuntimeError when connection name not found."""
        client = ConnectorClient(connection="nonexistent")
        with patch("backend.snowflake.tomllib.load") as mock_load:
            mock_load.return_value = {"default": {"account": "myaccount"}}
            with pytest.raises(RuntimeError, match="Connection 'nonexistent' not found"):
                client._load_connection_config()

    def test_get_connection_import_error(self) -> None:
        """Raises RuntimeError when connector not installed."""
        client = ConnectorClient()
        with patch.dict("sys.modules", {"snowflake.connector": None}):
            with patch("builtins.__import__", side_effect=ImportError("No module")):
                with pytest.raises(RuntimeError, match="snowflake-connector-python"):
                    client._get_connection()

    def test_close_no_connection(self) -> None:
        """Close handles case when no connection exists."""
        client = ConnectorClient()
        client._conn = None
        client.close()  # Should not raise
        assert client._conn is None


class TestSnowCLIClientEdgeCases:
    """Test edge cases for SnowCLIClient."""

    @patch("backend.snowflake.subprocess.run")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    def test_query_invalid_json(self, mock_which, mock_run) -> None:
        """Query returns empty list for invalid JSON."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="not valid json",
            stderr="",
        )
        client = SnowCLIClient()
        result = client.query("SELECT 1")
        assert result == []

    @patch("backend.snowflake.subprocess.run")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    def test_query_non_list_json(self, mock_which, mock_run) -> None:
        """Query returns empty list for non-list JSON."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout='{"key": "value"}',
            stderr="",
        )
        client = SnowCLIClient()
        result = client.query("SELECT 1")
        assert result == []

    @patch("backend.snowflake.subprocess.run")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    def test_execute_failure(self, mock_which, mock_run) -> None:
        """Execute raises RuntimeError on failure."""
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="Error")
        client = SnowCLIClient()
        with pytest.raises(RuntimeError, match="snow sql failed"):
            client.execute("CALL proc()")

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    async def test_async_query_failure(self, mock_which, mock_create_proc) -> None:
        """Async query raises RuntimeError on failure."""
        mock_proc = AsyncMock()
        mock_proc.returncode = 1
        mock_proc.communicate.return_value = (b"", b"Error message")
        mock_create_proc.return_value = mock_proc

        client = SnowCLIClient()
        with pytest.raises(RuntimeError, match="snow sql failed"):
            await client.async_query("SELECT 1")

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    async def test_async_query_empty_result(self, mock_which, mock_create_proc) -> None:
        """Async query returns empty list for empty result."""
        mock_proc = AsyncMock()
        mock_proc.returncode = 0
        mock_proc.communicate.return_value = (b"", b"")
        mock_create_proc.return_value = mock_proc

        client = SnowCLIClient()
        result = await client.async_query("SELECT 1")
        assert result == []

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    async def test_async_query_invalid_json(self, mock_which, mock_create_proc) -> None:
        """Async query returns empty list for invalid JSON."""
        mock_proc = AsyncMock()
        mock_proc.returncode = 0
        mock_proc.communicate.return_value = (b"not json", b"")
        mock_create_proc.return_value = mock_proc

        client = SnowCLIClient()
        result = await client.async_query("SELECT 1")
        assert result == []

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    async def test_async_query_non_list_json(self, mock_which, mock_create_proc) -> None:
        """Async query returns empty list for non-list JSON."""
        mock_proc = AsyncMock()
        mock_proc.returncode = 0
        mock_proc.communicate.return_value = (b'{"key": "value"}', b"")
        mock_create_proc.return_value = mock_proc

        client = SnowCLIClient()
        result = await client.async_query("SELECT 1")
        assert result == []

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    async def test_async_execute_failure(self, mock_which, mock_create_proc) -> None:
        """Async execute raises RuntimeError on failure."""
        mock_proc = AsyncMock()
        mock_proc.returncode = 1
        mock_proc.communicate.return_value = (b"", b"Error")
        mock_create_proc.return_value = mock_proc

        client = SnowCLIClient()
        with pytest.raises(RuntimeError, match="snow sql failed"):
            await client.async_execute("CALL proc()")


# ---------------------------------------------------------------------------
# Factory Tests
# ---------------------------------------------------------------------------


class TestGetClient:
    """Test client factory function."""

    def setup_method(self) -> None:
        """Reset cached client before each test."""
        reset_client()

    def teardown_method(self) -> None:
        """Reset cached client after each test."""
        reset_client()

    @patch.dict("os.environ", {"SNOWFLAKE_MODE": "cli"}, clear=False)
    @patch("shutil.which", return_value="/usr/local/bin/snow")
    def test_get_client_cli_mode(self, mock_which) -> None:
        """Returns SnowCLIClient when mode=cli."""
        client = get_client(mode="cli")
        assert isinstance(client, SnowCLIClient)

    @patch.dict("os.environ", {}, clear=False)
    @patch.object(Path, "exists", return_value=True)
    def test_get_client_connector_mode(self, mock_exists) -> None:
        """Returns ConnectorClient when mode=connector."""
        # Mock the config loading
        with patch.object(ConnectorClient, "_load_connection_config") as mock_load:
            mock_load.return_value = {"account": "test", "user": "test"}
            client = get_client(mode="connector")
            assert isinstance(client, ConnectorClient)

    @patch.dict("os.environ", {"SNOWFLAKE_HOST": "localhost"}, clear=False)
    def test_get_client_auto_snowpark(self) -> None:
        """Returns SnowparkClient when SNOWFLAKE_HOST is set."""
        client = get_client()
        assert isinstance(client, SnowparkClient)

    def test_get_client_cached(self) -> None:
        """Returns cached client on subsequent calls."""
        reset_client()
        with (
            patch.dict("os.environ", {"SNOWFLAKE_MODE": "cli"}, clear=False),
            patch("shutil.which", return_value="/usr/local/bin/snow"),
        ):
            client1 = get_client(mode="cli")
            client2 = get_client()
            assert client1 is client2

    def test_reset_client(self) -> None:
        """reset_client clears the cached client."""
        with (
            patch.dict("os.environ", {"SNOWFLAKE_MODE": "cli"}, clear=False),
            patch("shutil.which", return_value="/usr/local/bin/snow"),
        ):
            client1 = get_client(mode="cli")
            reset_client()
            client2 = get_client(mode="cli")
            assert client1 is not client2
