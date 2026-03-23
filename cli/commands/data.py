"""Data commands (status, run pipeline, reset, ingest).

Manages the matching pipeline lifecycle and data ingestion via the Snowflake
Task DAG. All commands execute SQL against the configured Snowflake connection.

Commands:
    status: Show row counts, match status, and observability metrics.
    run: Enable and optionally trigger the matching pipeline Task DAG.
    reset: Clear all matching results (keeps seed data).
    stop: Suspend all pipeline tasks.
    ingest: Insert synthetic raw item descriptions for testing.
    normalize-rules: Manage text normalization rules (stats, list, test, export).

Side Effects:
    run: ALTER TASK (resume), EXECUTE TASK (trigger), CALL stored procedures.
    reset: TRUNCATE on ITEM_MATCHES and MATCH_CANDIDATES tables.
    stop: ALTER TASK (suspend) via DISABLE_PARALLEL_PIPELINE_TASKS.
    ingest: INSERT into RAW.RAW_RETAIL_ITEMS.
    normalize-rules export: CALL EXPORT_NORMALIZATION_RULES stored procedure.
"""

import random
import sys
import time
import uuid
from typing import Annotated

import typer

from cli.config import Config, state
from cli.console import (
    log_connection,
    log_error,
    log_info,
    log_phase,
    log_section,
    log_success,
    log_warning,
)
from cli.snowflake import run_sql_query, snow_sql

app = typer.Typer(help="Data commands", no_args_is_help=True)

SQL_DIR = Config.SQL_DIR


@app.command()
def status() -> None:
    """Show row counts, match status, and observability metrics."""
    log_section("DATA STATUS")
    log_connection(state.connection)

    log_info("Querying table row counts...")

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

    print()
    log_info("Match status breakdown:")

    run_sql_query(
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
    )

    print()
    log_info("Pipeline performance (last 24h):")

    run_sql_query(
        f"""
        USE DATABASE {Config.DATABASE};
        SELECT
            COUNT(DISTINCT RUN_ID) AS runs,
            COUNT(*) AS total_steps,
            SUM(CASE WHEN STATUS = 'COMPLETED' THEN 1 ELSE 0 END) AS completed,
            SUM(CASE WHEN STATUS = 'FAILED' THEN 1 ELSE 0 END) AS failed,
            TO_VARCHAR(MIN(START_TIME), 'MM-DD HH24:MI') AS oldest_run,
            TO_VARCHAR(MAX(END_TIME), 'MM-DD HH24:MI') AS newest_run
        FROM ANALYTICS.PIPELINE_RUN_PROGRESS
        WHERE START_TIME >= DATEADD('hour', -24, CURRENT_TIMESTAMP());
        """,
        "Pipeline performance",
    )

    print()
    log_info("Early exit effectiveness:")

    run_sql_query(
        f"""
        USE DATABASE {Config.DATABASE};
        SELECT
            COUNT(*) AS total_matches,
            SUM(CASE WHEN IS_LLM_SKIPPED THEN 1 ELSE 0 END) AS llm_skipped,
            ROUND(SUM(CASE WHEN IS_LLM_SKIPPED THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS early_exit_pct
        FROM HARMONIZED.ITEM_MATCHES
        WHERE SUGGESTED_STANDARD_ID IS NOT NULL;
        """,
        "Early exit stats",
    )

    print()
    log_info("Pipeline latency (last 5 runs):")

    run_sql_query(
        f"""
        USE DATABASE {Config.DATABASE};
        SELECT 
            TO_VARCHAR(RUN_MINUTE, 'HH24:MI') AS RUN_TIME,
            LATENCY_DISPLAY AS TOTAL,
            PREP_SECONDS || 's' AS PREP,
            CORTEX_SEARCH_SECONDS || 's' AS SEARCH,
            COSINE_SECONDS || 's' AS COSINE,
            EDIT_SECONDS || 's' AS EDIT,
            ENSEMBLE_SECONDS || 's' AS ENSEMBLE,
            RUN_STATUS AS STATUS
        FROM ANALYTICS.V_PIPELINE_LATENCY_SUMMARY
        LIMIT 5;
        """,
        "Task latency breakdown",
    )

    log_success("Data status complete")


def _get_pending_count() -> int:
    """Query the number of items still in PENDING status."""
    result = snow_sql(
        query=f"""
        USE ROLE {Config.ROLE};
        USE DATABASE {Config.DATABASE};
        USE WAREHOUSE {Config.WAREHOUSE};
        SELECT COUNT(*) AS cnt FROM RAW.RAW_RETAIL_ITEMS WHERE MATCH_STATUS = 'PENDING';
        """,
        capture_output=True,
    )
    if result.returncode != 0:
        return -1
    # Parse count from output - look for numeric value
    for line in result.stdout.strip().split("\n"):
        line = line.strip()
        if line.isdigit():
            return int(line)
    return -1


def _get_unclassified_count() -> int:
    """Query the number of pending items that still need classification.

    These are items with MATCH_STATUS='PENDING' but no INFERRED_CATEGORY.
    The pipeline cannot match these items until they are classified.
    """
    result = snow_sql(
        query=f"""
        USE ROLE {Config.ROLE};
        USE DATABASE {Config.DATABASE};
        USE WAREHOUSE {Config.WAREHOUSE};
        SELECT COUNT(*) AS cnt FROM RAW.RAW_RETAIL_ITEMS
        WHERE MATCH_STATUS = 'PENDING' AND INFERRED_CATEGORY IS NULL;
        """,
        capture_output=True,
    )
    if result.returncode != 0:
        return -1
    # Parse count from output - look for numeric value
    for line in result.stdout.strip().split("\n"):
        line = line.strip()
        if line.isdigit():
            return int(line)
    return -1


def _get_pipeline_counts() -> tuple[int, int]:
    """Query pending and matched counts for progress display.

    Returns:
        Tuple of (pending_count, matched_count). Returns (-1, -1) on error.
    """
    result = snow_sql(
        query=f"""
        USE ROLE {Config.ROLE};
        USE DATABASE {Config.DATABASE};
        USE WAREHOUSE {Config.WAREHOUSE};
        SELECT
            (SELECT COUNT(*) FROM RAW.RAW_RETAIL_ITEMS WHERE MATCH_STATUS = 'PENDING') AS pending,
            (SELECT COUNT(*) FROM HARMONIZED.ITEM_MATCHES WHERE SUGGESTED_STANDARD_ID IS NOT NULL) AS matched;
        """,
        capture_output=True,
    )
    if result.returncode != 0:
        return (-1, -1)
    # Parse "pending | matched" from tabular output
    for line in result.stdout.strip().split("\n"):
        parts = [p.strip() for p in line.split("|")]
        if len(parts) >= 2 and parts[0].isdigit() and parts[1].isdigit():
            return (int(parts[0]), int(parts[1]))
    return (-1, -1)


def _run_pipeline_step(
    step_num: int,
    total_steps: int,
    label: str,
    sql: str,
) -> tuple[bool, float]:
    """Execute a single pipeline step with timing.

    Returns:
        Tuple of (success, elapsed_seconds).
    """
    step_prefix = f"[{step_num}/{total_steps}]"
    # Print without newline for inline status update
    sys.stdout.write(f"  {step_prefix} {label}...")
    sys.stdout.flush()

    step_start = time.time()
    result = snow_sql(
        query=f"""
        USE ROLE {Config.ROLE};
        USE DATABASE {Config.DATABASE};
        USE WAREHOUSE {Config.WAREHOUSE};
        {sql}
        """,
        capture_output=True,
    )
    elapsed = time.time() - step_start

    if result.returncode != 0:
        print(f" FAILED ({elapsed:.1f}s)")
        if result.stderr:
            log_error(result.stderr[:500])
        return (False, elapsed)

    print(f" done ({elapsed:.1f}s)")
    return (True, elapsed)


@app.command()
def run(
    trigger: Annotated[
        bool, typer.Option("--trigger", "-t", help="Trigger immediate execution after enabling tasks")
    ] = True,
) -> None:
    """Start the matching pipeline via Task DAG.

    Enables the Snowflake Task DAG and optionally triggers immediate execution.
    The Task DAG runs automatically every 3 minutes when enabled.

    Pipeline architecture (parallel execution):
      DEDUP_FASTPATH_TASK (root) -> CLASSIFY_UNIQUE_TASK -> VECTOR_PREP_TASK
          -> [CORTEX_SEARCH_TASK, COSINE_MATCH_TASK, EDIT_MATCH_TASK, JACCARD_MATCH_TASK] (parallel)
          -> STAGING_MERGE_TASK (finalizer)

    Decoupled scoring tasks (run independently):
      ENSEMBLE_SCORING_TASK, LLM_TIEBREAKER_TASK, ITEM_ROUTER_TASK

    Examples:
        uv run demo data run                  # Enable tasks + trigger immediate run
        uv run demo data run --no-trigger     # Enable tasks only (wait for schedule)
    """
    log_phase("Starting Pipeline (Task DAG)")
    log_connection(state.connection)

    pending_count = _get_pending_count()
    log_info(f"Pending items: {pending_count}")

    if pending_count == 0:
        log_warning("No pending items to process")
        log_info("Use 'uv run demo data ingest' to add test data")
        return

    log_info("Enabling Task DAG...")
    result = snow_sql(
        query=f"""
        USE ROLE {Config.ROLE};
        USE DATABASE {Config.DATABASE};
        USE WAREHOUSE {Config.WAREHOUSE};
        CALL HARMONIZED.ENABLE_PARALLEL_PIPELINE_TASKS();
        """,
        capture_output=True,
    )

    if result.returncode != 0:
        log_error(f"Failed to enable tasks: {result.stderr}")
        raise typer.Exit(1)

    log_success("Task DAG enabled")

    if trigger:
        log_info("Triggering immediate execution...")
        result = snow_sql(
            query=f"""
            USE ROLE {Config.ROLE};
            USE DATABASE {Config.DATABASE};
            USE WAREHOUSE {Config.WAREHOUSE};
            EXECUTE TASK HARMONIZED.DEDUP_FASTPATH_TASK;
            """,
            capture_output=True,
        )

        if result.returncode != 0:
            log_warning(f"Trigger failed: {result.stderr}")
            log_info("Tasks are enabled and will run on schedule (every 5 minutes)")
        else:
            log_success("Pipeline triggered")

    print()
    log_info("Pipeline is running in Snowflake Task DAG")
    log_info("Tasks run every 5 minutes automatically while enabled")
    log_info("Use 'uv run demo data status' to check progress")
    log_info("Use 'uv run demo data stop' to disable tasks")


@app.command()
def reset() -> None:
    """Reset pipeline results (clear matches, keep seed data)."""
    log_phase("Resetting Pipeline")
    log_connection(state.connection)

    log_info("This will clear all matching results but keep seed data.")

    if not state.force:
        confirm = typer.confirm("Reset pipeline results?")
        if not confirm:
            log_info("Reset cancelled.")
            raise typer.Exit(0)

    run_sql_query(
        f"""
        USE ROLE {Config.ROLE};
        USE DATABASE {Config.DATABASE};
        USE WAREHOUSE {Config.WAREHOUSE};
        TRUNCATE TABLE HARMONIZED.ITEM_MATCHES;
        TRUNCATE TABLE HARMONIZED.MATCH_CANDIDATES;
        """,
        "Resetting pipeline tables",
    )

    log_success("Pipeline reset complete")
    log_info("Run 'uv run demo data run' to start the pipeline")


@app.command()
def stop() -> None:
    """Stop the pipeline by disabling all Task DAG tasks.

    This suspends all pipeline tasks, stopping automatic processing.
    Any in-progress batch will complete before the pipeline stops.

    Examples:
        uv run demo data stop
    """
    log_phase("Stopping Pipeline (Disabling Tasks)")
    log_connection(state.connection)

    log_info("Disabling Task DAG...")
    result = snow_sql(
        query=f"""
        USE ROLE {Config.ROLE};
        USE DATABASE {Config.DATABASE};
        USE WAREHOUSE {Config.WAREHOUSE};
        CALL HARMONIZED.DISABLE_PARALLEL_PIPELINE_TASKS();
        """,
        capture_output=True,
    )

    if result.returncode != 0:
        log_error(f"Failed to disable tasks: {result.stderr}")
        raise typer.Exit(1)

    log_success("Task DAG disabled")
    log_info("Pipeline tasks are now suspended")
    log_info("Use 'uv run demo data run' to restart")


# Description templates by source system for realistic ingestion
_DESCRIPTION_TEMPLATES = {
    "SYSCO": [
        "COCA COLA CLASSIC 12PK 12OZ CAN",
        "NESTLE PURE LIFE WATER 16.9OZ 24PK",
        "FRITO LAY CLASSIC MIX 18CT",
        "GATORADE THIRST QUENCHER LEMON LIME 20OZ",
        "PEPSI COLA 2 LITER BTL",
        "DORITOS NACHO CHEESE 9.25OZ",
        "LAY'S CLASSIC POTATO CHIPS 10OZ",
        "AQUAFINA PURIFIED WATER 20OZ",
        "MTN DEW ORIGINAL 12PK 12OZ",
        "SNYDER'S PRETZEL PIECES HONEY MUSTARD 12OZ",
    ],
    "US_FOODS": [
        "GTRD FRT PNCH 20Z BTL",
        "COKE CL 12P 12Z CN",
        "DRTS NCH CHS 9.25Z",
        "PPSI 2L BTL",
        "FRTO LY CLSC MX 18C",
        "NSTL PR LF WTR 16.9Z 24P",
        "AQF PUR WTR 20Z",
        "LYS CLSC PTO CHP 10Z",
        "MT DW ORGNL 12P 12Z",
        "SNDRS PRTZL PCS HNY MSTRD 12Z",
    ],
    "INTERNAL": [
        "Coca-Cola Classic 12-Pack Cans",
        "Gatorade Fruit Punch 20 oz",
        "Doritos Nacho Cheese Tortilla Chips",
        "Pepsi-Cola 2 Liter Bottle",
        "Frito-Lay Classic Mix Variety Pack",
        "Nestle Pure Life Spring Water 24pk",
        "Aquafina Water 20oz Bottle",
        "Lay's Classic Potato Chips Bag",
        "Mountain Dew Original 12pk Cans",
        "Snyder's Honey Mustard Pretzel Pieces",
    ],
    "GORDON_FOOD_SERVICE": [
        "COKE CLASSIC 12/12OZ CANS",
        "GATORADE FRT PUNCH 20OZ BTL",
        "DORITOS NACHO CHS 9.25OZ BAG",
        "PEPSI 2LTR BOTTLE",
        "FRITO LAY VARIETY 18CT BOX",
        "NESTLE WATER 16.9OZ 24/CS",
        "AQUAFINA 20OZ BOTTLE",
        "LAYS CLASSIC CHIPS 10OZ BAG",
        "MTN DEW 12/12OZ CANS",
        "SNYDERS HNY MSTD PRTZL 12OZ",
    ],
    "PERFORMANCE_FOOD_GROUP": [
        "CC CLASSIC 12PK CAN 12OZ",
        "GTRDE FRT PNCH 20Z",
        "DORI NACHO CHEESE 9.25Z",
        "PEPSI COLA 2L",
        "FL CLASSIC MIX 18CT",
        "NESTLE PL WATER 24PK 16.9OZ",
        "AQUA PURE 20OZ",
        "LAYS ORIG CHIPS 10OZ",
        "MTN DEW 12PK 12OZ CAN",
        "SNYDERS PRETZEL HM 12OZ",
    ],
}

_VARIATIONS = [
    lambda s: s.upper(),
    lambda s: s.lower(),
    lambda s: s.title(),
    lambda s: "  " + s + "  ",
    lambda s: s.replace(" ", "  "),
    lambda s: s,
]


@app.command()
def ingest(
    count: Annotated[int, typer.Option(help="Number of items to ingest")] = 50,
) -> None:
    """Ingest synthetic raw item descriptions for testing.

    Generates randomized retail item descriptions from 5 source system templates
    with text variations (casing, spacing) and inserts them in batches of 50.

    Side Effects:
        INSERT into RAW.RAW_RETAIL_ITEMS with PENDING match status.
    """
    log_phase("Ingesting Synthetic Data")
    log_connection(state.connection)

    log_info(f"Generating {count} synthetic raw items...")

    sources = list(_DESCRIPTION_TEMPLATES.keys())
    values_parts = []

    for _ in range(count):
        item_id = str(uuid.uuid4())
        source = random.choice(sources)
        desc_template = random.choice(_DESCRIPTION_TEMPLATES[source])
        variation = random.choice(_VARIATIONS)
        desc = variation(desc_template).replace("'", "''")
        values_parts.append(f"('{item_id}', '{desc}', '{source}', 'PENDING', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())")

    # Split into batches of 50 to avoid SQL size limits
    batch_size = 50
    for i in range(0, len(values_parts), batch_size):
        batch = values_parts[i : i + batch_size]
        values_sql = ",\n        ".join(batch)
        run_sql_query(
            f"""
            USE ROLE {Config.ROLE};
            USE DATABASE {Config.DATABASE};
            USE WAREHOUSE {Config.WAREHOUSE};
            INSERT INTO RAW.RAW_RETAIL_ITEMS
                (ITEM_ID, RAW_DESCRIPTION, SOURCE_SYSTEM, MATCH_STATUS, CREATED_AT, UPDATED_AT)
            VALUES
            {values_sql};
            """,
            f"Inserting batch {i // batch_size + 1}",
        )

    log_success(f"Ingested {count} items")
    log_info("Run 'uv run demo data run' to process new items")


# ---- Normalization Rules Commands (T83) ----


@app.command("normalize-rules")
def normalize_rules(
    action: Annotated[
        str,
        typer.Argument(help="Action: stats, list, test, export"),
    ] = "stats",
    rule_type: Annotated[str | None, typer.Option("--type", "-t", help="Filter by rule type")] = None,
    text: Annotated[str | None, typer.Option("--text", help="Text to test normalization")] = None,
) -> None:
    """Manage normalization rules for text preprocessing.

    Subcommands via positional action argument:
        stats: Show rule counts by type (default).
        list: List rules, optionally filtered by --type.
        test: Test normalization on --text input.
        export: Export all rules to JSON via stored procedure.
    """
    log_section("NORMALIZATION RULES")
    log_connection(state.connection)

    if action == "stats":
        log_info("Fetching normalization rule statistics...")
        run_sql_query(
            f"""
            USE ROLE {Config.ROLE};
            USE DATABASE {Config.DATABASE};
            USE WAREHOUSE {Config.WAREHOUSE};
            SELECT
                RULE_TYPE,
                COUNT(*) AS TOTAL_RULES,
                SUM(CASE WHEN IS_ACTIVE THEN 1 ELSE 0 END) AS ACTIVE_RULES,
                ROUND(AVG(PRIORITY), 1) AS AVG_PRIORITY
            FROM HARMONIZED.NORMALIZATION_RULES
            GROUP BY RULE_TYPE
            ORDER BY RULE_TYPE;
            """,
            "Rule statistics by type",
        )
        log_success("Stats complete")

    elif action == "list":
        log_info("Listing normalization rules...")
        type_filter = f"WHERE RULE_TYPE = '{rule_type}'" if rule_type else ""
        run_sql_query(
            f"""
            USE ROLE {Config.ROLE};
            USE DATABASE {Config.DATABASE};
            USE WAREHOUSE {Config.WAREHOUSE};
            SELECT RULE_TYPE, PATTERN, REPLACEMENT, PRIORITY, IS_REGEX, IS_ACTIVE
            FROM HARMONIZED.NORMALIZATION_RULES
            {type_filter}
            ORDER BY PRIORITY, RULE_TYPE
            LIMIT 50;
            """,
            "Normalization rules",
        )
        log_success("List complete")

    elif action == "test":
        if not text:
            log_info("Error: --text is required for test action")
            raise typer.Exit(1)
        log_info(f"Testing normalization on: {text}")
        safe_text = text.replace("'", "''")
        run_sql_query(
            f"""
            USE ROLE {Config.ROLE};
            USE DATABASE {Config.DATABASE};
            USE WAREHOUSE {Config.WAREHOUSE};
            SELECT
                '{safe_text}' AS INPUT_TEXT,
                HARMONIZED.APPLY_NORMALIZATION_RULES('{safe_text}') AS NORMALIZED_TEXT;
            """,
            "Normalization test",
        )
        log_success("Test complete")

    elif action == "export":
        log_info("Exporting normalization rules to JSON...")
        run_sql_query(
            f"""
            USE ROLE {Config.ROLE};
            USE DATABASE {Config.DATABASE};
            USE WAREHOUSE {Config.WAREHOUSE};
            CALL HARMONIZED.EXPORT_NORMALIZATION_RULES();
            """,
            "Exported rules",
        )
        log_success("Export complete")

    else:
        log_info(f"Unknown action: {action}")
        log_info("Valid actions: stats, list, test, export")
        raise typer.Exit(1)
