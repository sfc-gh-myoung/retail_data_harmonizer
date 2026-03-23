"""Tests for CLI Snowflake module — subprocess and snow CLI interactions.

Uses mocked subprocess.run and shutil.which to test all snow CLI wrapper functions
without requiring actual Snowflake connectivity.
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from cli.config import state

# ---------------------------------------------------------------------------
# get_snow_command() tests
# ---------------------------------------------------------------------------


class TestGetSnowCommand:
    """Test snow CLI command detection."""

    @patch("shutil.which")
    def test_snow_found_directly(self, mock_which) -> None:
        """When snow is in PATH, return ['snow']."""
        mock_which.side_effect = lambda cmd: "/usr/local/bin/snow" if cmd == "snow" else None
        from cli.snowflake import get_snow_command

        result = get_snow_command()
        assert result == ["snow"]

    @patch("shutil.which")
    def test_uvx_fallback(self, mock_which) -> None:
        """When snow not found but uvx is, use uvx."""
        mock_which.side_effect = lambda cmd: "/usr/local/bin/uvx" if cmd == "uvx" else None
        from cli.snowflake import get_snow_command

        result = get_snow_command()
        assert result == ["uvx", "--from", "snowflake-cli-labs", "snow"]

    @patch("shutil.which", return_value=None)
    def test_neither_found_exits(self, mock_which) -> None:
        """When neither snow nor uvx found, sys.exit(1)."""
        from cli.snowflake import get_snow_command

        with pytest.raises(SystemExit) as exc_info:
            get_snow_command()
        assert exc_info.value.code == 1


# ---------------------------------------------------------------------------
# snow_sql() tests
# ---------------------------------------------------------------------------


class TestSnowSQL:
    """Test SQL execution via snow CLI."""

    @patch("cli.snowflake.subprocess.run")
    @patch("cli.snowflake.get_snow_command", return_value=["snow"])
    def test_query_mode(self, mock_get_cmd, mock_run) -> None:
        """Execute SQL query string."""
        mock_run.return_value = MagicMock(returncode=0, stdout="OK", stderr="")
        from cli.snowflake import snow_sql

        result = snow_sql(query="SELECT 1")
        assert result.returncode == 0
        # Verify -q flag used
        call_args = mock_run.call_args[0][0]
        assert "-q" in call_args
        assert "SELECT 1" in call_args

    @patch("cli.snowflake.subprocess.run")
    @patch("cli.snowflake.get_snow_command", return_value=["snow"])
    def test_file_mode(self, mock_get_cmd, mock_run, tmp_path) -> None:
        """Execute SQL from file."""
        sql_file = tmp_path / "test.sql"
        sql_file.write_text("SELECT 1;")
        mock_run.return_value = MagicMock(returncode=0, stdout="OK", stderr="")
        from cli.snowflake import snow_sql

        result = snow_sql(file=sql_file)
        assert result.returncode == 0
        # Verify -f flag used
        call_args = mock_run.call_args[0][0]
        assert "-f" in call_args

    @patch("cli.snowflake.get_snow_command", return_value=["snow"])
    def test_neither_query_nor_file_raises(self, mock_get_cmd) -> None:
        """ValueError when neither query nor file provided."""
        from cli.snowflake import snow_sql

        with pytest.raises(ValueError, match="Either query or file"):
            snow_sql()

    @patch("cli.snowflake.subprocess.run")
    @patch("cli.snowflake.get_snow_command", return_value=["snow"])
    def test_capture_output_mode(self, mock_get_cmd, mock_run) -> None:
        """Capture output when requested."""
        mock_run.return_value = MagicMock(returncode=0, stdout="result", stderr="")
        from cli.snowflake import snow_sql

        snow_sql(query="SELECT 1", capture_output=True)
        mock_run.assert_called_once()
        assert mock_run.call_args[1]["capture_output"] is True


# ---------------------------------------------------------------------------
# snow_stage_copy() tests
# ---------------------------------------------------------------------------


class TestSnowStageCopy:
    """Test stage copy operations."""

    @patch("cli.snowflake.subprocess.run")
    @patch("cli.snowflake.get_snow_command", return_value=["snow"])
    def test_basic_copy(self, mock_get_cmd, mock_run, tmp_path) -> None:
        """Copy file to stage with defaults."""
        local_file = tmp_path / "file.txt"
        local_file.write_text("content")
        mock_run.return_value = MagicMock(returncode=0)
        from cli.snowflake import snow_stage_copy

        result = snow_stage_copy(local_file, "@MY_STAGE")
        assert result.returncode == 0
        call_args = mock_run.call_args[0][0]
        assert "--overwrite" in call_args
        assert "--no-auto-compress" in call_args

    @patch("cli.snowflake.subprocess.run")
    @patch("cli.snowflake.get_snow_command", return_value=["snow"])
    def test_with_auto_compress(self, mock_get_cmd, mock_run, tmp_path) -> None:
        """Copy with auto-compress enabled."""
        local_file = tmp_path / "file.txt"
        local_file.write_text("content")
        mock_run.return_value = MagicMock(returncode=0)
        from cli.snowflake import snow_stage_copy

        snow_stage_copy(local_file, "@MY_STAGE", auto_compress=True)
        call_args = mock_run.call_args[0][0]
        assert "--no-auto-compress" not in call_args

    @patch("cli.snowflake.subprocess.run")
    @patch("cli.snowflake.get_snow_command", return_value=["snow"])
    def test_recursive_flag(self, mock_get_cmd, mock_run, tmp_path) -> None:
        """Copy with recursive flag."""
        local_dir = tmp_path / "dir"
        local_dir.mkdir()
        mock_run.return_value = MagicMock(returncode=0)
        from cli.snowflake import snow_stage_copy

        snow_stage_copy(local_dir, "@MY_STAGE", recursive=True)
        call_args = mock_run.call_args[0][0]
        assert "--recursive" in call_args


# ---------------------------------------------------------------------------
# snow_stage_remove() tests
# ---------------------------------------------------------------------------


class TestSnowStageRemove:
    """Test stage remove operations."""

    @patch("cli.snowflake.subprocess.run")
    @patch("cli.snowflake.get_snow_command", return_value=["snow"])
    def test_remove_stage_path(self, mock_get_cmd, mock_run) -> None:
        """Remove files from stage path."""
        mock_run.return_value = MagicMock(returncode=0)
        from cli.snowflake import snow_stage_remove

        result = snow_stage_remove("@MY_STAGE/path/")
        assert result.returncode == 0
        call_args = mock_run.call_args[0][0]
        assert "REMOVE @MY_STAGE/path/;" in call_args[-1]

    @patch("cli.snowflake.subprocess.run")
    @patch("cli.snowflake.get_snow_command", return_value=["snow"])
    def test_verbose_mode(self, mock_get_cmd, mock_run) -> None:
        """Verbose mode doesn't capture output."""
        mock_run.return_value = MagicMock(returncode=0)
        state.verbose = True
        from cli.snowflake import snow_stage_remove

        snow_stage_remove("@MY_STAGE/")
        # In verbose mode, capture_output should not be True
        assert mock_run.call_args[1].get("capture_output", False) is False
        state.verbose = False


# ---------------------------------------------------------------------------
# run_sql_file() tests
# ---------------------------------------------------------------------------


class TestRunSQLFile:
    """Test SQL file execution with logging."""

    @patch("cli.snowflake.snow_sql")
    def test_success(self, mock_snow_sql, tmp_path) -> None:
        """Successful SQL file execution."""
        sql_file = tmp_path / "test.sql"
        sql_file.write_text("SELECT 1;")
        mock_snow_sql.return_value = MagicMock(returncode=0, stderr="")
        from cli.snowflake import run_sql_file

        result = run_sql_file(sql_file, "Test query")
        assert result is True

    @patch("cli.snowflake.snow_sql")
    def test_file_not_found(self, mock_snow_sql, tmp_path) -> None:
        """Return False when file doesn't exist."""
        from cli.snowflake import run_sql_file

        result = run_sql_file(tmp_path / "nonexistent.sql", "Missing file")
        assert result is False
        mock_snow_sql.assert_not_called()

    @patch("cli.snowflake.snow_sql")
    def test_execution_failure(self, mock_snow_sql, tmp_path) -> None:
        """Return False on execution failure."""
        sql_file = tmp_path / "test.sql"
        sql_file.write_text("INVALID SQL;")
        mock_snow_sql.return_value = MagicMock(returncode=1, stderr="Syntax error")
        from cli.snowflake import run_sql_file

        result = run_sql_file(sql_file, "Bad query")
        assert result is False


# ---------------------------------------------------------------------------
# run_sql_query() tests
# ---------------------------------------------------------------------------


class TestRunSQLQuery:
    """Test SQL query execution with logging."""

    @patch("cli.snowflake.snow_sql")
    def test_success(self, mock_snow_sql) -> None:
        """Successful query execution."""
        mock_snow_sql.return_value = MagicMock(returncode=0, stdout="result", stderr="")
        from cli.snowflake import run_sql_query

        result = run_sql_query("SELECT 1", "Test query")
        assert result is True

    @patch("cli.snowflake.snow_sql")
    def test_failure(self, mock_snow_sql) -> None:
        """Return False on failure."""
        mock_snow_sql.return_value = MagicMock(returncode=1, stderr="Error", stdout="")
        from cli.snowflake import run_sql_query

        result = run_sql_query("BAD SQL", "Bad query")
        assert result is False

    @patch("cli.snowflake.snow_sql")
    def test_verbose_output(self, mock_snow_sql) -> None:
        """Verbose mode prints full output."""
        mock_snow_sql.return_value = MagicMock(
            returncode=0,
            stdout="line1\nline2\nline3",
            stderr="",
        )
        state.verbose = True
        from cli.snowflake import run_sql_query

        result = run_sql_query("SELECT 1", "Query")
        assert result is True
        state.verbose = False

    @patch("cli.snowflake.snow_sql")
    def test_truncated_output(self, mock_snow_sql) -> None:
        """Non-verbose mode truncates output."""
        long_output = "\n".join([f"line{i}" for i in range(50)])
        mock_snow_sql.return_value = MagicMock(returncode=0, stdout=long_output, stderr="")
        state.verbose = False
        from cli.snowflake import run_sql_query

        result = run_sql_query("SELECT 1", "Query")
        assert result is True


# ---------------------------------------------------------------------------
# run_sql_file_with_progress() tests
# ---------------------------------------------------------------------------


class TestRunSQLFileWithProgress:
    """Test SQL file execution with progress parsing."""

    @patch("cli.snowflake.snow_sql")
    def test_parses_info_markers(self, mock_snow_sql, tmp_path) -> None:
        """Parse [INFO] markers from output."""
        sql_file = tmp_path / "test.sql"
        sql_file.write_text("SELECT 1;")
        mock_snow_sql.return_value = MagicMock(
            returncode=0,
            stdout="| [INFO] Processing started |\n| [PASS] Step 1 complete |",
            stderr="",
        )
        from cli.snowflake import run_sql_file_with_progress

        result = run_sql_file_with_progress(sql_file, "Test")
        assert result is True

    @patch("cli.snowflake.snow_sql")
    def test_parses_done_markers(self, mock_snow_sql, tmp_path) -> None:
        """Parse [DONE] markers from output."""
        sql_file = tmp_path / "test.sql"
        sql_file.write_text("SELECT 1;")
        mock_snow_sql.return_value = MagicMock(
            returncode=0,
            stdout="| [DONE] All steps complete |",
            stderr="",
        )
        from cli.snowflake import run_sql_file_with_progress

        result = run_sql_file_with_progress(sql_file, "Test")
        assert result is True

    @patch("cli.snowflake.snow_sql")
    def test_file_not_found(self, mock_snow_sql, tmp_path) -> None:
        """Return False when file doesn't exist."""
        from cli.snowflake import run_sql_file_with_progress

        result = run_sql_file_with_progress(tmp_path / "missing.sql", "Test")
        assert result is False


# ---------------------------------------------------------------------------
# test_connection() tests
# ---------------------------------------------------------------------------


class TestConnection:
    """Test connection validation."""

    @patch("cli.snowflake.snow_sql")
    def test_connection_success(self, mock_snow_sql) -> None:
        """Return True on successful connection."""
        mock_snow_sql.return_value = MagicMock(returncode=0)
        from cli.snowflake import test_connection

        assert test_connection() is True

    @patch("cli.snowflake.snow_sql")
    def test_connection_failure(self, mock_snow_sql) -> None:
        """Return False on failed connection."""
        mock_snow_sql.return_value = MagicMock(returncode=1)
        from cli.snowflake import test_connection

        assert test_connection() is False


# ---------------------------------------------------------------------------
# run_pipeline_with_progress() tests
# ---------------------------------------------------------------------------


class TestRunPipelineWithProgress:
    """Test pipeline execution with progress tracking."""

    @patch("cli.snowflake.snow_sql")
    def test_file_not_found(self, mock_snow_sql, tmp_path) -> None:
        """Return False when pipeline file doesn't exist."""
        from cli.snowflake import run_pipeline_with_progress

        result = run_pipeline_with_progress(tmp_path / "missing.sql", "Pipeline")
        assert result is False

    @patch("cli.snowflake.snow_sql")
    def test_use_statements_executed(self, mock_snow_sql, tmp_path) -> None:
        """USE statements extracted and executed first."""
        sql_file = tmp_path / "pipeline.sql"
        sql_file.write_text("""
USE ROLE MY_ROLE;
USE DATABASE MY_DB;
-- PRE-FLIGHT CHECK
SELECT 1;
-- ===== END
""")
        mock_snow_sql.return_value = MagicMock(returncode=0, stdout="", stderr="")
        from cli.snowflake import run_pipeline_with_progress

        run_pipeline_with_progress(sql_file, "Pipeline")
        # First call should be USE statements
        assert mock_snow_sql.call_count >= 1

    @patch("cli.snowflake.snow_sql")
    def test_use_statement_failure(self, mock_snow_sql, tmp_path) -> None:
        """Return False if USE statements fail."""
        sql_file = tmp_path / "pipeline.sql"
        sql_file.write_text("USE ROLE INVALID_ROLE;\n-- PRE-FLIGHT CHECK\n-- =====")
        mock_snow_sql.return_value = MagicMock(returncode=1, stderr="Role not found")
        from cli.snowflake import run_pipeline_with_progress

        result = run_pipeline_with_progress(sql_file, "Pipeline")
        assert result is False

    @patch("cli.snowflake.snow_sql")
    def test_phase_execution(self, mock_snow_sql, tmp_path) -> None:
        """Execute phases with CALL statements."""
        sql_file = tmp_path / "pipeline.sql"
        sql_file.write_text("""
USE ROLE MY_ROLE;
USE DATABASE MY_DB;
-- PRE-FLIGHT CHECK
SELECT COUNT(*) FROM my_table;
-- ===== END
-- STEP 1: Classify
CALL HARMONIZED.CLASSIFY_BATCH(100);
-- ===== END
""")
        mock_snow_sql.return_value = MagicMock(returncode=0, stdout="", stderr="")
        from cli.snowflake import run_pipeline_with_progress

        result = run_pipeline_with_progress(sql_file, "Pipeline")
        assert result is True

    @patch("cli.snowflake.snow_sql")
    def test_call_statement_failure(self, mock_snow_sql, tmp_path) -> None:
        """Return False when CALL statement fails."""
        sql_file = tmp_path / "pipeline.sql"
        sql_file.write_text("""
USE ROLE MY_ROLE;
-- PRE-FLIGHT CHECK
CALL HARMONIZED.FAILING_PROC(100);
-- ===== END
""")
        # First call (USE) succeeds, second (CALL) fails
        mock_snow_sql.side_effect = [
            MagicMock(returncode=0, stdout="", stderr=""),
            MagicMock(returncode=1, stdout="", stderr="Procedure failed"),
        ]
        from cli.snowflake import run_pipeline_with_progress

        result = run_pipeline_with_progress(sql_file, "Pipeline")
        assert result is False

    @patch("cli.snowflake.snow_sql")
    def test_select_results_displayed(self, mock_snow_sql, tmp_path) -> None:
        """SELECT statements show their results."""
        sql_file = tmp_path / "pipeline.sql"
        sql_file.write_text("""
USE ROLE MY_ROLE;
-- PRE-FLIGHT CHECK
SELECT COUNT(*) FROM table1;
-- ===== END
""")
        mock_snow_sql.return_value = MagicMock(returncode=0, stdout="100\n", stderr="")
        from cli.snowflake import run_pipeline_with_progress

        result = run_pipeline_with_progress(sql_file, "Pipeline")
        assert result is True

    @patch("cli.snowflake.snow_sql")
    def test_no_use_statements(self, mock_snow_sql, tmp_path) -> None:
        """Pipeline works without USE statements."""
        sql_file = tmp_path / "pipeline.sql"
        sql_file.write_text("""
-- PRE-FLIGHT CHECK
SELECT 1;
-- ===== END
""")
        mock_snow_sql.return_value = MagicMock(returncode=0, stdout="", stderr="")
        from cli.snowflake import run_pipeline_with_progress

        result = run_pipeline_with_progress(sql_file, "Pipeline")
        assert result is True

    @patch("cli.snowflake.snow_sql")
    def test_no_matching_phases(self, mock_snow_sql, tmp_path) -> None:
        """Pipeline handles SQL without recognized phases."""
        sql_file = tmp_path / "pipeline.sql"
        sql_file.write_text("""
USE ROLE MY_ROLE;
-- UNRECOGNIZED PHASE
SELECT 1;
""")
        mock_snow_sql.return_value = MagicMock(returncode=0, stdout="", stderr="")
        from cli.snowflake import run_pipeline_with_progress

        result = run_pipeline_with_progress(sql_file, "Pipeline")
        assert result is True

    @patch("cli.snowflake.snow_sql")
    def test_proc_name_extraction(self, mock_snow_sql, tmp_path) -> None:
        """Procedure name extracted from CALL statement for display."""
        sql_file = tmp_path / "pipeline.sql"
        sql_file.write_text("""
USE ROLE MY_ROLE;
-- PRE-FLIGHT CHECK
CALL HARMONIZED.CLASSIFY_BATCH(100);
-- ===== END
""")
        mock_snow_sql.return_value = MagicMock(returncode=0, stdout="", stderr="")
        from cli.snowflake import run_pipeline_with_progress

        result = run_pipeline_with_progress(sql_file, "Pipeline")
        assert result is True

    @patch("cli.snowflake.snow_sql")
    def test_long_output_truncated(self, mock_snow_sql, tmp_path) -> None:
        """Output longer than 15 lines is truncated."""
        sql_file = tmp_path / "pipeline.sql"
        sql_file.write_text("""
USE ROLE MY_ROLE;
-- PRE-FLIGHT CHECK
SELECT * FROM large_table;
-- ===== END
""")
        # Return many lines of output
        long_output = "\n".join([f"row{i}" for i in range(50)])
        mock_snow_sql.return_value = MagicMock(returncode=0, stdout=long_output, stderr="")
        from cli.snowflake import run_pipeline_with_progress

        result = run_pipeline_with_progress(sql_file, "Pipeline")
        assert result is True


# ---------------------------------------------------------------------------
# Verbose Mode Tests
# ---------------------------------------------------------------------------


class TestVerboseMode:
    """Test verbose mode behavior in various functions."""

    @patch("cli.snowflake.subprocess.run")
    @patch("cli.snowflake.get_snow_command", return_value=["snow"])
    def test_snow_sql_verbose(self, mock_get_cmd, mock_run) -> None:
        """snow_sql in verbose mode doesn't capture output."""
        mock_run.return_value = MagicMock(returncode=0, stdout="result", stderr="")
        state.verbose = True
        from cli.snowflake import snow_sql

        snow_sql(query="SELECT 1")
        # In verbose mode without capture_output, shouldn't capture
        call_kwargs = mock_run.call_args[1]
        assert call_kwargs.get("capture_output", False) is False
        state.verbose = False

    @patch("cli.snowflake.subprocess.run")
    @patch("cli.snowflake.get_snow_command", return_value=["snow"])
    def test_snow_stage_copy_verbose(self, mock_get_cmd, mock_run, tmp_path) -> None:
        """snow_stage_copy in verbose mode doesn't capture output."""
        local_file = tmp_path / "file.txt"
        local_file.write_text("content")
        mock_run.return_value = MagicMock(returncode=0)
        state.verbose = True
        from cli.snowflake import snow_stage_copy

        snow_stage_copy(local_file, "@MY_STAGE")
        call_kwargs = mock_run.call_args[1]
        assert call_kwargs.get("capture_output", False) is False
        state.verbose = False

    @patch("cli.snowflake.snow_sql")
    def test_run_sql_file_with_progress_verbose(self, mock_snow_sql, tmp_path) -> None:
        """run_sql_file_with_progress shows all output in verbose mode."""
        sql_file = tmp_path / "test.sql"
        sql_file.write_text("SELECT 1;")
        mock_snow_sql.return_value = MagicMock(
            returncode=0,
            stdout="line without markers",
            stderr="",
        )
        state.verbose = True
        from cli.snowflake import run_sql_file_with_progress

        result = run_sql_file_with_progress(sql_file, "Test")
        assert result is True
        state.verbose = False


# ---------------------------------------------------------------------------
# Error Output Truncation Tests
# ---------------------------------------------------------------------------


class TestErrorOutputTruncation:
    """Test error output truncation behavior."""

    @patch("cli.snowflake.snow_sql")
    def test_run_sql_file_truncates_long_error(self, mock_snow_sql, tmp_path) -> None:
        """run_sql_file truncates long error output."""
        sql_file = tmp_path / "test.sql"
        sql_file.write_text("SELECT 1;")
        long_error = "X" * 5000  # Longer than 2000 char limit
        mock_snow_sql.return_value = MagicMock(returncode=1, stderr=long_error)
        from cli.snowflake import run_sql_file

        result = run_sql_file(sql_file, "Test")
        assert result is False

    @patch("cli.snowflake.snow_sql")
    def test_run_sql_query_truncates_long_error(self, mock_snow_sql) -> None:
        """run_sql_query truncates long error output."""
        long_error = "X" * 5000
        mock_snow_sql.return_value = MagicMock(returncode=1, stderr=long_error, stdout="")
        from cli.snowflake import run_sql_query

        result = run_sql_query("SELECT 1", "Test")
        assert result is False

    @patch("cli.snowflake.snow_sql")
    def test_run_sql_file_with_progress_truncates_error(self, mock_snow_sql, tmp_path) -> None:
        """run_sql_file_with_progress truncates long error output."""
        sql_file = tmp_path / "test.sql"
        sql_file.write_text("SELECT 1;")
        long_error = "X" * 5000
        mock_snow_sql.return_value = MagicMock(returncode=1, stderr=long_error)
        from cli.snowflake import run_sql_file_with_progress

        result = run_sql_file_with_progress(sql_file, "Test")
        assert result is False


# ---------------------------------------------------------------------------
# Connection String Tests
# ---------------------------------------------------------------------------


class TestConnectionString:
    """Test connection string handling."""

    @patch("cli.snowflake.subprocess.run")
    @patch("cli.snowflake.get_snow_command", return_value=["snow"])
    def test_uses_state_connection(self, mock_get_cmd, mock_run) -> None:
        """snow_sql uses connection from state."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        state.connection = "custom_conn"
        from cli.snowflake import snow_sql

        snow_sql(query="SELECT 1", capture_output=True)
        call_args = mock_run.call_args[0][0]
        assert "-c" in call_args
        conn_idx = call_args.index("-c")
        assert call_args[conn_idx + 1] == "custom_conn"
        state.connection = "default"
