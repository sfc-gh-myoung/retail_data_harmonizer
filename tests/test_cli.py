"""Tests for CLI commands — import, structure, and help output."""

from __future__ import annotations

from unittest.mock import patch

import pytest
from typer.testing import CliRunner

from cli import app
from cli.config import Config, State

runner = CliRunner()


# ---------------------------------------------------------------------------
# Config / State
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestConfig:
    """Test Config constants and State defaults."""

    def test_constants(self) -> None:
        """Test database, warehouse, and role constants."""
        assert Config.DATABASE == "HARMONIZER_DEMO"
        assert Config.WAREHOUSE == "HARMONIZER_DEMO_WH"
        assert Config.ROLE == "HARMONIZER_DEMO_ROLE"

    def test_schemas(self) -> None:
        """Test schema fully-qualified name constants."""
        assert Config.SCHEMA_RAW == "HARMONIZER_DEMO.RAW"
        assert Config.SCHEMA_HARMONIZED == "HARMONIZER_DEMO.HARMONIZED"
        assert Config.SCHEMA_ANALYTICS == "HARMONIZER_DEMO.ANALYTICS"

    def test_state_defaults(self) -> None:
        """Test State default values for connection, verbose, and force."""
        s = State()
        assert s.connection == "default"
        assert s.verbose is False
        assert s.force is False


# ---------------------------------------------------------------------------
# Top-level CLI
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestCLIHelp:
    """Test CLI help and version output."""

    def test_help(self) -> None:
        """Test --help flag shows help text."""
        result = runner.invoke(app, ["--help"])
        assert result.exit_code == 0
        assert "Retail Data Harmonizer" in result.output

    def test_version(self) -> None:
        """Test --version flag shows version string."""
        result = runner.invoke(app, ["--version"])
        assert result.exit_code == 0
        assert "demo version" in result.output

    def test_no_args_shows_help(self) -> None:
        """Test invoking CLI with no args shows usage info."""
        result = runner.invoke(app, [])
        # Typer exits 2 when no subcommand given — that's expected
        assert result.exit_code in (0, 2)
        assert "Usage" in result.output or "Commands" in result.output


@pytest.mark.unit
class TestCLISubcommands:
    """Verify all subcommands register correctly."""

    @pytest.mark.parametrize(
        "group",
        ["db", "data", "api", "web"],
        ids=["db-group", "data-group", "api-group", "web-group"],
    )
    def test_command_group_help(self, group) -> None:
        """Test each command group shows help output."""
        result = runner.invoke(app, [group, "--help"])
        assert result.exit_code == 0
        assert "Usage" in result.output or "Commands" in result.output

    @pytest.mark.parametrize(
        "cmd",
        ["setup", "teardown", "status", "validate"],
        ids=["setup-cmd", "teardown-cmd", "status-cmd", "validate-cmd"],
    )
    def test_top_level_commands_exist(self, cmd) -> None:
        """Test top-level commands accept --help flag."""
        result = runner.invoke(app, [cmd, "--help"])
        assert result.exit_code == 0

    @pytest.mark.parametrize(
        "subcmd",
        ["serve"],
        ids=["serve-subcmd"],
    )
    def test_web_subcommands_exist(self, subcmd) -> None:
        """Test web subcommands accept --help flag."""
        result = runner.invoke(app, ["web", subcmd, "--help"])
        assert result.exit_code == 0

    @pytest.mark.parametrize(
        "subcmd",
        ["up", "down", "verify", "run"],
        ids=["db-up", "db-down", "db-verify", "db-run"],
    )
    def test_db_subcommands_exist(self, subcmd) -> None:
        """Test db subcommands accept --help flag."""
        result = runner.invoke(app, ["db", subcmd, "--help"])
        assert result.exit_code == 0

    @pytest.mark.parametrize(
        "subcmd",
        ["run", "ingest"],
        ids=["data-run", "data-ingest"],
    )
    def test_data_subcommands_exist(self, subcmd) -> None:
        """Test data subcommands accept --help flag."""
        result = runner.invoke(app, ["data", subcmd, "--help"])
        assert result.exit_code == 0


@pytest.mark.unit
class TestCLIOptions:
    """Test CLI global options."""

    def test_connection_option(self) -> None:
        """Verify -c option is accepted."""
        result = runner.invoke(app, ["-c", "myconn", "--help"])
        assert result.exit_code == 0

    def test_force_option(self) -> None:
        """Verify --force option is accepted."""
        result = runner.invoke(app, ["--force", "--help"])
        assert result.exit_code == 0


# ---------------------------------------------------------------------------
# Console helpers
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestConsole:
    """Test console helper imports and smoke checks."""

    def test_imports(self) -> None:
        """Test console helper functions import and execute without error."""
        from cli.console import (
            log_connection,
            log_error,
            log_info,
            log_phase,
            log_section,
            log_success,
            log_warning,
        )

        # Smoke — these should not raise
        log_info("test")
        log_success("test")
        log_warning("test")
        log_error("test")
        log_section("test")
        log_phase("test")
        log_connection("default")


# ---------------------------------------------------------------------------
# Main Commands Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestSetupCommand:
    """Test setup command."""

    @patch("cli.commands.db.run_all_sql_files")
    @patch("cli.typer.confirm", return_value=True)
    def test_setup_with_confirmation(self, mock_confirm, mock_run_all) -> None:
        """Setup command runs all SQL files after confirmation."""
        result = runner.invoke(app, ["setup"])
        assert result.exit_code == 0
        mock_run_all.assert_called_once()

    @patch("cli.commands.db.run_all_sql_files")
    @patch("cli.typer.confirm", return_value=False)
    def test_setup_cancelled(self, mock_confirm, mock_run_all) -> None:
        """Setup command can be cancelled."""
        result = runner.invoke(app, ["setup"])
        assert result.exit_code == 0
        mock_run_all.assert_not_called()

    @patch("cli.commands.db.run_all_sql_files")
    def test_setup_with_force(self, mock_run_all) -> None:
        """Setup --force skips confirmation."""
        result = runner.invoke(app, ["--force", "setup"])
        assert result.exit_code == 0
        mock_run_all.assert_called_once()


@pytest.mark.unit
class TestTeardownCommand:
    """Test teardown command."""

    @patch("cli.run_sql_file", return_value=True)
    @patch("cli.typer.confirm", return_value=True)
    def test_teardown_with_confirmation(self, mock_confirm, mock_run_file) -> None:
        """Teardown command runs teardown SQL after confirmation."""
        result = runner.invoke(app, ["teardown"])
        assert result.exit_code == 0
        mock_run_file.assert_called_once()

    @patch("cli.run_sql_file")
    @patch("cli.typer.confirm", return_value=False)
    def test_teardown_cancelled(self, mock_confirm, mock_run_file) -> None:
        """Teardown command can be cancelled."""
        result = runner.invoke(app, ["teardown"])
        assert result.exit_code == 0
        mock_run_file.assert_not_called()

    @patch("cli.run_sql_file", return_value=False)
    @patch("cli.typer.confirm", return_value=True)
    def test_teardown_failure(self, mock_confirm, mock_run_file) -> None:
        """Teardown command exits on SQL failure."""
        result = runner.invoke(app, ["teardown"])
        assert result.exit_code == 1


@pytest.mark.unit
class TestStatusCommand:
    """Test status command."""

    @patch("cli.run_sql_query", return_value=True)
    def test_status_runs_queries(self, mock_query) -> None:
        """Status command runs status queries."""
        result = runner.invoke(app, ["status"])
        assert result.exit_code == 0
        # Multiple queries: connection info, row counts, match status
        assert mock_query.call_count >= 2

    @patch("cli.run_sql_query", return_value=False)
    def test_status_first_query_failure(self, mock_query) -> None:
        """Status command exits if connection fails."""
        result = runner.invoke(app, ["status"])
        assert result.exit_code == 1


@pytest.mark.unit
class TestValidateCommand:
    """Test validate command."""

    @patch("cli.test_connection", return_value=True)
    @patch("subprocess.run")
    @patch("shutil.which")
    def test_validate_all_pass(self, mock_which, mock_run, mock_test_conn) -> None:
        """Validate passes when all checks pass."""
        mock_which.side_effect = lambda cmd: f"/usr/local/bin/{cmd}"
        mock_run.return_value = type("Result", (), {"stdout": "Snowflake CLI 3.0.0", "returncode": 0})()
        result = runner.invoke(app, ["validate"])
        assert result.exit_code == 0
        assert "All required checks passed" in result.output

    @patch("cli.test_connection", return_value=False)
    @patch("subprocess.run")
    @patch("shutil.which")
    def test_validate_connection_failure(self, mock_which, mock_run, mock_test_conn) -> None:
        """Validate fails when Snowflake connection fails."""
        mock_which.side_effect = lambda cmd: f"/usr/local/bin/{cmd}"
        mock_run.return_value = type("Result", (), {"stdout": "Snowflake CLI 3.0.0", "returncode": 0})()
        result = runner.invoke(app, ["validate"])
        assert result.exit_code == 1

    @patch("cli.test_connection", return_value=True)
    @patch("shutil.which", return_value=None)
    def test_validate_missing_snow(self, mock_which, mock_test_conn) -> None:
        """Validate fails when snow CLI is missing."""
        result = runner.invoke(app, ["validate"])
        assert result.exit_code == 1


@pytest.mark.unit
class TestServeCommand:
    """Test serve command."""

    @patch("uvicorn.run")
    @patch("backend.api.snowflake_client.configure")
    def test_serve_default_options(self, mock_configure, mock_uvicorn) -> None:
        """Serve command starts uvicorn with defaults."""
        result = runner.invoke(app, ["web", "serve"])
        assert result.exit_code == 0
        mock_configure.assert_called_once()
        mock_uvicorn.assert_called_once()
        call_kwargs = mock_uvicorn.call_args[1]
        assert call_kwargs["host"] == "0.0.0.0"
        assert call_kwargs["port"] == 8000

    @patch("uvicorn.run")
    @patch("backend.api.snowflake_client.configure")
    def test_serve_custom_options(self, mock_configure, mock_uvicorn) -> None:
        """Serve command accepts custom host/port."""
        result = runner.invoke(app, ["web", "serve", "--host", "127.0.0.1", "--port", "9000"])
        assert result.exit_code == 0
        call_kwargs = mock_uvicorn.call_args[1]
        assert call_kwargs["host"] == "127.0.0.1"
        assert call_kwargs["port"] == 9000

    @patch("uvicorn.run")
    @patch("backend.api.snowflake_client.configure")
    def test_serve_with_reload(self, mock_configure, mock_uvicorn) -> None:
        """Serve command passes reload flag."""
        result = runner.invoke(app, ["web", "serve", "--reload"])
        assert result.exit_code == 0
        call_kwargs = mock_uvicorn.call_args[1]
        assert call_kwargs["reload"] is True


@pytest.mark.unit
class TestMainCallback:
    """Test main callback options."""

    @patch("cli.run_sql_query", return_value=True)
    def test_connection_option_sets_state(self, mock_query) -> None:
        """Connection option updates state."""
        from cli.config import state

        runner.invoke(app, ["-c", "myconn", "status"])
        assert state.connection == "myconn"
        # Reset
        state.connection = "default"

    @patch("cli.run_sql_query", return_value=True)
    def test_verbose_option_sets_state(self, mock_query) -> None:
        """Verbose option updates state."""
        from cli.config import state

        runner.invoke(app, ["--verbose", "status"])
        assert state.verbose is True
        # Reset
        state.verbose = False

    def test_version_callback(self) -> None:
        """Version flag shows version and exits."""
        result = runner.invoke(app, ["--version"])
        assert result.exit_code == 0
        assert "demo version" in result.output
