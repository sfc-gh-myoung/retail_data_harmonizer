"""Tests for CLI command modules: db.py, data.py, apps.py.

Uses CliRunner for Typer command testing with mocked Snowflake calls.
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest
from typer.testing import CliRunner

from cli.config import state

runner = CliRunner()


# ---------------------------------------------------------------------------
# DB Commands Tests (db.py)
# ---------------------------------------------------------------------------


class TestDBUpCommand:
    """Test db up command."""

    @patch("cli.commands.db.run_all_sql_files")
    @patch("cli.commands.db.typer.confirm", return_value=True)
    def test_up_with_confirmation(self, mock_confirm, mock_run_all) -> None:
        """Db up executes setup SQL files after confirmation."""
        from cli.commands.db import app

        result = runner.invoke(app, ["up"])
        assert result.exit_code == 0
        mock_run_all.assert_called_once()

    @patch("cli.commands.db.run_all_sql_files")
    @patch("cli.commands.db.typer.confirm", return_value=False)
    def test_up_cancelled(self, mock_confirm, mock_run_all) -> None:
        """Db up can be cancelled."""
        from cli.commands.db import app

        result = runner.invoke(app, ["up"])
        assert result.exit_code == 0
        mock_run_all.assert_not_called()

    @patch("cli.commands.db.run_all_sql_files")
    def test_up_with_force(self, mock_run_all) -> None:
        """Db up --force skips confirmation."""
        from cli.commands.db import app

        state.force = True
        result = runner.invoke(app, ["up"])
        state.force = False
        assert result.exit_code == 0
        mock_run_all.assert_called_once()


class TestDBDownCommand:
    """Test db down command."""

    @patch("cli.commands.db.run_all_sql_files")
    @patch("cli.commands.db.typer.confirm", return_value=True)
    def test_down_with_confirmation(self, mock_confirm, mock_run_all) -> None:
        """Db down executes teardown SQL files."""
        from cli.commands.db import app

        result = runner.invoke(app, ["down"])
        assert result.exit_code == 0
        mock_run_all.assert_called_once()

    @patch("cli.commands.db.run_all_sql_files")
    @patch("cli.commands.db.typer.confirm", return_value=False)
    def test_down_cancelled(self, mock_confirm, mock_run_all) -> None:
        """Db down can be cancelled."""
        from cli.commands.db import app

        result = runner.invoke(app, ["down"])
        assert result.exit_code == 0
        mock_run_all.assert_not_called()


class TestDBVerifyCommand:
    """Test db verify command."""

    @patch("cli.commands.db.run_sql_query", return_value=True)
    def test_verify_runs_query(self, mock_query) -> None:
        """Db verify runs verification query."""
        from cli.commands.db import app

        result = runner.invoke(app, ["verify"])
        assert result.exit_code == 0
        mock_query.assert_called_once()


class TestDBRunCommand:
    """Test db run command."""

    @patch("cli.commands.db.run_sql_file", return_value=True)
    def test_run_existing_file(self, mock_run_file, tmp_path) -> None:
        """Db run executes specified SQL file."""
        sql_file = tmp_path / "test.sql"
        sql_file.write_text("SELECT 1;")
        from cli.commands.db import app

        result = runner.invoke(app, ["run", str(sql_file)])
        assert result.exit_code == 0
        mock_run_file.assert_called_once()

    def test_run_missing_file(self) -> None:
        """Db run fails for missing file."""
        from cli.commands.db import app

        result = runner.invoke(app, ["run", "/nonexistent/file.sql"])
        assert result.exit_code == 1

    @patch("cli.commands.db.run_sql_file", return_value=True)
    def test_run_non_sql_file_fails(self, mock_run_file, tmp_path) -> None:
        """Db run rejects non-.sql files."""
        txt_file = tmp_path / "test.txt"
        txt_file.write_text("not sql")
        from cli.commands.db import app

        result = runner.invoke(app, ["run", str(txt_file)])
        assert result.exit_code == 1


class TestRunAllSQLFiles:
    """Test run_all_sql_files helper."""

    @patch("cli.commands.db.run_sql_file")
    def test_runs_all_files_in_order(self, mock_run_file, tmp_path) -> None:
        """Executes all SQL files in sorted order."""
        (tmp_path / "02_second.sql").write_text("SELECT 2;")
        (tmp_path / "01_first.sql").write_text("SELECT 1;")
        mock_run_file.return_value = True
        from cli.commands.db import run_all_sql_files

        run_all_sql_files(tmp_path, "test")
        assert mock_run_file.call_count == 2
        # Verify sorted order
        calls = [call[0][0].name for call in mock_run_file.call_args_list]
        assert calls == ["01_first.sql", "02_second.sql"]

    @patch("cli.commands.db.run_sql_file", return_value=False)
    def test_stops_on_failure(self, mock_run_file, tmp_path) -> None:
        """Stops execution on first failure."""
        (tmp_path / "01.sql").write_text("SELECT 1;")
        (tmp_path / "02.sql").write_text("SELECT 2;")
        import click

        from cli.commands.db import run_all_sql_files

        with pytest.raises(click.exceptions.Exit):
            run_all_sql_files(tmp_path, "test")
        # Should stop after first failure
        assert mock_run_file.call_count == 1


# ---------------------------------------------------------------------------
# Data Commands Tests (data.py)
# ---------------------------------------------------------------------------


class TestDataStatusCommand:
    """Test data status command."""

    @patch("cli.commands.data.run_sql_query", return_value=True)
    def test_status_runs_queries(self, mock_query) -> None:
        """Data status runs multiple status queries."""
        from cli.commands.data import app

        result = runner.invoke(app, ["status"])
        assert result.exit_code == 0
        # Multiple queries for different status sections
        assert mock_query.call_count >= 5


class TestDataRunCommand:
    """Test data run command (Task DAG)."""

    @patch("cli.commands.data.snow_sql")
    @patch("cli.commands.data._get_pending_count", return_value=100)
    def test_run_enables_tasks(self, mock_pending, mock_sql) -> None:
        """Data run enables task DAG and triggers execution."""
        mock_sql.return_value = MagicMock(returncode=0, stderr="")
        from cli.commands.data import app

        result = runner.invoke(app, ["run"])
        assert result.exit_code == 0
        assert mock_sql.call_count >= 2  # Enable + trigger

    @patch("cli.commands.data.snow_sql")
    @patch("cli.commands.data._get_pending_count", return_value=0)
    def test_run_no_pending_items(self, mock_pending, mock_sql) -> None:
        """Data run warns when no pending items."""
        from cli.commands.data import app

        result = runner.invoke(app, ["run"])
        assert result.exit_code == 0
        assert "No pending items" in result.output


class TestDataResetCommand:
    """Test data reset command."""

    @patch("cli.commands.data.run_sql_query", return_value=True)
    @patch("cli.commands.data.typer.confirm", return_value=True)
    def test_reset_with_confirmation(self, mock_confirm, mock_query) -> None:
        """Data reset truncates tables after confirmation."""
        from cli.commands.data import app

        result = runner.invoke(app, ["reset"])
        assert result.exit_code == 0
        mock_query.assert_called_once()

    @patch("cli.commands.data.run_sql_query")
    @patch("cli.commands.data.typer.confirm", return_value=False)
    def test_reset_cancelled(self, mock_confirm, mock_query) -> None:
        """Data reset can be cancelled."""
        from cli.commands.data import app

        result = runner.invoke(app, ["reset"])
        assert result.exit_code == 0
        mock_query.assert_not_called()


class TestDataStopCommand:
    """Test data stop command."""

    @patch("cli.commands.data.snow_sql")
    def test_stop_disables_tasks(self, mock_sql) -> None:
        """Data stop disables task DAG."""
        mock_sql.return_value = MagicMock(returncode=0, stderr="")
        from cli.commands.data import app

        result = runner.invoke(app, ["stop"])
        assert result.exit_code == 0


class TestDataIngestCommand:
    """Test data ingest command."""

    @patch("cli.commands.data.run_sql_query", return_value=True)
    def test_ingest_default_count(self, mock_query) -> None:
        """Data ingest with default count."""
        from cli.commands.data import app

        result = runner.invoke(app, ["ingest"])
        assert result.exit_code == 0
        # Default is 50 items

    @patch("cli.commands.data.run_sql_query", return_value=True)
    def test_ingest_custom_count(self, mock_query) -> None:
        """Data ingest with custom count."""
        from cli.commands.data import app

        result = runner.invoke(app, ["ingest", "--count", "10"])
        assert result.exit_code == 0


class TestDataNormalizeRulesCommand:
    """Test data normalize-rules command."""

    @patch("cli.commands.data.run_sql_query", return_value=True)
    def test_normalize_rules_stats(self, mock_query) -> None:
        """normalize-rules stats shows statistics."""
        from cli.commands.data import app

        result = runner.invoke(app, ["normalize-rules", "stats"])
        assert result.exit_code == 0

    @patch("cli.commands.data.run_sql_query", return_value=True)
    def test_normalize_rules_list(self, mock_query) -> None:
        """normalize-rules list shows all rules."""
        from cli.commands.data import app

        result = runner.invoke(app, ["normalize-rules", "list"])
        assert result.exit_code == 0

    @patch("cli.commands.data.run_sql_query", return_value=True)
    def test_normalize_rules_test(self, mock_query) -> None:
        """normalize-rules test applies rules to text."""
        from cli.commands.data import app

        result = runner.invoke(app, ["normalize-rules", "test", "--text", "TEST INPUT"])
        assert result.exit_code == 0

    def test_normalize_rules_test_missing_text(self) -> None:
        """normalize-rules test requires --text."""
        from cli.commands.data import app

        result = runner.invoke(app, ["normalize-rules", "test"])
        assert result.exit_code == 1


class TestDataHelpers:
    """Test data.py helper functions."""

    @patch("cli.commands.data.snow_sql")
    def test_get_pending_count_success(self, mock_sql) -> None:
        """_get_pending_count parses count from output."""
        mock_sql.return_value = MagicMock(returncode=0, stdout="100\n")
        from cli.commands.data import _get_pending_count

        assert _get_pending_count() == 100

    @patch("cli.commands.data.snow_sql")
    def test_get_pending_count_failure(self, mock_sql) -> None:
        """_get_pending_count returns -1 on failure."""
        mock_sql.return_value = MagicMock(returncode=1, stdout="")
        from cli.commands.data import _get_pending_count

        assert _get_pending_count() == -1

    @patch("cli.commands.data.snow_sql")
    def test_get_pipeline_counts_success(self, mock_sql) -> None:
        """_get_pipeline_counts parses both counts."""
        mock_sql.return_value = MagicMock(returncode=0, stdout="50 | 100\n")
        from cli.commands.data import _get_pipeline_counts

        pending, matched = _get_pipeline_counts()
        assert pending == 50
        assert matched == 100


# ---------------------------------------------------------------------------
# Data Commands Edge Cases
# ---------------------------------------------------------------------------


class TestDataRunEdgeCases:
    """Edge case tests for data run command."""

    @patch("cli.commands.data.snow_sql")
    @patch("cli.commands.data._get_pending_count", return_value=100)
    def test_run_enable_failure(self, mock_pending, mock_sql) -> None:
        """Data run fails when enabling tasks fails."""
        mock_sql.return_value = MagicMock(returncode=1, stderr="Permission denied")
        from cli.commands.data import app

        result = runner.invoke(app, ["run"])
        assert result.exit_code == 1

    @patch("cli.commands.data.snow_sql")
    @patch("cli.commands.data._get_pending_count", return_value=100)
    def test_run_trigger_failure(self, mock_pending, mock_sql) -> None:
        """Data run continues when trigger fails."""
        # First call (enable) succeeds, second (trigger) fails
        mock_sql.side_effect = [
            MagicMock(returncode=0, stderr=""),
            MagicMock(returncode=1, stderr="Trigger failed"),
        ]
        from cli.commands.data import app

        result = runner.invoke(app, ["run"])
        # Should still exit 0 because tasks are enabled
        assert result.exit_code == 0

    @patch("cli.commands.data.snow_sql")
    @patch("cli.commands.data._get_pending_count", return_value=100)
    def test_run_default_triggers(self, mock_pending, mock_sql) -> None:
        """Data run by default triggers immediate execution."""
        mock_sql.return_value = MagicMock(returncode=0, stderr="")
        from cli.commands.data import app

        result = runner.invoke(app, ["run"])
        assert result.exit_code == 0
        # Two calls: enable + trigger
        assert mock_sql.call_count == 2


class TestDataStopEdgeCases:
    """Edge case tests for data stop command."""

    @patch("cli.commands.data.snow_sql")
    def test_stop_failure(self, mock_sql) -> None:
        """Data stop fails when disabling tasks fails."""
        mock_sql.return_value = MagicMock(returncode=1, stderr="Permission denied")
        from cli.commands.data import app

        result = runner.invoke(app, ["stop"])
        assert result.exit_code == 1


class TestDataNormalizeRulesEdgeCases:
    """Edge case tests for normalize-rules command."""

    @patch("cli.commands.data.run_sql_query", return_value=True)
    def test_normalize_rules_list_with_type(self, mock_query) -> None:
        """normalize-rules list --type filters by type."""
        from cli.commands.data import app

        result = runner.invoke(app, ["normalize-rules", "list", "--type", "ABBREVIATION"])
        assert result.exit_code == 0

    @patch("cli.commands.data.run_sql_query", return_value=True)
    def test_normalize_rules_export(self, mock_query) -> None:
        """normalize-rules export calls export procedure."""
        from cli.commands.data import app

        result = runner.invoke(app, ["normalize-rules", "export"])
        assert result.exit_code == 0

    def test_normalize_rules_unknown_action(self) -> None:
        """normalize-rules unknown action shows error."""
        from cli.commands.data import app

        result = runner.invoke(app, ["normalize-rules", "unknown"])
        assert result.exit_code == 1


class TestDataHelpersEdgeCases:
    """Edge case tests for data.py helper functions."""

    @patch("cli.commands.data.snow_sql")
    def test_get_pending_count_no_digit(self, mock_sql) -> None:
        """_get_pending_count returns -1 when no digit found."""
        mock_sql.return_value = MagicMock(returncode=0, stdout="no numbers here\n")
        from cli.commands.data import _get_pending_count

        assert _get_pending_count() == -1

    @patch("cli.commands.data.snow_sql")
    def test_get_unclassified_count_success(self, mock_sql) -> None:
        """_get_unclassified_count parses count from output."""
        mock_sql.return_value = MagicMock(returncode=0, stdout="25\n")
        from cli.commands.data import _get_unclassified_count

        assert _get_unclassified_count() == 25

    @patch("cli.commands.data.snow_sql")
    def test_get_unclassified_count_failure(self, mock_sql) -> None:
        """_get_unclassified_count returns -1 on failure."""
        mock_sql.return_value = MagicMock(returncode=1, stdout="")
        from cli.commands.data import _get_unclassified_count

        assert _get_unclassified_count() == -1

    @patch("cli.commands.data.snow_sql")
    def test_get_unclassified_count_no_digit(self, mock_sql) -> None:
        """_get_unclassified_count returns -1 when no digit found."""
        mock_sql.return_value = MagicMock(returncode=0, stdout="no numbers\n")
        from cli.commands.data import _get_unclassified_count

        assert _get_unclassified_count() == -1

    @patch("cli.commands.data.snow_sql")
    def test_get_pipeline_counts_failure(self, mock_sql) -> None:
        """_get_pipeline_counts returns (-1, -1) on failure."""
        mock_sql.return_value = MagicMock(returncode=1, stdout="")
        from cli.commands.data import _get_pipeline_counts

        pending, matched = _get_pipeline_counts()
        assert pending == -1
        assert matched == -1

    @patch("cli.commands.data.snow_sql")
    def test_get_pipeline_counts_invalid_format(self, mock_sql) -> None:
        """_get_pipeline_counts returns (-1, -1) for invalid format."""
        mock_sql.return_value = MagicMock(returncode=0, stdout="invalid format\n")
        from cli.commands.data import _get_pipeline_counts

        pending, matched = _get_pipeline_counts()
        assert pending == -1
        assert matched == -1


class TestRunPipelineStep:
    """Test _run_pipeline_step helper."""

    @patch("cli.commands.data.snow_sql")
    def test_step_success(self, mock_sql) -> None:
        """_run_pipeline_step returns (True, elapsed) on success."""
        mock_sql.return_value = MagicMock(returncode=0, stderr="")
        from cli.commands.data import _run_pipeline_step

        success, elapsed = _run_pipeline_step(1, 3, "Test step", "SELECT 1")
        assert success is True
        assert elapsed >= 0

    @patch("cli.commands.data.snow_sql")
    def test_step_failure(self, mock_sql) -> None:
        """_run_pipeline_step returns (False, elapsed) on failure."""
        mock_sql.return_value = MagicMock(returncode=1, stderr="Error")
        from cli.commands.data import _run_pipeline_step

        success, elapsed = _run_pipeline_step(1, 3, "Test step", "SELECT 1")
        assert success is False
        assert elapsed >= 0


# ---------------------------------------------------------------------------
# Web Commands Tests (web.py)
# ---------------------------------------------------------------------------


class TestWebCommands:
    """Tests for web commands."""

    @patch("shutil.which", return_value=None)
    def test_check_npm_not_found(self, mock_which) -> None:
        """Test _check_npm returns False when npm not found."""
        from cli.commands.web import _check_npm

        result = _check_npm()
        assert result is False

    @patch("shutil.which", return_value="/usr/bin/npm")
    def test_check_npm_found(self, mock_which) -> None:
        """Test _check_npm returns True when npm is found."""
        from cli.commands.web import _check_npm

        result = _check_npm()
        assert result is True

    @patch("cli.commands.web._check_npm", return_value=False)
    def test_run_npm_no_npm(self, mock_check) -> None:
        """Test _run_npm returns False when npm not available."""
        from cli.commands.web import _run_npm

        result = _run_npm(["install"], "Installing")
        assert result is False

    @patch("subprocess.run")
    @patch("cli.commands.web._check_npm", return_value=True)
    @patch("cli.commands.web.REACT_DIR")
    def test_run_npm_dir_not_exists(self, mock_dir, mock_check, mock_run) -> None:
        """Test _run_npm returns False when React dir not found."""
        mock_dir.exists.return_value = False
        from cli.commands.web import _run_npm

        result = _run_npm(["install"], "Installing")
        assert result is False

    @patch("subprocess.run")
    @patch("cli.commands.web._check_npm", return_value=True)
    @patch("cli.commands.web.REACT_DIR")
    def test_run_npm_success(self, mock_dir, mock_check, mock_run) -> None:
        """Test _run_npm returns True on successful npm command."""
        mock_dir.exists.return_value = True
        mock_run.return_value = MagicMock(returncode=0)
        from cli.commands.web import _run_npm

        result = _run_npm(["install"], "Installing")
        assert result is True

    @patch("subprocess.run")
    @patch("cli.commands.web._check_npm", return_value=True)
    @patch("cli.commands.web.REACT_DIR")
    def test_run_npm_failure(self, mock_dir, mock_check, mock_run) -> None:
        """Test _run_npm returns False on failed npm command."""
        mock_dir.exists.return_value = True
        mock_run.return_value = MagicMock(returncode=1)
        from cli.commands.web import _run_npm

        result = _run_npm(["install"], "Installing")
        assert result is False

    @patch("cli.commands.web._run_npm", return_value=True)
    def test_react_install_success(self, mock_run_npm) -> None:
        """Test react-install command succeeds."""
        from cli.commands.web import app

        result = runner.invoke(app, ["react-install"])
        assert result.exit_code == 0
        mock_run_npm.assert_called_once_with(["install"], "Installing React dependencies")

    @patch("cli.commands.web._run_npm", return_value=False)
    def test_react_install_failure(self, mock_run_npm) -> None:
        """Test react-install command fails properly."""
        from cli.commands.web import app

        result = runner.invoke(app, ["react-install"])
        assert result.exit_code == 1

    @patch("cli.commands.web._run_npm", return_value=True)
    def test_react_build_success(self, mock_run_npm) -> None:
        """Test react-build command succeeds."""
        from cli.commands.web import app

        result = runner.invoke(app, ["react-build"])
        assert result.exit_code == 0
        mock_run_npm.assert_called_once_with(["run", "build"], "Building React frontend")

    @patch("cli.commands.web._run_npm", return_value=False)
    def test_react_build_failure(self, mock_run_npm) -> None:
        """Test react-build command fails properly."""
        from cli.commands.web import app

        result = runner.invoke(app, ["react-build"])
        assert result.exit_code == 1

    @patch("cli.commands.web._run_npm", return_value=True)
    def test_react_lint_success(self, mock_run_npm) -> None:
        """Test react-lint command succeeds."""
        from cli.commands.web import app

        result = runner.invoke(app, ["react-lint"])
        assert result.exit_code == 0

    @patch("cli.commands.web._run_npm", return_value=False)
    def test_react_lint_failure(self, mock_run_npm) -> None:
        """Test react-lint command fails properly."""
        from cli.commands.web import app

        result = runner.invoke(app, ["react-lint"])
        assert result.exit_code == 1


# ---------------------------------------------------------------------------
# Cache Tests (backend/services/cache.py)
# ---------------------------------------------------------------------------


class TestSyncTTLCache:
    """Tests for SyncTTLCache class."""

    def test_get_expired_returns_none(self) -> None:
        """Test get returns None for expired entries."""
        from backend.services.cache import SyncTTLCache

        cache = SyncTTLCache(ttl_seconds=0.001)
        cache.set("key", "value")

        import time

        time.sleep(0.01)  # Wait for expiry

        assert cache.get("key") is None

    def test_get_fresh_returns_value(self) -> None:
        """Test get returns value for fresh entries."""
        from backend.services.cache import SyncTTLCache

        cache = SyncTTLCache(ttl_seconds=60.0)
        cache.set("key", "value")

        assert cache.get("key") == "value"

    def test_invalidate_specific_key(self) -> None:
        """Test invalidate removes specific key."""
        from backend.services.cache import SyncTTLCache

        cache = SyncTTLCache()
        cache.set("key1", "value1")
        cache.set("key2", "value2")

        cache.invalidate("key1")

        assert cache.get("key1") is None
        assert cache.get("key2") == "value2"

    def test_invalidate_all(self) -> None:
        """Test invalidate clears all keys."""
        from backend.services.cache import SyncTTLCache

        cache = SyncTTLCache()
        cache.set("key1", "value1")
        cache.set("key2", "value2")

        cache.invalidate()

        assert cache.get("key1") is None
        assert cache.get("key2") is None

    @pytest.mark.asyncio
    async def test_get_or_fetch_cache_hit(self) -> None:
        """Test get_or_fetch returns cached value on hit."""
        from backend.services.cache import SyncTTLCache

        cache = SyncTTLCache(ttl_seconds=60.0)
        cache.set("key", "cached_value")

        fetch_called = False

        async def fetch_fn():
            nonlocal fetch_called
            fetch_called = True
            return "fresh_value"

        result = await cache.get_or_fetch("key", 60.0, fetch_fn)

        assert result == "cached_value"
        assert fetch_called is False

    @pytest.mark.asyncio
    async def test_get_or_fetch_cache_miss(self) -> None:
        """Test get_or_fetch calls fetch_fn on miss."""
        from backend.services.cache import SyncTTLCache

        cache = SyncTTLCache()

        async def fetch_fn():
            return "fresh_value"

        result = await cache.get_or_fetch("new_key", 60.0, fetch_fn)

        assert result == "fresh_value"
        assert cache.get("new_key") == "fresh_value"


class TestTTLCacheSync:
    """Tests for TTLCache sync methods."""

    def test_get_expired_returns_none(self) -> None:
        """Test sync get returns None for expired entries."""
        from backend.services.cache import TTLCache

        cache = TTLCache()
        cache._cache["key"] = (0, "value")  # Expired (timestamp in past)

        assert cache.get("key") is None

    def test_get_fresh_returns_value(self) -> None:
        """Test sync get returns value for fresh entries."""
        import time

        from backend.services.cache import TTLCache

        cache = TTLCache()
        cache._cache["key"] = (time.time() + 60, "value")

        assert cache.get("key") == "value"

    def test_set_stores_value(self) -> None:
        """Test sync set stores value with TTL."""
        from backend.services.cache import TTLCache

        cache = TTLCache()
        cache.set("key", "value", 60.0)

        assert "key" in cache._cache
        assert cache._cache["key"][1] == "value"

    def test_invalidate_specific_key(self) -> None:
        """Test invalidate removes specific key."""
        from backend.services.cache import TTLCache

        cache = TTLCache()
        cache._cache["key1"] = (float("inf"), "value1")
        cache._cache["key2"] = (float("inf"), "value2")

        cache.invalidate("key1")

        assert "key1" not in cache._cache
        assert "key2" in cache._cache
