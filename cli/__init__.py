"""Retail Data Harmonizer CLI.

Cross-platform CLI for managing the Snowflake Retail Data Harmonization Demo.

Usage:
    uv run demo [OPTIONS] COMMAND [ARGS]...

Examples:
    uv run demo setup                    # Full setup: db + pipeline
    uv run demo -c myconn setup          # Setup with specific connection
    uv run demo data run                 # Run the matching pipeline
    uv run demo status                   # Check database status
"""

import os
import shutil
import subprocess
import sys
from typing import Annotated

import typer

from cli.commands import api, data, db, web
from cli.config import Config, state
from cli.console import log_connection, log_error, log_info, log_section, log_success, log_warning
from cli.snowflake import run_sql_file, run_sql_query, test_connection

app = typer.Typer(
    name="demo",
    help=f"Retail Data Harmonizer CLI v{Config.VERSION}",
    no_args_is_help=True,
)

app.add_typer(db.app, name="db")
app.add_typer(data.app, name="data")
app.add_typer(web.app, name="web")
app.add_typer(api.app, name="api")

SQL_DIR = Config.SQL_DIR


def version_callback(value: bool) -> None:
    """Print version and exit if --version flag is passed."""
    if value:
        print(f"demo version {Config.VERSION}")
        raise typer.Exit()


@app.callback()
def main(
    connection: Annotated[
        str,
        typer.Option("-c", "--connection", help="Snowflake connection name"),
    ] = "default",
    verbose: Annotated[
        bool,
        typer.Option("--verbose", help="Show verbose output"),
    ] = False,
    force: Annotated[
        bool,
        typer.Option("--force", "-f", help="Skip confirmation prompts"),
    ] = False,
    version: Annotated[
        bool | None,
        typer.Option("--version", "-V", callback=version_callback, is_eager=True, help="Show version"),
    ] = None,
) -> None:
    r"""Retail Data Harmonizer.

    A cross-platform CLI for deploying and managing the Snowflake Retail Data
    Harmonization Demo.

    \b
    Quick Start:
        uv run demo setup                # Full setup
        uv run demo data run             # Run matching pipeline
        uv run demo status               # Check status

    \b
    Environment Variables:
        FORCE=true     Skip confirmation prompts
        VERBOSE=true   Show full SQL output
        NO_COLOR=1     Disable colored output
    """
    state.connection = connection
    state.verbose = verbose or os.environ.get("VERBOSE", "").lower() == "true"
    state.force = force or os.environ.get("FORCE", "").lower() == "true"


@app.command()
def setup() -> None:
    """Full setup: database + pipeline.

    Executes all SQL files in sql/setup/ sequentially to create:
    - Database, warehouse, and role
    - Schemas (STAGING, ANALYTICS, CONFIG)
    - Tables (STANDARD_ITEMS, RAW_RETAIL_ITEMS, MATCH_RESULTS, etc.)
    - Stored procedures (SUBMIT_REVIEW, RESET_PIPELINE, etc.)
    - Snowflake Tasks for pipeline automation
    - Dynamic Tables for real-time analytics

    Side Effects:
        Creates Snowflake database objects. Prompts for confirmation unless --force.
    """
    log_section("FULL SETUP - Retail Data Harmonizer")
    log_connection(state.connection)

    setup_dir = SQL_DIR / "setup"
    sql_files = sorted(setup_dir.rglob("*.sql"))

    log_info(f"This will execute {len(sql_files)} SQL files from sql/setup/:")
    for sql_file in sql_files:
        print(f"  - {sql_file.relative_to(setup_dir)}")
    print()

    if not state.force:
        confirm = typer.confirm("Start full setup?")
        if not confirm:
            log_info("Setup cancelled.")
            raise typer.Exit(0)

    # Execute all setup SQL files in sorted order
    db.run_all_sql_files(setup_dir, "setup")

    log_section("SETUP COMPLETE")

    print("What was created:")
    print(f"  - {Config.DATABASE} database with 3 schemas (RAW, HARMONIZED, ANALYTICS)")
    print(f"  - {Config.WAREHOUSE} warehouse")
    print(f"  - {Config.ROLE} role")
    print("  - Tables: standard items, raw retail items, embeddings, matches, candidates")
    print("  - Taxonomy reference data (CATEGORY_TAXONOMY)")
    print("  - Enhanced normalization rules (NORMALIZATION_RULES)")
    print("  - Traceability junction table (RAW_TO_UNIQUE_MAP)")
    print("  - Matching pipeline (classify, embed, match, score)")
    print("  - De-duplication & fast-path (UNIQUE_DESCRIPTIONS, CONFIRMED_MATCHES)")
    print("  - Cost tracking (PIPELINE_RUNS, COST_TRACKING)")
    print("  - Parallel execution (VECTOR_PREP_BATCH, MATCH_*_BATCH procedures)")
    print("  - Task DAG (DEDUP_FASTPATH_TASK, CLASSIFY_UNIQUE_TASK, VECTOR_PREP_TASK, method tasks, ensemble)")
    print("  - Parallel Task DAG (8 tasks for method-level vector matching)")
    print("  - Stream-based processing (RAW_ITEMS_STREAM for exactly-once)")
    print("  - Conditional LLM (skips LLM when vector confidence >= 75%)")
    print("  - Task management procedures (ENABLE/DISABLE/GET_STATUS)")
    print("  - Re-evaluation procedures")
    print("  - Performance views for FastAPI dashboard")
    print("  - Utility procedures (record locking, pipeline stats, warehouse warmup)")
    print()
    print("Next steps:")
    print("  1. Run the matching pipeline: uv run demo data run")
    print("  2. Check status: uv run demo status")
    print("  3. Start the web UI: uv run demo web serve")
    print()
    print("To teardown: uv run demo teardown")


@app.command()
def teardown() -> None:
    """Full teardown: remove all database objects."""
    log_section("FULL TEARDOWN")
    log_connection(state.connection)

    log_warning("This will PERMANENTLY remove:")
    print(f"  - {Config.DATABASE} database (all schemas and data)")
    print(f"  - {Config.WAREHOUSE} warehouse")
    print(f"  - {Config.ROLE} role")
    print()

    if not state.force:
        confirm = typer.confirm("Are you sure you want to remove ALL demo objects?")
        if not confirm:
            log_info("Teardown cancelled.")
            raise typer.Exit(0)

    if not run_sql_file(SQL_DIR / "teardown" / "01_teardown.sql", "Removing all database objects"):
        raise typer.Exit(1)

    log_success("Full teardown complete")
    log_info("Run 'uv run demo setup' to redeploy")


@app.command()
def status() -> None:
    """Show database status and row counts."""
    log_section("Database Status")
    log_connection(state.connection)

    log_info("Checking database objects...")

    if not run_sql_query(
        f"""
        USE ROLE {Config.ROLE};
        USE DATABASE {Config.DATABASE};
        USE WAREHOUSE {Config.WAREHOUSE};
        SELECT
            '{Config.DATABASE}' AS database_name,
            '{Config.WAREHOUSE}' AS warehouse_name,
            CURRENT_USER() AS current_user,
            CURRENT_ROLE() AS current_role;
        """,
        "Connection info",
    ):
        log_error("Demo is not set up. Run 'uv run demo setup' to deploy.")
        raise typer.Exit(1)

    all_passed = True

    print()
    log_info("Table row counts:")

    if not run_sql_query(
        f"""
        USE DATABASE {Config.DATABASE};
        SELECT 'STANDARD_ITEMS' AS table_name, COUNT(*) AS row_count FROM RAW.STANDARD_ITEMS
        UNION ALL SELECT 'RAW_RETAIL_ITEMS', COUNT(*) FROM RAW.RAW_RETAIL_ITEMS
        UNION ALL SELECT 'STANDARD_ITEMS_EMBEDDINGS', COUNT(*) FROM RAW.STANDARD_ITEMS_EMBEDDINGS
        UNION ALL SELECT 'ITEM_MATCHES', COUNT(*) FROM HARMONIZED.ITEM_MATCHES
        UNION ALL SELECT 'MATCH_CANDIDATES', COUNT(*) FROM HARMONIZED.MATCH_CANDIDATES
        UNION ALL SELECT 'UNIQUE_DESCRIPTIONS', COUNT(*) FROM HARMONIZED.UNIQUE_DESCRIPTIONS
        UNION ALL SELECT 'CONFIRMED_MATCHES', COUNT(*) FROM HARMONIZED.CONFIRMED_MATCHES
        UNION ALL SELECT 'PIPELINE_RUNS', COUNT(*) FROM ANALYTICS.PIPELINE_RUNS
        UNION ALL SELECT 'COST_TRACKING', COUNT(*) FROM ANALYTICS.COST_TRACKING
        UNION ALL SELECT 'CATEGORY_TAXONOMY', COUNT(*) FROM RAW.CATEGORY_TAXONOMY
        ORDER BY table_name;
        """,
        "Row counts",
    ):
        all_passed = False

    print()
    log_info("Match status breakdown:")

    if not run_sql_query(
        f"""
        USE DATABASE {Config.DATABASE};
        SELECT
            COALESCE(STATUS, 'UNREVIEWED') AS status,
            COUNT(*) AS count
        FROM HARMONIZED.ITEM_MATCHES
        GROUP BY STATUS
        ORDER BY count DESC;
        """,
        "Match status",
    ):
        all_passed = False

    if all_passed:
        log_success("Status check complete")
    else:
        log_warning("Status check completed with errors")


@app.command()
def validate() -> None:
    """Check environment and Snowflake connection."""
    log_section("Environment Validation")

    all_passed = True

    log_info("Checking Python...")
    if shutil.which("python3") or shutil.which("python"):
        version = f"{sys.version_info.major}.{sys.version_info.minor}"
        log_success(f"Python {version}")
    else:
        log_error("Python 3 not found")
        all_passed = False

    log_info("Checking uv...")
    if shutil.which("uv"):
        log_success("uv installed")
    else:
        log_warning("uv not installed")

    log_info("Checking Snowflake CLI...")
    if shutil.which("snow"):
        result = subprocess.run(["snow", "--version"], capture_output=True, text=True, check=False)
        version = result.stdout.strip().split("\n")[0] if result.stdout else "unknown"
        log_success(f"Snowflake CLI: {version}")
    else:
        log_error("Snowflake CLI not installed")
        all_passed = False

    log_info(f"Testing Snowflake connection ({state.connection})...")
    if test_connection():
        log_success(f"Snowflake connection '{state.connection}' successful")
    else:
        log_error(f"Snowflake connection '{state.connection}' failed")
        log_info("Run: snow connection add")
        log_info("Or specify a different connection: uv run demo -c <name> validate")
        all_passed = False

    print()
    if all_passed:
        log_success("All required checks passed")
        print()
        print("Ready to deploy: uv run demo setup")
    else:
        log_error("Some checks failed. Please resolve issues above.")
        raise typer.Exit(1)


if __name__ == "__main__":
    app()
