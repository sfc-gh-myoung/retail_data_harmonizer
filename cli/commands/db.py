"""Database commands (up, down, verify, run)."""

from pathlib import Path
from typing import Annotated

import typer

from cli.config import Config, state
from cli.console import (
    log_connection,
    log_error,
    log_info,
    log_section,
    log_success,
    log_warning,
)
from cli.snowflake import run_sql_file, run_sql_query

app = typer.Typer(help="Database commands", no_args_is_help=True)

SQL_DIR = Config.SQL_DIR


def run_all_sql_files(directory: Path, description: str) -> None:
    """Execute all SQL files in a directory in sorted order.

    Args:
        directory: Path to directory containing SQL files
        description: Description for logging (e.g., "setup", "teardown")

    Raises:
        typer.Exit: If any SQL file fails to execute
    """
    sql_files = sorted(directory.rglob("*.sql"))
    if not sql_files:
        log_warning(f"No SQL files found in {directory}")
        return

    total = len(sql_files)
    for i, sql_file in enumerate(sql_files, 1):
        step_desc = f"[{i}/{total}] {sql_file.name}"
        if not run_sql_file(sql_file, step_desc):
            log_error(f"Failed at {sql_file.name}")
            raise typer.Exit(1)


@app.command()
def up() -> None:
    """Full database setup - runs all SQL files in sql/setup/ sequentially."""
    log_section("DATABASE SETUP")
    log_connection(state.connection)

    setup_dir = SQL_DIR / "setup"
    sql_files = sorted(setup_dir.rglob("*.sql"))

    log_info(f"This will execute {len(sql_files)} SQL files from sql/setup/:")
    for sql_file in sql_files:
        print(f"  - {sql_file.relative_to(setup_dir)}")
    print()

    if not state.force:
        confirm = typer.confirm("Start database setup?")
        if not confirm:
            log_info("Database setup cancelled.")
            raise typer.Exit(0)

    run_all_sql_files(setup_dir, "setup")

    log_success("Database setup complete")


@app.command()
def down() -> None:
    """Remove all database objects (database, warehouse, role)."""
    log_section("DATABASE TEARDOWN")
    log_connection(state.connection)

    log_warning("This will PERMANENTLY remove:")
    print(f"  - {Config.DATABASE} database (all schemas and data)")
    print(f"  - {Config.WAREHOUSE} warehouse")
    print(f"  - {Config.ROLE} role")
    print()

    if not state.force:
        confirm = typer.confirm("Are you sure you want to remove ALL database objects?")
        if not confirm:
            log_info("Teardown cancelled.")
            raise typer.Exit(0)

    run_all_sql_files(SQL_DIR / "teardown", "teardown")

    log_success("Database teardown complete")
    log_info("Run 'uv run demo db up' to redeploy")


@app.command()
def verify() -> None:
    """Verify database setup (row counts for all tables)."""
    log_section("VERIFY DATABASE")
    log_connection(state.connection)

    log_info("Checking table row counts...")

    run_sql_query(
        f"""
        USE ROLE {Config.ROLE};
        USE DATABASE {Config.DATABASE};
        USE WAREHOUSE {Config.WAREHOUSE};
        SELECT 'STANDARD_ITEMS' AS table_name, COUNT(*) AS row_count FROM RAW.STANDARD_ITEMS
        UNION ALL SELECT 'RAW_RETAIL_ITEMS', COUNT(*) FROM RAW.RAW_RETAIL_ITEMS
        UNION ALL SELECT 'STANDARD_ITEMS_EMBEDDINGS', COUNT(*) FROM RAW.STANDARD_ITEMS_EMBEDDINGS
        UNION ALL SELECT 'ITEM_MATCHES', COUNT(*) FROM HARMONIZED.ITEM_MATCHES
        UNION ALL SELECT 'MATCH_CANDIDATES', COUNT(*) FROM HARMONIZED.MATCH_CANDIDATES
        ORDER BY table_name;
        """,
        "Row counts",
    )

    log_success("Database verification complete")


@app.command()
def run(
    sql_file: Annotated[
        str, typer.Argument(help="SQL file path (e.g., sql/setup/05_taxonomy.sql or setup/05_taxonomy.sql)")
    ],
) -> None:
    """Run a specified SQL file.

    Accepts either:
      - Full path: sql/setup/05_taxonomy.sql
      - Relative to sql/: setup/05_taxonomy.sql (backward compatible)

    Examples:
        uv run demo db run sql/setup/05_taxonomy.sql
        uv run demo db run setup/05_taxonomy.sql
        uv run demo db run sql/utils/run_demo.sql
    """
    log_section(f"RUN SQL FILE: {sql_file}")
    log_connection(state.connection)

    # Build path: try as-is first, then relative to SQL_DIR for backward compatibility
    file_path = Path(sql_file)
    if not file_path.exists():
        # Try relative to SQL_DIR (backward compatibility)
        file_path = SQL_DIR / sql_file

    if not file_path.exists():
        log_error(f"SQL file not found: {sql_file}")
        log_info("Available SQL files:")
        for subdir in ["setup", "teardown", "utils"]:
            subdir_path = SQL_DIR / subdir
            if subdir_path.exists():
                print(f"  {subdir}/")
                for f in sorted(subdir_path.glob("*.sql")):
                    print(f"    - {f.name}")
        raise typer.Exit(1)

    if file_path.suffix != ".sql":
        log_error(f"File must be a .sql file: {sql_file}")
        raise typer.Exit(1)

    if not run_sql_file(file_path, f"Executing {file_path}"):
        raise typer.Exit(1)

    log_success(f"SQL file executed: {file_path}")
