# SQL Setup Directory Structure

This directory contains SQL scripts organized by functional area. Scripts are executed in alphabetical/numerical order.

## Directory Layout

```
sql/setup/
├── 01_roles_and_warehouse.sql  # Database, warehouse, role, schemas
├── 02_schema_and_tables.sql    # Core table definitions
├── 03_event_views.sql          # Event and telemetry views
├── 04_telemetry.sql            # Usage tracking tables
├── 05_seed_data/               # Master and raw item data
│   ├── 05a_standard_items_beverages.sql
│   ├── 05b_standard_items_snacks.sql
│   ├── 05c_standard_items_condiments.sql
│   ├── 05d_standard_items_prepared.sql
│   ├── 05e_standard_items_grabgo.sql
│   ├── 05f_standard_items_alcohol_frozen.sql
│   ├── 05g_events.sql
│   ├── 05h_raw_items_duplicates.sql
│   ├── 05i_raw_items_stadium.sql
│   ├── 05j_raw_items_arena.sql
│   ├── 05k_raw_items_hospital.sql
│   ├── 05l_raw_items_university.sql
│   └── 05m_raw_items_corporate.sql
├── 06_category_taxonomy.sql    # Product classification
├── 07_raw_items_stream.sql     # RAW_ITEMS_STREAM (created after seed data)
├── 08_dedup_normalization.sql  # Text normalization functions
├── 09_fastpath_cache.sql       # Deduplication and fast-path cache
├── 10_item_lineage.sql         # Item lineage tracking
├── 11_matching/                # Core matching logic
│   ├── 11a_cortex_search_setup.sql
│   ├── 11b_matcher_functions.sql
│   └── 11c_ensemble_and_routing.sql
├── 12_parallel_matchers.sql    # Batch matching procedures (VECTOR_PREP, 4 match methods)
├── 13_admin_utilities.sql      # Utility stored procedures
├── 14_cost_tracking.sql        # Cost tracking and analytics views
├── 15_task_coordination.sql    # Table-based task coordination (message queue pattern)
├── 16_task_dag_definition.sql  # 10-task Snowflake Task DAG (DEDUP → CLASSIFY → PREP → 4×parallel → MERGE → ENSEMBLE → ROUTER)
├── 17_reevaluation_triggers.sql # Match reevaluation procedures
├── 18_api_views.sql            # Dashboard monitoring views + task state cache (atomic swap pattern)
├── 19_materialized_aggregates.sql # Dynamic tables for dashboard KPIs
├── 20_accuracy_testing/        # Accuracy test framework
│   ├── 20a_accuracy_tables.sql
│   ├── 20b_accuracy_procedures.sql
│   ├── 20c_accuracy_views.sql
│   └── 20d_expanded_accuracy_tests.sql
├── 21_role_grants.sql          # Permission grants
```

## Execution

The CLI automatically discovers all `.sql` files recursively:

```bash
uv run demo db up    # Executes all files in order
```

To run a specific file:
```bash
uv run demo db run sql/setup/05_seed_data/05a_standard_items_beverages.sql
```

## Naming Convention

- **Numeric prefix**: Determines execution order (01_, 02_, etc.)
- **Letter suffix**: Sub-ordering within modules (05a_, 05b_, etc.)
- **Subdirectories**: Group related scripts (e.g., `05_seed_data/`)

## Dependencies

Scripts are designed to be idempotent using:
- `CREATE OR REPLACE` for procedures, functions, views
- `CREATE TABLE IF NOT EXISTS` for tables
- `TRUNCATE TABLE IF EXISTS` before bulk inserts

## Cache Refresh Patterns

**Task State Cache** (`18_api_views.sql`):
- `TASK_STATE_CACHE` table stores cached `SHOW TASKS` results
- `V_TASK_STATE_CACHE` view provides deduplicated API access with `QUALIFY ROW_NUMBER()`
- `REFRESH_TASK_STATE_CACHE_PROC` uses **atomic swap pattern** (staging table + `ALTER TABLE SWAP`)
- Zero-downtime refresh: queries never see partial/empty state during 30-second refresh cycle
