"""Snowflake CLI (snow) wrapper for SQL execution."""

import re
import shutil
import subprocess
import sys
from pathlib import Path

from rich.progress import BarColumn, Progress, SpinnerColumn, TaskProgressColumn, TextColumn

from cli.config import state
from cli.console import console, log_error, log_info, log_success


def get_snow_command() -> list[str]:
    """Get the base snow command, detecting available installation.

    Checks for the Snowflake CLI in the system PATH. Falls back to running
    via uvx if the direct installation is not found.

    Returns:
        List of command components to invoke the snow CLI.

    Raises:
        SystemExit: If neither snow nor uvx is available on the system.
    """
    if shutil.which("snow"):
        return ["snow"]
    if shutil.which("uvx"):
        return ["uvx", "--from", "snowflake-cli-labs", "snow"]
    log_error("Snowflake CLI not found.")
    log_info("Install: pip install snowflake-cli-labs")
    log_info("Or with uv: uvx --from snowflake-cli-labs snow")
    sys.exit(1)


def snow_sql(
    query: str | None = None,
    file: Path | None = None,
    capture_output: bool = False,
) -> subprocess.CompletedProcess[str]:
    """Execute SQL via snow CLI.

    Runs a SQL query or file using the Snowflake CLI with the current
    connection from global state. Templating is disabled for security.

    Args:
        query: SQL query string to execute directly.
        file: Path to a SQL file to execute.
        capture_output: If True, capture stdout/stderr. If False, behavior
            depends on state.verbose setting.

    Returns:
        CompletedProcess with return code and captured output (if requested).

    Raises:
        ValueError: If neither query nor file is provided.
    """
    cmd = [*get_snow_command(), "sql", "--enable-templating", "NONE", "-c", state.connection]
    if query:
        cmd.extend(["-q", query])
    elif file:
        cmd.extend(["-f", str(file)])
    else:
        raise ValueError("Either query or file must be provided")

    if capture_output or not state.verbose:
        return subprocess.run(cmd, capture_output=True, text=True, check=False)
    return subprocess.run(cmd, text=True, check=False)


def snow_stage_copy(
    local_path: Path,
    stage: str,
    auto_compress: bool = False,
    recursive: bool = False,
) -> subprocess.CompletedProcess[str]:
    """Copy file to Snowflake stage.

    Uploads a local file or directory to a Snowflake stage using the CLI.
    Files are overwritten if they already exist at the destination.

    Args:
        local_path: Path to the local file or directory to upload.
        stage: Snowflake stage path (e.g., '@DB.SCHEMA.STAGE/path').
        auto_compress: Whether to automatically compress files during upload.
        recursive: Whether to recursively copy directories.

    Returns:
        CompletedProcess with return code and output.
    """
    flags = ["--overwrite"]
    if not auto_compress:
        flags.append("--no-auto-compress")
    if recursive:
        flags.append("--recursive")

    cmd = [
        *get_snow_command(),
        "stage",
        "copy",
        str(local_path),
        stage,
        "-c",
        state.connection,
        *flags,
    ]
    if state.verbose:
        return subprocess.run(cmd, text=True, check=False)
    return subprocess.run(cmd, capture_output=True, text=True, check=False)


def snow_stage_remove(
    stage_path: str,
) -> subprocess.CompletedProcess[str]:
    """Remove files from a Snowflake stage path.

    Executes a REMOVE command to delete files from the specified stage location.

    Args:
        stage_path: Snowflake stage path to remove (e.g., '@DB.SCHEMA.STAGE/file').

    Returns:
        CompletedProcess with return code and output.
    """
    cmd = [
        *get_snow_command(),
        "sql",
        "-c",
        state.connection,
        "-q",
        f"REMOVE {stage_path};",
    ]
    if state.verbose:
        return subprocess.run(cmd, text=True, check=False)
    return subprocess.run(cmd, capture_output=True, text=True, check=False)


def run_sql_file(file: Path, description: str) -> bool:
    """Run a SQL file with logging.

    Executes a SQL file and logs success or failure with the provided description.
    On failure, displays truncated stderr output (last 2000 chars).

    Args:
        file: Path to the SQL file to execute.
        description: Human-readable description for log messages.

    Returns:
        True if execution succeeded (return code 0), False otherwise.
    """
    if not file.exists():
        log_error(f"SQL file not found: {file}")
        return False

    log_info(f"{description}...")
    result = snow_sql(file=file)

    if result.returncode == 0:
        log_success(description)
        return True

    log_error(f"{description} failed")
    if result.stderr:
        print(result.stderr[-2000:] if len(result.stderr) > 2000 else result.stderr)
    if not state.verbose:
        log_info("Run with --verbose flag before the command for full output, e.g.: uv run demo --verbose setup")
    return False


def run_sql_query(query: str, description: str) -> bool:
    """Run a SQL query with logging.

    Executes a SQL query string and logs the result. On success, displays
    up to 20 lines of output. On failure, shows truncated stderr.

    Args:
        query: SQL query string to execute.
        description: Human-readable description for log messages.

    Returns:
        True if execution succeeded (return code 0), False otherwise.
    """
    log_info(f"{description}...")
    result = snow_sql(query=query)

    if result.returncode != 0:
        log_error(f"{description} failed")
        if result.stderr:
            print(result.stderr[-2000:] if len(result.stderr) > 2000 else result.stderr)
        if not state.verbose:
            log_info("Run with --verbose flag before the command for full output, e.g.: uv run demo --verbose setup")
        return False

    if state.verbose and result.stdout:
        print(result.stdout)
    elif result.stdout:
        lines = result.stdout.strip().split("\n")
        for line in lines[:20]:
            print(line)

    return True


def run_sql_file_with_progress(file: Path, description: str) -> bool:
    """Run a SQL file and parse status messages for display.

    Executes a SQL file and parses output for [INFO], [PASS], and [DONE]
    status markers, displaying them as formatted log messages.

    Args:
        file: Path to the SQL file to execute.
        description: Human-readable description for error messages.

    Returns:
        True if execution succeeded (return code 0), False otherwise.
    """
    if not file.exists():
        log_error(f"SQL file not found: {file}")
        return False

    result = snow_sql(file=file, capture_output=True)

    if result.returncode != 0:
        log_error(f"{description} failed")
        if result.stderr:
            print(result.stderr[-2000:] if len(result.stderr) > 2000 else result.stderr)
        return False

    for line in result.stdout.split("\n"):
        match = re.search(r"\|\s*\[INFO\]\s*(.+?)\s*\|", line)
        if match:
            log_info(match.group(1).strip())
            continue
        match = re.search(r"\|\s*\[PASS\]\s*(.+?)\s*\|", line)
        if match:
            log_success(match.group(1).strip())
            continue
        match = re.search(r"\|\s*\[DONE\]\s*(.+?)\s*\|", line)
        if match:
            log_success(match.group(1).strip())
            continue
        if state.verbose and line.strip():
            print(line)

    return True


def test_connection() -> bool:
    """Test Snowflake connection.

    Executes a simple SELECT query to verify the Snowflake connection
    is working with the current connection settings.

    Returns:
        True if connection test succeeded, False otherwise.
    """
    result = snow_sql(query="SELECT 'Connected' AS status", capture_output=True)
    return result.returncode == 0


def run_pipeline_with_progress(file: Path, description: str) -> bool:
    """Run the matching pipeline SQL file with real-time progress tracking.

    Parses the SQL file into phases (pre-flight, classification, matching,
    scoring, verification) and executes statements incrementally, providing
    visual feedback via Rich progress bars and spinners.

    Args:
        file: Path to the pipeline SQL file to execute.
        description: Human-readable description for progress display.

    Returns:
        True if all phases completed successfully, False on any failure.
    """
    if not file.exists():
        log_error(f"SQL file not found: {file}")
        return False

    # Parse SQL file into executable statements
    with file.open() as f:
        content = f.read()

    # Define pipeline phases based on SQL file structure
    phases = [
        {
            "name": "Pre-flight Check",
            "description": "Verifying data is loaded",
            "pattern": r"-- PRE-FLIGHT CHECK.*?(?=-- =====)",
        },
        {
            "name": "Phase 1: Classification",
            "description": "Classifying raw items into categories",
            "pattern": r"-- STEP 1: Classify.*?(?=-- =====)",
        },
        {
            "name": "Phase 2: Cortex Search Matching",
            "description": "Finding candidates using vector similarity",
            "pattern": r"-- STEP 2: Run Cortex Search.*?(?=-- =====)",
        },
        {
            "name": "Phase 3: Cosine Similarity Matching",
            "description": "Computing cosine similarity scores",
            "pattern": r"-- STEP 3: Run Cosine Similarity.*?(?=-- =====)",
        },
        {
            "name": "Phase 4: LLM Semantic Matching",
            "description": "Running semantic analysis with LLM",
            "pattern": r"-- STEP 4: Run LLM Semantic.*?(?=-- =====)",
        },
        {
            "name": "Phase 5: Ensemble Scoring",
            "description": "Computing final ensemble scores",
            "pattern": r"-- STEP 5: Compute ensemble.*?(?=-- =====)",
        },
        {
            "name": "Post-Pipeline Verification",
            "description": "Verifying results and generating statistics",
            "pattern": r"-- POST-PIPELINE VERIFICATION.*$",
        },
    ]

    console.print()
    console.print(f"[bold cyan]Starting {description}[/bold cyan]")
    console.print()

    # Extract USE statements (execute once at start)
    use_statements = re.findall(r"^(USE \w+ \w+;)", content, re.MULTILINE)
    if use_statements:
        use_block = "\n".join(use_statements)
        result = snow_sql(query=use_block, capture_output=True)
        if result.returncode != 0:
            log_error("Failed to set Snowflake context (USE statements)")
            if result.stderr:
                print(result.stderr)
            return False

    # Execute each phase
    total_phases = len(phases)
    for phase_num, phase in enumerate(phases, 1):
        console.print(f"[bold yellow]━━━ {phase['name']} ({phase_num}/{total_phases}) ━━━[/bold yellow]")
        log_info(phase["description"])

        # Extract SQL statements for this phase
        match = re.search(phase["pattern"], content, re.DOTALL)
        if not match:
            log_info(f"No statements found for {phase['name']}")
            continue

        phase_sql = match.group(0)

        # Split into individual statements (CALL and SELECT)
        statements = []
        for line in phase_sql.split("\n"):
            line = line.strip()
            if line.startswith("CALL ") or line.startswith("SELECT "):
                statements.append(line)

        if not statements:
            log_info(f"No executable statements in {phase['name']}")
            continue

        # Execute statements with progress tracking
        call_statements = [s for s in statements if s.startswith("CALL")]
        select_statements = [s for s in statements if s.startswith("SELECT")]

        # Execute CALL statements with progress bar
        if call_statements:
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                BarColumn(),
                TaskProgressColumn(),
                console=console,
            ) as progress:
                task = progress.add_task("Processing batches...", total=len(call_statements))

                for i, stmt in enumerate(call_statements, 1):
                    # Extract procedure name for better display
                    proc_match = re.search(r"CALL [\w.]+\.(\w+)\((\d+)\)", stmt)
                    if proc_match:
                        proc_name = proc_match.group(1)
                        batch_size = proc_match.group(2)
                        progress.update(
                            task,
                            description=f"{proc_name} (batch {i}/{len(call_statements)}, size={batch_size})",
                        )
                    else:
                        progress.update(task, description=f"Batch {i}/{len(call_statements)}")

                    result = snow_sql(query=stmt, capture_output=True)
                    if result.returncode != 0:
                        progress.stop()
                        log_error(f"Failed executing: {stmt}")
                        if result.stderr:
                            print(result.stderr[-2000:] if len(result.stderr) > 2000 else result.stderr)
                        return False

                    progress.advance(task)

            log_success(f"Completed {len(call_statements)} batch operations")

        # Execute SELECT statements to show intermediate results
        if select_statements:
            for stmt in select_statements:
                result = snow_sql(query=stmt, capture_output=True)
                if result.returncode == 0 and result.stdout:
                    # Display first 15 lines of output
                    lines = result.stdout.strip().split("\n")
                    for line in lines[:15]:
                        if line.strip():
                            print(f"  {line}")
                    if len(lines) > 15:
                        console.print(f"  [dim]... ({len(lines) - 15} more rows)[/dim]")

        console.print()

    log_success(f"{description} complete")
    return True
