# Architecture Guide

This document provides a comprehensive technical overview of the Retail Data Harmonizer system architecture, matching algorithms, and data flow.



## Table of Contents

- [Executive Summary](#executive-summary)
- [Introduction](#introduction)
- [System Overview](#system-overview)
- [Package Layout](#package-layout)
- [The Matching Problem](#the-matching-problem)
- [Data Flow Walkthrough](#data-flow-walkthrough)
- [Matching Algorithms Deep Dive](#matching-algorithms-deep-dive)
- [Ensemble Scoring](#ensemble-scoring)
- [Parallel Execution Architecture](#parallel-execution-architecture)
- [Task DAG Architecture](#task-dag-architecture)
- [Task Coordination (Message Queue Pattern)](#task-coordination-message-queue-pattern)
- [Accuracy Testing Framework](#accuracy-testing-framework)
- [Observability & Monitoring](#observability--monitoring)
- [Web UI Technology Stack](#web-ui-technology-stack)
- [Cost Optimization Strategies](#cost-optimization-strategies)
- [Feedback Loop and Learning](#feedback-loop-and-learning)
- [ML Feature Store Architecture](#ml-feature-store-architecture)
- [Database Schema Overview](#database-schema-overview)
- [Configuration Reference](#configuration-reference)
- [Build Automation](#build-automation)



## Executive Summary

**Quick Facts:**
- **High de-duplication ratio** on raw items (96x on demo data) before matching
- **4-method ensemble**: Cortex Search (55%), Cosine (25%), Edit Distance (12%), Jaccard (18%)
- **Root task schedule**: Every 1 minute (`CRON * * * * *`)
- **Target accuracy**: >85% on high-confidence matches

### Ensemble Formula

```
base_score = (0.55 × cortex_search) + (0.25 × cosine) + (0.12 × edit) + (0.18 × jaccard)
ensemble_score = LEAST(1.0, base_score × agreement_multiplier - subcategory_penalty)
```

**Agreement Multipliers:** 4-way = 1.20×, 3-way = 1.15×, 2-way = 1.10×

### Routing Thresholds

| Score | Status | Action |
|-------|--------|--------|
| ≥ 80% | AUTO_ACCEPTED | No review needed |
| 70-79% | AUTO_ACCEPTED | Accepted, available for spot-check |
| < 70% | PENDING_REVIEW | Routed to human review queue |

### Key Performance Characteristics

| Stage | Duration | Notes |
|-------|----------|-------|
| Prep (classify + embed) | ~40s | Set-based SQL |
| Cortex Search | ~2m | Optimized bulk INSERTs |
| Cosine Match | ~3s | Set-based SQL (parallel) |
| Edit Match | ~3s | Set-based SQL (parallel) |
| Jaccard Match | ~3s | Set-based SQL (parallel) |
| Ensemble | ~20s | 4-method weighted scoring |
| **Total** | **~3 min** | Target: <5 min per batch |

### Cost Optimizations

| Optimization | Impact |
|--------------|--------|
| De-duplication | 96x fewer AI calls on demo data |
| Fast-path cache | 0-60%+ items skip AI entirely |
| Category filter | 4x fewer vector comparisons |



## Introduction

The Retail Data Harmonizer is an AI-powered system that automatically maps unmapped retail item descriptions to a master item list (Standard Items). Built on Snowflake Cortex AI, it combines four matching algorithms into an ensemble to achieve high-accuracy matching at scale.

**Target Use Case:** Retail organizations where the same product (e.g., "20oz Coke Bottle") appears as dozens of different descriptions from different vendor POS systems.

**Key Goals:**
- Replace manual matching with automated AI matching
- Achieve >90% accuracy on high-confidence matches
- Build a feedback loop where human corrections improve future matching
- Minimize AI costs through de-duplication and caching



## System Overview

```ascii
                              RETAIL DATA HARMONIZER
    ┌────────────────────────────────────────────────────────────────────────┐
    │                                                                        │
    │   ┌─────────────┐     ┌─────────────────────────────────────────────┐  │
    │   │   RAW       │     │              HARMONIZED                     │  │
    │   │   SCHEMA    │     │              SCHEMA                         │  │
    │   │             │     │                                             │  │
    │   │ ┌─────────┐ │     │  ┌───────────────┐    ┌──────────────────┐  │  │
    │   │ │STANDARD │ │     │  │UNIQUE_        │    │CONFIRMED_        │  │  │
    │   │ │_ITEMS   │◄├─────┼──┤DESCRIPTIONS   │    │MATCHES           │  │  │
    │   │ │ (500)   │ │     │  │ (de-dup)      │    │ (fast-path cache)│  │  │
    │   │ └────┬────┘ │     │  └───────┬───────┘    └────────┬─────────┘  │  │
    │   │      │      │     │          │                     │            │  │
    │   │ ┌────▼────┐ │     │          │    ┌────────────────┘            │  │
    │   │ │STANDARD │ │     │          │    │                             │  │
    │   │ │_ITEMS_  │ │     │          │    │                             │  │
    │   │ │EMBED-   │ │     │          ▼    ▼                             │  │
    │   │ │DINGS    │ │     │  ┌───────────────────────────────────────┐  │  │
    │   │ │(vectors)│ │     │  │         MATCHING PIPELINE             │  │  │
    │   │ └─────────┘ │     │  │                                       │  │  │
    │   │             │     │  │  Step -1: Release expired locks       │  │  │
    │   │ ┌─────────┐ │     │  │  Step  0: De-duplication              │  │  │
    │   │ │RAW_     │ │     │  │  Step 0.5: Fast-path cache lookup     │  │  │
    │   │ │RETAIL_  │─┼─────┼─►│  Step  1: AI_CLASSIFY (CLASSIFY task) │  │  │
    │   │ │ITEMS    │ │     │  │  Step  2: Cortex Search (parallel)    │  │  │
    │   │ │ (12K)   │ │     │  │  Step  3: Cosine Similarity (parallel)│  │  │
    │   │ └─────────┘ │     │  │  Step  4: Edit Distance (parallel)    │  │  │
    │   │             │     │  │  Step  4: Jaccard Sim (parallel)      │  │  │
    │   │ ┌─────────┐ │     │  │  Step  5: Ensemble Scoring            │  │  │
    │   │ │CATEGORY_│ │     │  │                                       │  │  │
    │   │ │CATEGORY_│ │     │  │                                       │  │  │
    │   │ │TAXONOMY │ │     │  └───────────────┬───────────────────────┘  │  │
    │   │ └─────────┘ │     │                  │                          │  │
    │   └─────────────┘     │                  ▼                          │  │
    │                       │  ┌───────────────────────────────────────┐  │  │
    │                       │  │         ITEM_MATCHES                  │  │  │
    │                       │  │  (scores, suggested standard item)    │  │  │
    │                       │  └───────────────┬───────────────────────┘  │  │
    │                       │                  │                          │  │
    │                       └──────────────────┼──────────────────────────┘  │
    │                                          │                             │
    │   ┌──────────────────────────────────────┼──────────────────────────┐  │
    │   │              ANALYTICS SCHEMA        │                          │  │
    │   │                                      ▼                          │  │
    │   │  ┌──────────────┐    ┌──────────────────────────────────────┐   │  │
    │   │  │CONFIG        │    │         ROUTING                      │   │  │
    │   │  │ (thresholds, │    │                                      │   │  │
    │   │  │  weights)    │    │  Score >= 80%  ──► AUTO_ACCEPTED     │   │  │
    │   │  └──────────────┘    │  Score 70-79%  ──► AUTO_ACCEPTED     │   │  │
    │   │                      │                     (reviewable)     │   │  │
    │   │  ┌──────────────┐    │  Score < 70%   ──► PENDING_REVIEW    │   │  │
    │   │  │MATCH_AUDIT_  │    │                                      │   │  │
    │   │  │LOG           │◄───┴──────────────────────────────────────┘   │  │
    │   │  │ (history)    │                                               │  │
    │   │  └──────────────┘                                               │  │
    │   │                                                                 │  │
    │   │  ┌──────────────┐    ┌──────────────┐                           │  │
    │   │  │PIPELINE_RUNS │    │COST_TRACKING │                           │  │
    │   │  │ (run history)│    │ (ROI metrics)│                           │  │
    │   │  └──────────────┘    └──────────────┘                           │  │
    │   └─────────────────────────────────────────────────────────────────┘  │
    │                                                                        │
    │   ┌─────────────────────────────────────────────────────────────────┐  │
    │   │                    WEB INTERFACE                                │  │
    │   │                                                                 │  │
    │   │                          ┌──────────────────────────────┐       │  │
    │   │                          │    FASTAPI + REACT APP       │       │  │
    │   │                          │                              │       │  │
    │   │                          │  - Dashboard                 │       │  │
    │   │                          │  - Pipeline                  │       │  │
    │   │                          │  - Review Matches            │       │  │
    │   │                          │  - Test Verification         │       │  │
    │   │                          │  - Algorithm Comparison      │       │  │
    │   │                          │  - Logs                      │       │  │
    │   │                          │  - Settings                  │       │  │
    │   │                          └──────────────────────────────┘       │  │
    │   └─────────────────────────────────────────────────────────────────┘  │
    └────────────────────────────────────────────────────────────────────────┘
```



## Package Layout

The project uses a **flat package structure** with clear separation of concerns. Top-level directories are organized by role rather than nested under a single namespace package.

```ascii
retail_data_harmonizer/
├── cli/                 # CLI layer (Typer) — entry point: demo = "cli:app"
│   ├── __init__.py      # Typer app factory, top-level commands
│   ├── config.py        # Configuration management
│   ├── console.py       # Rich console output helpers
│   ├── snowflake.py     # Snowflake connection helpers
│   └── commands/        # Subcommand groups (data, db, web, apps, api)
│
├── backend/             # Backend services
│   ├── __init__.py
│   ├── snowflake.py     # Shared Snowflake connection utilities
│   └── api/             # FastAPI application
│       ├── __init__.py  # FastAPI app factory, middleware, route registration
│       ├── deps.py      # Dependency injection (Snowflake sessions, etc.)
│       ├── snowflake_client.py  # Query client for Snowflake operations
│       └── routes/      # Route modules (dashboard, pipeline, review, etc.)
│
├── frontend/            # Frontend implementations
│   └── react/           # Client-rendered React/TypeScript frontend
│       ├── src/         # App.tsx, components, hooks, API client, types
│       └── vite.config.ts
│
├── docker/              # Container configurations
│   ├── Dockerfile.api   # API-only image (backend only)
│   ├── Dockerfile.react # React frontend image (Vite build)
│   ├── docker-compose.yml  # Multi-service orchestration
│   └── nginx.conf       # Reverse proxy for API + frontend routing
│
└── sql/                 # Snowflake SQL (numbered execution order)
```

### Separation of Concerns

| Directory | Responsibility | Depends On |
|-----------|---------------|------------|
| `cli/` | User-facing CLI commands, orchestration | `backend/` |
| `backend/api/` | HTTP API (FastAPI), REST endpoints | `backend/snowflake` |
| `frontend/react/` | Client-rendered UI (React 19 + TypeScript + Vite) | REST API from `backend/api/` |
| `docker/` | Container images and orchestration | All of the above |
| `sql/` | Database DDL, procedures, seed data | Snowflake only |

### Build Configuration

The `pyproject.toml` registers two packages for wheel builds:

```toml
[tool.hatch.build.targets.wheel]
packages = ["cli", "backend"]

[project.scripts]
demo = "cli:app"
```

The `frontend/` directory is not a Python package — it contains the standalone Vite/React app.

### Docker Setup

The `docker/` directory provides two Dockerfile variants for different deployment scenarios:

- **`Dockerfile.api`** — API-only container (headless mode, for programmatic access)
- **`Dockerfile.react`** — React SPA built with Vite, served via nginx

The `docker-compose.yml` orchestrates all services together, with `nginx.conf` routing traffic between the API backend and frontend containers.

### Frontend Architecture

The frontend is a React 19 single-page application built with TypeScript and Vite.

| Stack | Technology |
|-------|-----------|
| Framework | React 19 + TypeScript 5.9 |
| Build Tool | Vite 7 |
| UI Components | shadcn/ui (Radix UI) + Tailwind CSS 4 |
| State Management | TanStack Query 5 (server), Zustand 5 (client) |
| Routing | React Router DOM 6 |

The React frontend consumes the FastAPI backend via REST endpoints.



## The Matching Problem

### Why Retail Item Matching is Hard

Retail data comes from dozens of different point-of-sale systems (Micros, Clover, NCR, etc.), each with its own data entry conventions. A single product can appear in countless variations:

**Example: A 20oz Coca-Cola Bottle**
```
Source System     Description
─────────────     ───────────────────────────────
Micros POS        COKE 20OZ BTL
Clover            Coca-Cola Classic 20 oz
NCR               20 OZ COCA COLA
Manual Entry      coke bottle (20oz)
Imported Data     COCA-COLA 20OZ BOTTLE CLASSIC
Abbreviated       CK20BTL
```

**Challenges:**
1. **Inconsistent formatting** — ALL CAPS vs. Title Case vs. lowercase
2. **Abbreviations** — "BTL", "OZ", "CK" vs. full words
3. **Missing information** — brand names omitted, sizes not standardized
4. **Typos and errors** — "Coca Cola" vs. "Cocacola" vs. "Coka Cola"
5. **Extra information** — promotional text, location codes, timestamps

### Scale Challenges

At production scale, de-duplication is the single biggest cost optimization. On the included demo data:
- **~10,000** raw item descriptions
- **~650** unique descriptions after de-duplication (93% reduction)
- Multiple source systems with different data conventions

The manual mapping process is typically:
- Expensive and labor-intensive
- **~75% accuracy** (human fatigue, inconsistency)
- **Zero learning** — the same item gets re-mapped every time



## Data Flow Walkthrough

The pipeline processes items in a carefully optimized sequence, with two cost-saving steps before any AI matching occurs.

### Step -1: Release Expired Locks

Before processing, the pipeline cleans up review locks that have timed out (15-minute default). This prevents orphaned locks from blocking the review queue.

```sql
UPDATE HARMONIZED.ITEM_MATCHES
SET LOCKED_BY = NULL, LOCKED_AT = NULL, LOCK_EXPIRES_AT = NULL
WHERE LOCK_EXPIRES_AT < CURRENT_TIMESTAMP()
  AND LOCKED_BY IS NOT NULL;
```

### Step 0: De-duplication and Normalization

**Purpose:** Collapse millions of raw items to thousands of unique descriptions.

**Normalization rules:**
1. Convert to UPPERCASE
2. TRIM leading/trailing whitespace
3. Collapse multiple spaces to single space

**Example:**
```
Input descriptions:
  "  Coke 20oz   bottle  "
  "COKE 20OZ BOTTLE"
  "coke 20oz bottle"

Normalized output:
  "COKE 20OZ BOTTLE"
```

**Impact (demo data):**
```
~10,000 raw items
       ↓ normalize + de-duplicate
   ~650 unique descriptions (93% reduction)
```

This means AI matching runs against unique descriptions instead of every raw item — **the single biggest cost optimization**.

### Step 0.5: Confirmed-Match Fast-Path

**Purpose:** Skip AI entirely for descriptions previously confirmed by a human reviewer.

When a reviewer confirms a match, the mapping is cached in `CONFIRMED_MATCHES`:
```
NORMALIZED_DESCRIPTION          STANDARD_ITEM_ID    CONFIRMED_BY
──────────────────────          ────────────────    ────────────
COKE 20OZ BOTTLE                STD-001234          jsmith
PEPSI 12 PACK CANS              STD-005678          mjones
```

On subsequent pipeline runs, any raw item matching a cached description:
- Gets an **instant match** with `MATCH_METHOD = 'FAST_PATH'`
- Marked `IS_CACHED = TRUE`
- **Zero AI cost** — no embeddings, no vector computations

As more reviews accumulate, the fast-path hit rate increases, continuously reducing AI costs.

### Step 1: Category Pre-Filter (CLASSIFY_UNIQUE_TASK / AI_CLASSIFY)

**Purpose:** Classify unique descriptions into category + subcategory before vector matching.

The dedicated `CLASSIFY_UNIQUE_TASK` runs `CLASSIFY_UNIQUE_DESCRIPTIONS()`, which uses `AI_CLASSIFY` for two-phase classification operating at the unique-description level. Categories are dynamically loaded from `CATEGORY_TAXONOMY` (populated from `STANDARD_ITEMS`). Results fan back to all raw items via `RAW_TO_UNIQUE_MAP`:

```sql
-- Categories loaded dynamically from CATEGORY_TAXONOMY (currently 20 categories)
-- Example categories: Beverages, Hot Dogs & Sausages, Ice Cream & Frozen Treats, etc.
UPDATE HARMONIZED.UNIQUE_DESCRIPTIONS
SET INFERRED_CATEGORY = SNOWFLAKE.CORTEX.AI_CLASSIFY(
        NORMALIZED_DESCRIPTION,
        (SELECT ARRAY_AGG(DISTINCT CATEGORY) FROM RAW.CATEGORY_TAXONOMY WHERE IS_ACTIVE = TRUE AND SUBCATEGORY IS NULL)
    ):labels[0]::STRING
WHERE INFERRED_CATEGORY IS NULL;
```

**Impact:** Instead of comparing a "Coke 20oz" against all 1,226 standard items, we only compare against items in the matching category (e.g., ~243 items in "Beverages") — significant reduction in vector comparisons.

### Steps 2-4: Four Parallel Matching Methods

Each method runs independently and produces a score (0.0 to 1.0):

| Step | Method | Snowflake Functions |
|------|--------|---------------------|
| 2 | Cortex Search | `SEARCH_PREVIEW` on Cortex Search Service |
| 3 | Cosine Similarity | `EMBED_TEXT_1024` + `VECTOR_COSINE_SIMILARITY` |
| 4 | Edit Distance | `EDITDISTANCE` (Levenshtein distance) |
| 4 | Jaccard Similarity | Token intersection/union via `JACCARD_SIMILARITY` UDF |

Results are stored in `ITEM_MATCHES` with separate columns for each score:
- `CORTEX_SEARCH_SCORE`
- `COSINE_SCORE`
- `EDIT_DISTANCE_SCORE`
- `JACCARD_SCORE`

### Step 5: Ensemble Scoring and Routing

The four individual scores are combined into a single `ENSEMBLE_SCORE` with configurable weights and agreement bonuses. See [Ensemble Scoring](#ensemble-scoring) for details.

Based on the ensemble score, items are routed:
- **Score >= 80%:** `AUTO_ACCEPTED` — no human review needed
- **Score 70-79%:** `AUTO_ACCEPTED` (reviewable) — accepted but available for spot-checking
- **Score < 70%:** `PENDING_REVIEW` — routed to human review queue

### Batch Processing Behavior

The pipeline procedures process items in configurable batches (default: 200). Understanding which steps are batched is important for processing all records.

#### Per-Invocation Behavior

When the batch pipeline is invoked (via CLI, API, or Tasks), each step behaves differently:

| Step | Procedure | Batch Behavior |
|------|-----------|----------------|
| 0 | `DEDUPLICATE_RAW_ITEMS()` | **ALL pending** — No limit, processes everything |
| 0.5 | `RESOLVE_FAST_PATH()` | **ALL pending** — No limit, resolves all cached matches |
| Classify | `CLASSIFY_UNIQUE_DESCRIPTIONS(BATCH_SIZE)` | **BATCH_SIZE only** — AI_CLASSIFY category + subcategory at unique-description level |
| Prep | `VECTOR_PREP_BATCH(BATCH_SIZE)` | **BATCH_SIZE only** — Stages ALL stream items first, then embeds batch |
| 2 | `MATCH_CORTEX_SEARCH_BATCH(batch_id)` | **Current batch** — Writes to staging table |
| 3 | `MATCH_COSINE_BATCH(batch_id)` | **Current batch** — Writes to staging table |
| 4 | `MATCH_EDIT_BATCH(batch_id)` | **Current batch** — Writes to staging table |
| 4 | `MATCH_JACCARD_BATCH(batch_id)` | **Current batch** — Writes to staging table |
| 5 | `MERGE_STAGING_TABLES()` | Merges 4 staging tables into ITEM_MATCHES |
| 6 | `COMPUTE_ENSEMBLE_SCORES_ONLY()` | Computes ensemble scores with agreement multipliers |
| 7 | `ROUTE_MATCHED_ITEMS()` | Routes items to HARMONIZED_ITEMS, REVIEW_QUEUE, or REJECTED_ITEMS |

**Key Insight:** A single pipeline invocation with `batch_size=500` processes approximately 500 unique items through the batch matching architecture. Classification runs at the unique-description level before vector prep. The vector methods (Cortex Search, Cosine, Edit, Jaccard) write to staging tables, and the ensemble step merges results with agreement-based scoring. De-duplication and fast-path resolution always process all applicable records.

#### Processing All Records

To process **all** pending items, use the CLI's `--loop-until-done` flag:

```bash
uv run demo data run --loop-until-done
```

This causes the CLI to:
1. Call the pipeline procedure (processes one batch)
2. Check remaining pending count
3. Repeat until `pending_count <= 0` or shutdown requested

**Without `--loop-until-done`:** Only one batch (~200 items) is processed per command invocation.

**With `--loop-until-done`:** The CLI loops automatically, processing all items in sequential batches.

For faster processing, combine with parallel execution:

```bash
uv run demo data run --parallel --loop-until-done --batch-size 500
```



## Matching Algorithms Deep Dive

### Cortex Search

**How it works:**

Cortex Search is a managed vector search service in Snowflake. We create a search index on standard item descriptions:

```sql
CREATE CORTEX SEARCH SERVICE HARMONIZED.STANDARD_ITEM_SEARCH
    ON STANDARD_DESCRIPTION
    ATTRIBUTES STANDARD_ITEM_ID, CATEGORY, BRAND, SRP
    WAREHOUSE = HARMONIZER_DEMO_WH
    TARGET_LAG = '1 hour'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    AS (
        SELECT STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, BRAND, SRP
        FROM RAW.STANDARD_ITEMS
    );
```

When a raw item needs matching, we query the search service with a category filter:

```sql
SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'HARMONIZER_DEMO.HARMONIZED.STANDARD_ITEM_SEARCH',
    '{"query": "COKE 20OZ BOTTLE", "filter": {"@eq": {"CATEGORY": "Beverages"}}, "limit": 5}'
);
```

**Relevance Scoring:**

Cortex Search returns relevance scores in the `@scores` field of each result:

```json
{
  "results": [
    {
      "@scores": {
        "cosine_similarity": 0.87,
        "text_match": 12.5
      },
      "STANDARD_ITEM_ID": "STD-001234",
      "STANDARD_DESCRIPTION": "Coca-Cola Classic 20oz Bottle"
    }
  ]
}
```

We use the `cosine_similarity` score (range: -1 to 1) and normalize it to our standard 0-1 range:

```python
normalized_score = (cosine_similarity + 1) / 2
# Example: cosine_similarity = 0.87 → normalized = 0.935
```

**Pros:**
- Fast vector retrieval (optimized for scale)
- Managed service (Snowflake handles embedding, indexing, updates)
- Supports filtering by attributes (category, brand)
- Automatic index refresh based on TARGET_LAG
- Returns actual relevance scores for accurate ensemble weighting

**Cons:**
- Less precise for complex semantic nuances
- Limited to text similarity (doesn't reason about context)
- Requires 1-hour lag for index updates

**Best suited for:**
- High-volume initial filtering
- Finding the top-N most similar candidates
- Cases where speed matters more than perfect precision



### Cosine Similarity

**How it works:**

Pre-compute 1024-dimensional embeddings for all standard items using `EMBED_TEXT_1024`:

```sql
INSERT INTO RAW.STANDARD_ITEMS_EMBEDDINGS (STANDARD_ITEM_ID, EMBEDDING)
SELECT
    STANDARD_ITEM_ID,
    SNOWFLAKE.CORTEX.EMBED_TEXT_1024('snowflake-arctic-embed-l-v2.0', STANDARD_DESCRIPTION)
FROM RAW.STANDARD_ITEMS;
```

At matching time, generate an embedding for the raw item and compare using `VECTOR_COSINE_SIMILARITY`:

```sql
SELECT
    se.STANDARD_ITEM_ID,
    VECTOR_COSINE_SIMILARITY(raw_embedding, se.EMBEDDING) AS cosine_score
FROM RAW.STANDARD_ITEMS_EMBEDDINGS se
WHERE cosine_score > 0.5
ORDER BY cosine_score DESC
LIMIT 5;
```

**Pros:**
- Deterministic — same input always produces same output
- Scalable — pre-computed embeddings enable fast batch comparisons
- Category filter reduces search space (only compare within category)
- Works well for lexically similar items

**Cons:**
- Requires embedding maintenance (re-compute when standard items change)
- Embedding computation cost for raw items at matching time
- May miss semantic matches that aren't lexically similar

**Best suited for:**
- Items with similar word patterns
- Batch processing where consistency matters
- Cases where the raw description closely resembles the standard description



### Edit Distance

**How it works:**

Edit distance (Levenshtein distance) measures the minimum number of single-character edits needed to transform one string into another. It's especially effective for catching typos and minor variations.

```sql
SELECT
    s.STANDARD_ITEM_ID,
    s.STANDARD_DESCRIPTION,
    1.0 - (EDITDISTANCE(
        UPPER(raw_description),
        UPPER(s.STANDARD_DESCRIPTION)
    )::FLOAT / GREATEST(LENGTH(raw_description), LENGTH(s.STANDARD_DESCRIPTION))) AS edit_score
FROM RAW.STANDARD_ITEMS s
WHERE s.CATEGORY = raw_category
ORDER BY edit_score DESC
LIMIT 5;
```

The score is normalized to 0.0-1.0 by dividing by the maximum string length.

**Example:**
```
Raw:      "COCA COLA 20OZ BTL"
Standard: "Coca-Cola 20oz Bottle"

Edit distance = 5 (remove hyphen, expand "BTL" to "Bottle")
Max length = 21
Score = 1 - (5/21) = 0.76
```

**Pros:**
- Extremely fast — no AI calls, pure string computation
- Excellent for typos, abbreviations, and minor variations
- Deterministic and consistent
- No additional infrastructure required

**Cons:**
- Length-sensitive — struggles with very different string lengths
- Doesn't understand semantic meaning
- Case and whitespace sensitive (mitigated by normalization)

**Best suited for:**
- Typo detection ("Coka Cola" → "Coca-Cola")
- Abbreviation matching ("BTL" in similar position to "Bottle")
- Quick filtering before expensive methods



### Jaccard Token Similarity

**How it works:**

Jaccard similarity measures the overlap between two sets of tokens (words). It's calculated as the size of the intersection divided by the size of the union of the token sets.

```sql
-- Token-based Jaccard similarity using UDF
SELECT
    s.STANDARD_ITEM_ID,
    s.STANDARD_DESCRIPTION,
    HARMONIZED.JACCARD_SIMILARITY(
        UPPER(raw_description),
        UPPER(s.STANDARD_DESCRIPTION)
    ) AS jaccard_score
FROM RAW.STANDARD_ITEMS s
WHERE s.CATEGORY = raw_category
ORDER BY jaccard_score DESC
LIMIT 5;
```

The underlying calculation:

```sql
-- Jaccard = |A ∩ B| / |A ∪ B|
-- Where A and B are sets of word tokens

CREATE FUNCTION HARMONIZED.JACCARD_SIMILARITY(text1 VARCHAR, text2 VARCHAR)
RETURNS FLOAT
AS $$
    SELECT
        ARRAY_SIZE(ARRAY_INTERSECTION(
            SPLIT(REGEXP_REPLACE(text1, '[^A-Z0-9 ]', ''), ' '),
            SPLIT(REGEXP_REPLACE(text2, '[^A-Z0-9 ]', ''), ' ')
        ))::FLOAT /
        NULLIF(ARRAY_SIZE(ARRAY_DISTINCT(ARRAY_CAT(
            SPLIT(REGEXP_REPLACE(text1, '[^A-Z0-9 ]', ''), ' '),
            SPLIT(REGEXP_REPLACE(text2, '[^A-Z0-9 ]', ''), ' ')
        ))), 0)
$$;
```

**Example:**
```
Raw:      "COCA COLA 20OZ BOTTLE"
Standard: "Coca-Cola Classic 20oz Bottle"

Raw tokens:      {COCA, COLA, 20OZ, BOTTLE}
Standard tokens: {COCA, COLA, CLASSIC, 20OZ, BOTTLE}

Intersection: {COCA, COLA, 20OZ, BOTTLE} = 4 tokens
Union:        {COCA, COLA, CLASSIC, 20OZ, BOTTLE} = 5 tokens

Jaccard = 4/5 = 0.80
```

**Pros:**
- Word-order independent — "COLA COCA" matches "COCA COLA"
- Excellent for reordered descriptions and different word arrangements
- Extremely fast — pure set operations, no AI calls
- Deterministic and consistent
- Handles missing or extra words gracefully

**Cons:**
- Doesn't understand synonyms (only exact token matches)
- Sensitive to tokenization (hyphenated words, abbreviations)
- No semantic understanding

**Best suited for:**
- Reordered descriptions ("Diet Coke 12oz" vs "12oz Coke Diet")
- Items with extra qualifiers ("COCA COLA CLASSIC" vs "COCA COLA")
- Complementing edit distance (catches cases edit distance misses)



### Algorithm Comparison Summary

| Method | Speed | Cost | Precision | Best For |
|--------|-------|------|-----------|----------|
| Cortex Search | Fast | Low | Good | Initial candidate retrieval |
| Cosine Similarity | Medium | Medium | Good | Lexically similar items |
| Edit Distance | Very Fast | None | Good | Typos, abbreviations |
| Jaccard Similarity | Very Fast | None | Good | Reordered descriptions, word overlap |



### Cortex Search vs Cosine Similarity: Deep Dive

Both methods use semantic understanding, but they work differently and excel in different scenarios.

#### Functional Differences

| Aspect | Cortex Search | Cosine Similarity |
|--------|---------------|-------------------|
| **Algorithm** | Hybrid (semantic + lexical + ranking) | Pure semantic (embeddings only) |
| **How it works** | Pre-indexed service, Snowflake's optimized ranking | Direct vector comparison via `VECTOR_COSINE_SIMILARITY` |
| **Lexical matching** | Yes (boosts exact/partial keyword matches) | No (only understands meaning) |
| **Transparency** | Black box (Snowflake optimized) | Fully transparent (vector math) |
| **Speed** | Very fast (pre-indexed) | Slower (embedding computed at query time) |

#### Where Each Method Excels

**Cortex Search is best for:**
```
Input: "Diet Pepsi 12pk"
       ↓
Cortex Search finds: "Diet Pepsi 12-Pack Cans"
       ↓
Why: Exact keyword match on "Diet Pepsi" gets lexical boost
```

- Brand names and product identifiers (lexical matching matters)
- Items where keywords are critical signals
- Cases where exact words should heavily influence ranking

**Cosine Similarity is best for:**
```
Input: "Fizzy lemon drink"
       ↓
Cosine Similarity finds: "Sprite 20oz Bottle"
       ↓
Why: Semantically understands "fizzy lemon drink" ≈ "lemon-lime soda"
```

- Semantic equivalence despite different vocabulary
- Conceptual matching (synonyms, paraphrases)
- Items described in non-standard ways

#### Real-World Disagreement Examples

| Input | Cortex Search Match | Cosine Match | Better Answer |
|-------|---------------------|--------------|---------------|
| "Coke Zero Sugar 20oz" | Coca-Cola Zero Sugar 20oz ✓ | Coca-Cola Zero Sugar 20oz ✓ | Both (agreement = high confidence) |
| "Cola beverage, diet" | Diet Cola Syrup | Diet Coke 12oz Can | Cosine (semantic understanding) |
| "PEPSI-COLA 591ML" | Pepsi 20oz Bottle ✓ | Diet Pepsi 20oz | Cortex Search (keyword match) |
| "Lemon lime carbonated" | Lime Juice Concentrate | Sprite 2-Liter ✓ | Cosine (conceptual understanding) |

#### Why Both Methods Add Value

The two methods have **complementary failure modes**:

```ascii
┌─────────────────────────────────────────────────────────────────┐
│                    SIGNAL COVERAGE                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Cortex Search          OVERLAP            Cosine Similarity   │
│   ┌──────────┐      ┌──────────────┐       ┌──────────────┐     │
│   │ Lexical  │      │   Semantic   │       │    Pure      │     │
│   │ Keyword  │◄────►│   + Keyword  │◄─────►│   Semantic   │     │
│   │ Matches  │      │    Hybrid    │       │   Meaning    │     │
│   └──────────┘      └──────────────┘       └──────────────┘     │
│                                                                 │
│   Catches:           Catches:              Catches:             │
│   - Brand names      - Most items          - Synonyms           │
│   - SKU patterns     - Common cases        - Paraphrases        │
│   - Exact matches                          - Conceptual matches │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Agreement Patterns and Interpretation

| Agreement Pattern | Interpretation | Confidence Level |
|-------------------|----------------|------------------|
| Both agree on same match | Strong signal — keywords AND semantics align | High |
| Cortex Search only finds it | Keywords match but semantics differ | Medium (possible false positive) |
| Cosine only finds it | Semantically similar but no keyword overlap | Medium-High (unusual phrasing) |
| Neither finds it | Genuinely difficult item | Low (rely on Edit Distance + Jaccard) |

#### Accuracy Impact

~~Based on typical retail matching scenarios~~ **Updated based on empirical testing:**

| Configuration | Observed Accuracy | Notes |
|---------------|-------------------|-------|
| Cortex Search alone | **~100%** | Handles abbreviations via hybrid lexical+semantic |
| Cosine Similarity alone | **~15%** | Fails on abbreviations (pure semantic) |
| Both combined (current weights) | ~85-90% | Cosine drags down Search accuracy |

> **Critical insight**: For heavily abbreviated retail data (like Retail), Cortex Search
> alone may outperform the current ensemble approach. The ~5-7% improvement assumption
> was based on scenarios where both methods perform comparably.

#### Weight Rationale

Current weights (normalized 4-signal weighted average):
- `Cortex Search (0.55) + Cosine (0.25) + Edit (0.12) + Jaccard (0.18) = 1.0` (normalized)

This reflects empirical testing results:
1. Cortex Search significantly outperforms Cosine on abbreviated data (100% vs 15% accuracy)
2. Cortex Search's hybrid lexical+semantic approach handles brand abbreviations
3. Cosine still adds value for semantic variations but with reduced weight
4. Edit Distance (12%) serves as a tiebreaker for exact character matches
5. Jaccard (18%) provides token-level overlap scoring for robustness

> **Note**: Weights were revised from Search=0.25/Cosine=0.35 based on empirical 
> testing showing Cortex Search dramatically outperforms raw Cosine Similarity 
> on abbreviated retail data like "CK" → "Coca-Cola", "PEP" → "Pepsi".

**Simplification consideration**: If agreement rate exceeds 95% on your specific data, 
consolidating to one method may reduce complexity without accuracy loss. Run the 
agreement analysis query periodically to evaluate.

#### Agreement Analysis Query

Use this query to measure actual agreement rates between Cortex Search and Cosine Similarity:

```sql
-- Measure agreement rates between Cortex Search and Cosine Similarity
WITH method_comparison AS (
    SELECT 
        RAW_ITEM_ID,
        SEARCH_MATCHED_ID,
        COSINE_MATCHED_ID,
        CORTEX_SEARCH_SCORE,
        COSINE_SCORE,
        CASE 
            WHEN SEARCH_MATCHED_ID = COSINE_MATCHED_ID THEN 'AGREE'
            ELSE 'DISAGREE'
        END as agreement_status,
        ABS(CORTEX_SEARCH_SCORE - COSINE_SCORE) as score_difference
    FROM HARMONIZED.ITEM_MATCHES
    WHERE SEARCH_MATCHED_ID IS NOT NULL 
      AND COSINE_MATCHED_ID IS NOT NULL
)
SELECT 
    COUNT(*) as total_comparisons,
    SUM(CASE WHEN agreement_status = 'AGREE' THEN 1 ELSE 0 END) as agreements,
    SUM(CASE WHEN agreement_status = 'DISAGREE' THEN 1 ELSE 0 END) as disagreements,
    ROUND(100.0 * SUM(CASE WHEN agreement_status = 'AGREE' THEN 1 ELSE 0 END) 
          / COUNT(*), 2) as agreement_rate_pct,
    ROUND(AVG(score_difference), 4) as avg_score_diff,
    ROUND(AVG(CASE WHEN agreement_status = 'AGREE' THEN score_difference END), 4) 
          as avg_diff_when_agree,
    ROUND(AVG(CASE WHEN agreement_status = 'DISAGREE' THEN score_difference END), 4) 
          as avg_diff_when_disagree
FROM method_comparison;
```

**Interpretation guide:**
- `agreement_rate_pct > 95%`: Consider simplifying to one method
- `agreement_rate_pct 80-95%`: Both methods add value, keep both
- `agreement_rate_pct < 80%`: Significant complementary coverage, both essential
- `avg_diff_when_disagree > 0.3`: Methods capture very different signals

#### Empirical Results (Retail Data)

Testing on sample Retail retail items revealed **critical differences** between the methods:

| Raw Description | Cortex Search Match | Cosine Similarity Match | Correct? |
|-----------------|---------------------|-------------------------|----------|
| CK CLA 20OZ BTL | Coca-Cola Classic 20oz Bottle ✓ | Gold Peak Tea 18.5oz | Search |
| CK ZERO 20 BTL | Coca-Cola Zero Sugar 20oz Bottle ✓ | Chicken Tenders 6pc | Search |
| DT CK 20OZ | Diet Coke 20oz Bottle ✓ | Pure Leaf Tea 18.5oz | Search |
| PEP 20OZ BTL | Pepsi Cola 20oz Bottle ✓ | Powerade Fruit Punch | Search |
| FANTA ORG 20Z | Fanta Orange 20oz Bottle ✓ | Supreme Pizza Slice | Search |
| MT DEW 12Z CAN | Mountain Dew 12oz Can ✓ | Mountain Dew 12oz Can ✓ | Both |
| SPRT 12Z CAN | Sprite 12oz Can ✓ | Sprite 12oz Can ✓ | Both |

**Key Findings:**

| Metric | Value |
|--------|-------|
| Agreement Rate | **15.4%** |
| Cortex Search Correct | **100%** (13/13) |
| Cosine Similarity Correct | **15%** (2/13) |

**Why such a large gap?**

1. **Abbreviation handling**: Cortex Search's hybrid lexical+semantic approach handles 
   abbreviations like "CK" → "Coca-Cola", "PEP" → "Pepsi", "SPRT" → "Sprite"
   
2. **Pure embeddings fail on abbreviations**: The Arctic Embed model doesn't understand 
   that "CK" means "Coke" — it sees "CK" as semantically similar to random text

3. **Lexical signal is critical**: For retail item matching, brand names and abbreviations
   carry more weight than pure semantic meaning

**Applied Changes (based on these findings):**

1. **Weights updated**: Cortex Search 0.25→0.55, Cosine 0.35→0.25, Edit 0.15→0.12, Jaccard 0.18
2. **Agreement multipliers**: 4-way (1.20×), 3-way (1.15×), 2-way (1.10×)
3. **Embedding model upgraded**: Arctic Embed v1.5 → v2.0 for improved semantic understanding
4. Cortex Search now has highest weight, reflecting its superior performance on abbreviated retail data

Future considerations:
- Preprocess raw descriptions to expand abbreviations before Cosine matching
- Use Cosine primarily as a tiebreaker when Cortex Search scores are close



## Ensemble Scoring

The ensemble combines four vector methods into a **normalized weighted average** with agreement multipliers. A **subcategory penalty** is applied when the inferred subcategory doesn't match.

### Score Normalization

All method scores are normalized to a 0-1 range before combining:

| Method | Raw Score Range | Normalization |
|--------|-----------------|---------------|
| Cortex Search | `@scores.cosine_similarity` [-1, 1] | `(score + 1) / 2` |
| Cosine Similarity | `VECTOR_COSINE_SIMILARITY` [0, 1]* | Direct use (typically positive for text) |
| Edit Distance | `1 - (distance / max_length)` [0, 1] | Already normalized |
| Jaccard Similarity | `|A ∩ B| / |A ∪ B|` [0, 1] | Already normalized |

*Note: For text embeddings (Arctic Embed), cosine similarity between similar texts is typically in [0, 1] since embedding vectors have similar orientations. Negative values would indicate semantically opposite content, which is rare for retail item descriptions.

This ensures each method contributes proportionally to the weighted average.

### Weight Formula

The ensemble uses a **normalized 4-signal weighted average with agreement multipliers and subcategory penalty**:

```
-- Weights are dynamically normalized to always sum to 1.0
weight_sum = W_search + W_cosine + W_edit + W_jaccard
normalized_weights = (W_search/weight_sum, W_cosine/weight_sum, W_edit/weight_sum, W_jaccard/weight_sum)

-- Base score from 4 vector methods (max = 1.0 when all scores are 1.0)
base_score = (search × norm_W_search) + (cosine × norm_W_cosine) + (edit × norm_W_edit) + (jaccard × norm_W_jaccard)

-- Final ensemble score with agreement bonus and subcategory penalty
ensemble_score = LEAST(1.0, base_score × agreement_multiplier - subcategory_penalty)
```

Default weights (stored in `CONFIG`, dynamically normalized):
- `ENSEMBLE_WEIGHT_SEARCH` = 0.55 (55%) — highest weight due to superior abbreviation handling
- `ENSEMBLE_WEIGHT_COSINE` = 0.25 (25%) — strong semantic signal for non-abbreviated text
- `ENSEMBLE_WEIGHT_EDIT` = 0.12 (12%) — tiebreaker for exact character matches
- `ENSEMBLE_WEIGHT_JACCARD` = 0.18 (18%) — catches reordered descriptions

**Weight Normalization**: Weights are normalized at runtime to ensure the sum equals 1.0. This guarantees that when all four vector methods score 1.0, the base score is also 1.0 (before agreement multipliers).

**Subcategory Penalty** (currently disabled):
- `SUBCATEGORY_MISMATCH_PENALTY` = 0.00 — penalty when item subcategory doesn't match (disabled: inference uses different naming than standard items)
- `SUBCATEGORY_UNKNOWN_PENALTY` = 0.00 — penalty when subcategory couldn't be inferred (disabled: many valid items lack subcategory)
- When enabled, these penalties encourage more conservative matching when category alignment is uncertain

### Agreement Bonuses

When the four vector methods agree on the same standard item, the score is boosted:

```
                          Agreement Factor
─────────────────────────────────────────────
All 4 vector methods agree    × 1.20 (+20% boost)
3 of 4 vector methods agree   × 1.15 (+15% boost)
2 of 4 vector methods agree   × 1.10 (+10% boost)
No agreement                  × 1.00 (no change)
```

The final score is capped at 1.0:

```sql
-- Weights are normalized at procedure start:
-- weight_sum := search_weight + cosine_weight + edit_weight + jaccard_weight;
-- search_weight := search_weight / weight_sum;  -- etc.

ENSEMBLE_SCORE = LEAST(1.0,
    -- Normalized 4-signal weighted average (weights sum to 1.0)
    (COALESCE(im.CORTEX_SEARCH_SCORE, 0) * :search_weight +
     COALESCE(im.COSINE_SCORE, 0) * :cosine_weight +
     COALESCE(im.EDIT_DISTANCE_SCORE, 0) * :edit_weight +
     COALESCE(im.JACCARD_SCORE, 0) * :jaccard_weight)
    *
    -- Agreement multiplier (4 vector methods)
    CASE
        WHEN im.SEARCH_MATCHED_ID = im.COSINE_MATCHED_ID
             AND im.COSINE_MATCHED_ID = im.EDIT_DISTANCE_MATCHED_ID
             AND im.EDIT_DISTANCE_MATCHED_ID = im.JACCARD_MATCHED_ID
             AND im.SEARCH_MATCHED_ID IS NOT NULL
        THEN :multiplier_4way  -- 1.20
        WHEN (/* 3-way agreement combinations */)
        THEN :multiplier_3way  -- 1.15
        WHEN (/* 2-way agreement combinations */)
        THEN :multiplier_2way  -- 1.10
        ELSE 1.00
    END
    -
    -- Subcategory Penalty: Deduct when subcategory doesn't match
    CASE
        WHEN ri.INFERRED_SUBCATEGORY IS NULL THEN :subcat_unknown_penalty  -- 0.05
        WHEN ri.INFERRED_SUBCATEGORY != si.SUBCATEGORY THEN :subcat_mismatch_penalty  -- 0.15
        ELSE 0
    END
)
```

### Final Match Selection

The `SUGGESTED_STANDARD_ID` is chosen with the following priority:

1. **Unanimous agreement** — use the agreed-upon item (all 4 methods agree)
2. **Majority agreement** — use the item agreed upon by 3 of 4 methods
3. **Cosine choice** — fallback to highest semantic similarity
4. **Cortex Search choice** — final fallback

### Routing Thresholds

| Ensemble Score | Status | Destination | Action |
|--------------|--------|-------------|--------|
| >= 0.80 | AUTO_ACCEPTED | HARMONIZED_ITEMS | No review needed |
| 0.70 - 0.79 | AUTO_ACCEPTED | HARMONIZED_ITEMS | Accepted, available for spot-check |
| < 0.70 | PENDING_REVIEW | REVIEW_QUEUE | Routed to human review queue |
| No match (all NULL/'None') | REJECTED | REJECTED_ITEMS | Auto-rejected, requires manual data entry |

Thresholds are configurable via `ANALYTICS.CONFIG`.



## Parallel Execution Architecture

The pipeline uses **method-level parallelism** to run all four vector matching techniques (Cortex Search, Cosine Similarity, Edit Distance, Jaccard Similarity) simultaneously. This is achieved through Snowflake's Task DAG with staging tables pattern, avoiding table-locking issues that would serialize concurrent operations.

### Serial vs Parallel Vector Matching

```ascii
SERIAL EXECUTION (sequential methods):
────────────────────────────────────────────────────────────────────────────────
│ Dedup │ Classify │ Prep │ Cortex Search │ Cosine Sim │ Edit Dist │ Jaccard │ Ensemble │ Done │
────────────────────────────────────────────────────────────────────────────────
Time: ████████████████████████████████████████████████████████████████████ 100%

PARALLEL EXECUTION (concurrent methods via staging tables):
────────────────────────────────────────────────────────────────────────────────
│ Dedup │ Classify │ Prep │ Cortex Search   │ Ensemble │ Done │
│       │          │      │ Cosine Sim      │          │      │
│       │          │      │ Edit Distance   │          │      │
│       │          │      │ Jaccard Sim     │          │      │
────────────────────────────────────────────────────────────────────────────────
Time: ████████████████████████████████████ ~35% (3x faster)
```

### Stream-Based Exactly-Once Processing

A Snowflake Stream on `RAW_RETAIL_ITEMS` ensures exactly-once processing:

```sql
-- Stream tracks new records only (APPEND_ONLY)
CREATE STREAM RAW_ITEMS_STREAM ON TABLE RAW_RETAIL_ITEMS
    APPEND_ONLY = TRUE;

-- Root task runs on 1-minute CRON schedule
-- Procedure handles empty states gracefully (early exit if nothing to process)
-- NOTE: Snowflake task WHEN clauses only allow SYSTEM$STREAM_HAS_DATA() and
--       SYSTEM$GET_PREDECESSOR_RETURN_VALUE(). EXISTS subqueries are not supported.
SCHEDULE = 'USING CRON * * * * * America/New_York'
```

Key guarantees:
- **Atomic consumption**: Stream advances only when consumed in DML
- **No duplicates**: Each record processed exactly once
- **Scheduled execution**: Task runs every 1 minute; procedure handles empty states gracefully
- **Safe batching**: Stream items are staged first to prevent data loss with LIMIT clauses

### Staging Tables Pattern

Each vector method writes to its own TRANSIENT staging table to avoid locking:

```ascii
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                        STAGING TABLES (TRANSIENT)                                                   │
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                     │
│   CORTEX_SEARCH_STAGING      COSINE_MATCH_STAGING      EDIT_MATCH_STAGING    JACCARD_MATCH_STAGING  │
│   ┌─────────────────────┐    ┌─────────────────────┐   ┌─────────────────┐   ┌───────────────────┐  │
│   │ RAW_ITEM_ID         │    │ RAW_ITEM_ID         │   │ RAW_ITEM_ID     │   │ RAW_ITEM_ID       │  │
│   │ BATCH_ID            │    │ BATCH_ID            │   │ BATCH_ID        │   │ BATCH_ID          │  │
│   │ SEARCH_MATCHED_ID   │    │ COSINE_MATCHED_ID   │   │ EDIT_MATCHED_ID │   │ JACCARD_MATCHED_ID│  │
│   │ SEARCH_SCORE        │    │ COSINE_SCORE        │   │ EDIT_SCORE      │   │ JACCARD_SCORE     │  │
│   │ SEARCH_REASONING    │    │ COSINE_REASONING    │   │ EDIT_REASONING  │   │ JACCARD_REASONING │  │
│   └─────────────────────┘    └─────────────────────┘   └─────────────────┘   └───────────────────┘  │
│                                                                                                     │
│   • INSERT-only operations avoid table locking                                                      │
│   • BATCH_ID ties results together for ensemble scoring                                             │
│   • TRANSIENT = no Time Travel overhead                                                             │
│   • Cleaned up after ensemble scoring completes                                                     │
│                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Parallel TaskDAG with Decoupled Ensemble

The Task DAG uses Snowflake's `AFTER` and `FINALIZE` clauses for true parallelism, with a **decoupled ensemble pipeline** that replaces the monolithic finalizer:

```ascii
                    ┌─────────────────────────────────────┐
                    │      DEDUP_FASTPATH_TASK            │
                    │        (root, every 1 min)          │
                    │                                     │
                    │  SCHEDULE: CRON * * * * *           │
                    │  (procedure handles empty states)   │
                    │                                     │
                    │  • Dedup + fast-path resolution     │
                    └─────────────────┬───────────────────┘
                                      │ WHEN != skipped
                                      ▼
                    ┌─────────────────────────────────────┐
                    │     CLASSIFY_UNIQUE_TASK            │
                    │     (after dedup)                   │
                    │                                     │
                    │  • AI_CLASSIFY category             │
                    │  • AI_CLASSIFY subcategory          │
                    │  • Fan-out via RAW_TO_UNIQUE_MAP    │
                    └─────────────────┬───────────────────┘
                                      │ WHEN != error
                                      ▼
                    ┌─────────────────────────────────────┐
                    │        VECTOR_PREP_TASK             │
                    │        (after classify)             │
                    │                                     │
                    │  • Stage ALL stream → STREAM_STAGING│
                    │  • Batch from staging (LIMIT)       │
                    │  • Generate embeddings              │
                    │  • Create ITEM_MATCHES stubs        │
                    │  • Cleanup staging after batch      │
                    │  • Return BATCH_ID                  │
                    └─────────────────┬───────────────────┘
                                      │
          ┌───────────────────────────┼───────────────────────┬──────────────────────┐
          │                           │                       │                      │
          ▼                           ▼                       ▼                      ▼
    ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
    │ CORTEX_SEARCH_  │     │ COSINE_MATCH_   │     │ EDIT_MATCH_     │     │ JACCARD_MATCH_  │
    │ TASK            │     │ TASK            │     │ TASK            │     │ TASK            │
    │                 │     │                 │     │                 │     │                 │
    │ AFTER: PREP     │     │ AFTER: PREP     │     │ AFTER: PREP     │     │ AFTER: PREP     │
    │                 │     │                 │     │                 │     │                 │
    │ • Query Cortex  │     │ • VECTOR_       │     │ • EDITDISTANCE  │     │ • JACCARD_      │
    │   Search service│     │   COSINE_       │     │   function      │     │   SIMILARITY    │
    │ • INSERT to     │     │   SIMILARITY    │     │ • INSERT to     │     │ • INSERT to     │
    │   staging table │     │ • INSERT to     │     │   staging table │     │   staging table │
    │                 │     │   staging table │     │                 │     │                 │
    └────────┬────────┘     └────────┬────────┘     └────────┬────────┘     └────────┬────────┘
             │                       │                       │                       │
             │      TRUE PARALLEL    │    (sibling tasks     │      EXECUTION        │
             │                       │     run concurrently) │                       │
             │                       │                       │                       │
             └───────────────────────┴───────────────────────┴───────────────────────┘
                                     │
                                     ▼
                    ┌─────────────────────────────────────┐
                    │     STAGING_MERGE_TASK (FINALIZE)   │
                    │                                     │
                    │  • Merge 4 staging tables           │
                    │  • Single responsibility: merge     │
                    └─────────────────────────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         │                           │                           │
         ▼                           ▼                           ▼
    ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
    │ ENSEMBLE_       │     │ ITEM_ROUTER_    │     │                 │
    │ SCORING_TASK    │     │ TASK            │     │                 │
    │                 │     │                 │     │                 │
    │ WHEN: items     │     │ WHEN: items     │     │                 │
    │ ready for       │     │ need routing    │     │                 │
    │ scoring         │     │                 │     │                 │
    │ • Weighted      │     │ • Route to      │     │                 │
    │   ensemble      │     │   HARMONIZED or │     │                 │
    │ • Self-trigger  │     │   REVIEW_QUEUE  │     │                 │
    └─────────────────┘     └─────────────────┘     └─────────────────┘
    (processes ready)       (routes scored)

    Note: AFTER clause creates sibling tasks that run in TRUE PARALLEL
          FINALIZE clause waits for ALL siblings to complete
          WHEN clause enables self-triggering (Snowflake best practice)
```

### Decoupled Pipeline Benefits

The decoupled architecture replaces the monolithic `VECTOR_ENSEMBLE_TASK` with three single-responsibility tasks:

| Task | Trigger | Responsibility |
|------|---------|----------------|
| `STAGING_MERGE_TASK` | FINALIZE | Merge staging tables |
| `ENSEMBLE_SCORING_TASK` | WHEN (items ready) | Weighted 4-method ensemble scoring |
| `ITEM_ROUTER_TASK` | WHEN (items scored) | Route to HARMONIZED_ITEMS or REVIEW_QUEUE |

**Key advantages:**
- **Single responsibility**: Each task does exactly one thing (easier to optimize/troubleshoot)
- **Self-healing**: WHEN clauses trigger when work is available (no orphan states)
- **Independent batch limits**: Each task can have its own batch size
- **Clear state visibility**: Item progression visible in ITEM_MATCHES columns

### State Model and Implicit State Derivation

Instead of tracking state through task execution order, we track state through **data conditions**. Each task queries for items in its input state and transitions them to its output state.

#### State Transition Diagram

```
                    ┌─────────────────┐
                    │ SCORES_PENDING  │
                    │                 │
                    │ Waiting for 4   │
                    │ matcher scores  │
                    └────────┬────────┘
                             │
                             │ [STAGING_MERGE_TASK]
                             │ All 4 scores written
                             ↓
                   ┌─────────────────┐
                   │ ENSEMBLE_READY  │
                   │                 │
                   │ All 4 scores    │
                   │ present         │
                   └────────┬────────┘
                            │
                            │ [ENSEMBLE_SCORING_TASK]
                            │ Compute ENSEMBLE_SCORE
                            ↓
                  ┌─────────────────┐
                  │     SCORED      │
                  │                 │
                  │ ENSEMBLE_SCORE  │
                  │ computed        │
                  └────────┬────────┘
                           │
                           │ [ITEM_ROUTER_TASK]
                           │ Update MATCH_STATUS
                           ↓
                  ┌─────────────────┐
                  │     ROUTED      │
                  │                 │
                  │ Terminal state  │
                  └─────────────────┘
```

#### Implicit State Derivation

State is derived from column values in ITEM_MATCHES:

```sql
CASE
    -- Missing matcher scores - waiting for parallel tasks
    WHEN CORTEX_SEARCH_SCORE IS NULL 
      OR COSINE_SCORE IS NULL 
      OR EDIT_DISTANCE_SCORE IS NULL 
      OR JACCARD_SCORE IS NULL 
    THEN 'SCORES_PENDING'
    
    -- All scores present, routed - terminal state
    WHEN ENSEMBLE_SCORE IS NOT NULL 
    THEN 'ROUTED'
    
    -- All scores present, ready for ensemble scoring
    WHEN ENSEMBLE_SCORE IS NULL
    THEN 'ENSEMBLE_READY'
    
    ELSE 'UNKNOWN'
END
```

#### Pipeline Health Query

```sql
-- Pipeline health at a glance
SELECT 
    CASE 
        WHEN CORTEX_SEARCH_SCORE IS NULL THEN 'WAITING_FOR_MATCHERS'
        WHEN COSINE_SCORE IS NULL THEN 'WAITING_FOR_MATCHERS'
        WHEN EDIT_DISTANCE_SCORE IS NULL THEN 'WAITING_FOR_MATCHERS'
        WHEN JACCARD_SCORE IS NULL THEN 'WAITING_FOR_MATCHERS'
        WHEN ENSEMBLE_SCORE IS NULL THEN 'WAITING_FOR_ENSEMBLE'
        ELSE 'WAITING_FOR_ROUTING'
    END AS stage,
    COUNT(*) as item_count,
    MIN(CREATED_AT) as oldest_item
FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
GROUP BY 1
ORDER BY 2 DESC;
```

### Why This Design Is Robust

#### 1. No Orphan States Possible

Each task operates independently on items in its target state. If any task fails or the pipeline stalls:
- Items remain in their current state
- The responsible task will pick them up on the next scheduled run
- No manual intervention needed

#### 2. Self-Healing via Internal Checks

Each procedure checks for work internally and exits early if none exists:

```sql
-- Inside each procedure:
SELECT COUNT(*) INTO v_items_to_process
FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
WHERE [condition for this task's work];

IF (v_items_to_process = 0) THEN
    RETURN OBJECT_CONSTRUCT('status', 'complete', 'processed', 0, 'message', 'No items to process');
END IF;
```

#### 3. Graceful Backpressure

In high-volume scenarios:
- Stream-triggered DAG processes items and creates ITEM_MATCHES records
- Ensemble and router tasks process at their own pace
- No task crashes. No orphans. System degrades gracefully.

### Cortex Search Task Optimization

The Cortex Search task uses a Python stored procedure optimized for bulk operations:

**Snowflake Limitation**: `SEARCH_PREVIEW` requires literal constant arguments and cannot accept dynamic query values, even with bind variables. This means each item's search must be a separate API call.

**Optimization Strategy**: While API calls remain sequential, database write operations are batched using bulk INSERT:

```ascii
BEFORE OPTIMIZATION (row-by-row):
─────────────────────────────────────────────────────────────────
For each of 500 items:
  • 1 API call (~0.25s)
  • 1 staging INSERT
  • 5 candidate INSERTs

Total: 500 API calls + 3,000 INSERTs = 26+ minutes
─────────────────────────────────────────────────────────────────

AFTER OPTIMIZATION (bulk INSERT):
─────────────────────────────────────────────────────────────────
Phase 1: Collect all results
  • 500 API calls (~0.25s each = ~125s)
  
Phase 2: Bulk INSERT
  • 5 staging INSERT statements (100 rows each)
  • 1 temp table + MERGE for candidates

Total: 500 API calls + ~10 bulk INSERTs = ~2 minutes
─────────────────────────────────────────────────────────────────
```

**Benchmark Results** (500 items):
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Duration | 26+ min | 2.2 min | **12x faster** |
| DB round-trips | ~3,000 | ~10 | **300x fewer** |
| Per-item time | ~3s | ~0.27s | **11x faster** |

### Available Tasks

| Task | Schedule | Trigger | Use Case |
|------|----------|---------|----------|
| `DEDUP_FASTPATH_TASK` | Every 1 min | Stream OR staging OR pending items | Root task: dedup + fast-path resolution |
| `CLASSIFY_UNIQUE_TASK` | On-demand | AFTER DEDUP_FASTPATH (WHEN != skipped) | AI_CLASSIFY category + subcategory at unique-desc level |
| `VECTOR_PREP_TASK` | On-demand | AFTER CLASSIFY_UNIQUE (WHEN != error) | Stage stream items, embed, create stubs |
| `CORTEX_SEARCH_TASK` | On-demand | AFTER PREP | Cortex Search matching |
| `COSINE_MATCH_TASK` | On-demand | AFTER PREP | Cosine similarity matching |
| `EDIT_MATCH_TASK` | On-demand | AFTER PREP | Edit distance matching |
| `JACCARD_MATCH_TASK` | On-demand | AFTER PREP | Jaccard token similarity matching |
| **Decoupled Ensemble Tasks** | | | |
| `STAGING_MERGE_TASK` | On-demand | FINALIZE | Merge staging tables |
| `ENSEMBLE_SCORING_TASK` | Every 1 min | WHEN (items ready) | Weighted 4-method ensemble scoring |
| `ITEM_ROUTER_TASK` | Every 1 min | WHEN (items scored) | Route to HARMONIZED_ITEMS or REVIEW_QUEUE |

### CLI Commands

```bash
# Enable Task DAG and trigger immediate execution
uv run demo data run

# Enable tasks only (wait for schedule)
uv run demo data run --no-trigger

# Disable Task DAG
uv run demo data stop

# Monitor Task DAG status
uv run demo data status

# Create parallel task DAG (if not already created by db up)
uv run demo db run sql/setup/12_parallel_matchers.sql
uv run demo db run 16_task_dag_definition.sql
```

### Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `RUN_MATCHING_PIPELINE()` | Serial execution (default) |
| `VECTOR_PREP_BATCH(batch_size)` | Stage ALL stream items to STREAM_STAGING, then batch process (classify, embed) |
| `MATCH_CORTEX_SEARCH_BATCH(batch_id)` | Cortex Search matching to staging |
| `MATCH_COSINE_BATCH(batch_id)` | Cosine similarity matching to staging |
| `MATCH_EDIT_BATCH(batch_id)` | Edit distance matching to staging |
| `MATCH_JACCARD_BATCH(batch_id)` | Jaccard token similarity matching to staging |
| **Decoupled Ensemble Procedures** | |
| `MERGE_STAGING_TABLES()` | Merge 4 staging tables into ITEM_MATCHES |
| `COMPUTE_ENSEMBLE_SCORES_ONLY()` | Weighted 4-method ensemble scoring with agreement multipliers |
| `ROUTE_MATCHED_ITEMS()` | Route items to HARMONIZED_ITEMS, REVIEW_QUEUE, or REJECTED_ITEMS |

### Task Management Procedures

The system provides wrapper procedures for enabling/disabling the Task DAG rather than requiring direct `ALTER TASK` calls. While you *can* call `ALTER TASK` directly, these procedures offer several benefits:

| Procedure | Purpose |
|-----------|---------|
| `ENABLE_PARALLEL_PIPELINE_TASKS()` | Resume all 11 decoupled pipeline tasks in correct order |
| `DISABLE_PARALLEL_PIPELINE_TASKS()` | Suspend all 11 decoupled pipeline tasks in correct order |
| `GET_PIPELINE_TASK_STATUS()` | Return JSON status of all pipeline tasks |

**Why use these instead of direct `ALTER TASK`?**

1. **Dependency Ordering**: Snowflake requires tasks to be enabled/disabled in a specific order:
   - **Enable**: leaf tasks first, root task last (VECTOR_ENSEMBLE → siblings → CLASSIFY_UNIQUE → DEDUP_FASTPATH)
   - **Disable**: root task first, leaf tasks last (DEDUP_FASTPATH → CLASSIFY_UNIQUE → siblings → VECTOR_ENSEMBLE)
   
   If you enable the root task before its children, Snowflake throws an error. The procedures encode this logic.

2. **Atomic Operations**: One procedure call handles all 15 tasks instead of 15 separate `ALTER TASK` statements.

3. **Error Handling**: Procedures catch exceptions and return structured JSON errors instead of raw SQL failures.

4. **API Integration**: The JSON return format (`{"status": "enabled", "tasks": [...]}`) is designed for the FastAPI dashboard to parse and display status.

5. **Permission Encapsulation**: With `EXECUTE AS OWNER`, users with `USAGE` on the procedure can manage tasks without needing `OPERATE` privilege on each individual task.

**Direct ALTER TASK (if preferred)**:

```sql
-- Enable (leaf to root order for DAG, then standalone tasks):
-- DAG tasks
ALTER TASK HARMONIZER_DEMO.HARMONIZED.STAGING_MERGE_TASK RESUME;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_TASK RESUME;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_TASK RESUME;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_TASK RESUME;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_TASK RESUME;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_TASK RESUME;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.CLASSIFY_UNIQUE_TASK RESUME;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_TASK RESUME;
-- Decoupled scheduled tasks (independent)
ALTER TASK HARMONIZER_DEMO.HARMONIZED.ENSEMBLE_SCORING_TASK RESUME;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.ITEM_ROUTER_TASK RESUME;

-- Disable (root to leaf order for DAG, then standalone tasks):
-- DAG tasks
ALTER TASK HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.CLASSIFY_UNIQUE_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.STAGING_MERGE_TASK SUSPEND;
-- Decoupled scheduled tasks (independent)
ALTER TASK HARMONIZER_DEMO.HARMONIZED.ENSEMBLE_SCORING_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.ITEM_ROUTER_TASK SUSPEND;
```

### Why Staging Tables Instead of Parallel CTEs?

Snowflake's table-locking behavior requires this architecture:

| Approach | Issue | Result |
|----------|-------|--------|
| Parallel UPDATE | Multiple tasks updating ITEM_MATCHES | Serialized execution (locks) |
| Parallel MERGE | Multiple tasks merging to same table | Serialized execution (locks) |
| Parallel CTEs | Single transaction, single warehouse | No true parallelism |
| **Staging Tables** | Each task INSERTs to own table | **True parallel execution** |

The staging tables pattern ensures:
1. **No lock contention** — Each task writes to its own table
2. **True parallelism** — Tasks execute on separate compute threads
3. **Atomic merge** — Single MERGE operation combines all results
4. **Easy cleanup** — TRANSIENT tables deleted after processing



## Task Coordination (Message Queue Pattern)

The pipeline uses a table-based coordination system instead of Snowflake's built-in `SYSTEM$SET_RETURN_VALUE` / `SYSTEM$GET_PREDECESSOR_RETURN_VALUE` functions. This design provides more reliable task-to-task communication, especially for complex DAGs with parallel execution.

### Why Table-Based Coordination?

Snowflake's built-in task return value mechanism has limitations:

| Issue | SYSTEM$SET_RETURN_VALUE | Table-Based Coordination |
|-------|-------------------------|--------------------------|
| **Context restrictions** | Cannot call after EXECUTE IMMEDIATE or dynamic SQL | No restrictions, works anywhere |
| **Error 90237** | "Side effects function not allowed" in certain contexts | N/A |
| **Error 091426** | "Predecessor task did not set return value" | Never happens - status always in table |
| **Audit trail** | None - return values are ephemeral | Full history of every DAG run |
| **Debugging** | No visibility into past runs | Query table to see exact status |

### TASK_COORDINATION Table

```sql
CREATE TABLE HARMONIZED.TASK_COORDINATION (
    COORDINATION_ID     VARCHAR(36) PRIMARY KEY,
    RUN_ID              VARCHAR(36) NOT NULL,      -- Groups all tasks in one DAG execution
    TASK_NAME           VARCHAR(100) NOT NULL,     -- DEDUP_FASTPATH, CLASSIFY_UNIQUE, etc.
    STATUS              VARCHAR(20) NOT NULL,      -- STARTED, COMPLETED, SKIPPED, FAILED
    PAYLOAD             VARIANT,                   -- Task-specific metadata
    CREATED_AT          TIMESTAMP_NTZ,
    UPDATED_AT          TIMESTAMP_NTZ,
    UNIQUE (RUN_ID, TASK_NAME)
);
```

### Helper Procedures and Functions

| Object | Purpose |
|--------|---------|
| `REGISTER_TASK_START(run_id, task_name)` | Called at procedure start to register STARTED status |
| `UPDATE_TASK_STATUS(run_id, task, status, payload)` | Called at end to set COMPLETED/SKIPPED/FAILED with payload |
| `GET_PARENT_TASK_STATUS(parent_task, max_age_min)` | Check if parent completed/skipped/failed |
| `GET_LATEST_RUN_ID(parent_task)` | Get run_id from parent to inherit in child |
| `CHECK_ALL_PARALLEL_TASKS_DONE(run_id)` | Verify all 4 matchers completed for ensemble step |

### Monitoring Views

| View | Purpose |
|------|---------|
| `V_CURRENT_DAG_RUN` | All tasks from last hour with duration, ordered by task sequence |
| `V_DAG_RUN_HISTORY` | Aggregated stats per run: duration, tasks completed/skipped/failed |
| `V_TASK_COORDINATION_LATEST` | Most recent status for each task type |

### Cleanup

A scheduled task (`CLEANUP_COORDINATION_TASK`) runs daily at 3 AM ET to delete records older than 7 days.



## Pipeline Execution (Task DAG)

The pipeline runs exclusively via Snowflake Task DAG. There is no synchronous execution mode.

```ascii
┌──────────────────────────────────────────────────────────────────────────────┐
│                    STREAM-TRIGGERED DAG (10 tasks)                           │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   DEDUP_FASTPATH_TASK (root, CRON every 1 min)                               │
│        │ WHEN != skipped                                                     │
│        ▼                                                                     │
│   CLASSIFY_UNIQUE_TASK (AI_CLASSIFY category + subcategory)                  │
│        │ WHEN != error                                                       │
│        ▼                                                                     │
│   VECTOR_PREP_TASK (embeddings + ITEM_MATCHES stubs)                         │
│        │                                                                     │
│        ├──────────────────┬──────────────────┬──────────────────┐            │
│        ▼                  ▼                  ▼                  ▼            │
│   CORTEX_SEARCH_TASK  COSINE_MATCH_TASK  EDIT_MATCH_TASK  JACCARD_MATCH_TASK │
│   (parallel)          (parallel)         (parallel)       (parallel)         │
│        │                  │                  │                  │            │
│        └──────────────────┴──────────────────┴──────────────────┘            │
│                           │                                                  │
│                           ▼                                                  │
│               STAGING_MERGE_TASK (FINALIZE)                                  │
│               (waits for all 4 siblings, merges staging)                     │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                            │
                            │ Writes to ITEM_MATCHES
                            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│              DECOUPLED SCHEDULED TASKS (independent, every 1 min)           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ENSEMBLE_SCORING_TASK                   ITEM_ROUTER_TASK                  │
│   (SCHEDULE = '1 MINUTE')                 (SCHEDULE = '1 MINUTE')           │
│   • Checks for work internally            • Checks for work internally      │
│   • Computes ENSEMBLE_SCORE               • Routes to AUTO_ACCEPTED or      │
│   • 4-method weighted ensemble              PENDING_REVIEW                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Features

1. **Stream-Based Processing** — RAW_ITEMS_STREAM provides exactly-once processing
2. **True Parallel Execution** — Four matching methods run simultaneously on separate staging tables
3. **Dedup + Fast-Path First** — 96x cost reduction before vector matching
4. **Automatic Scheduling** — Runs every 1 minute when enabled

### Task Management Procedures

| Procedure | Purpose |
|-----------|---------|
| `ENABLE_PARALLEL_PIPELINE_TASKS()` | Enable Task DAG in correct dependency order |
| `DISABLE_PARALLEL_PIPELINE_TASKS()` | Disable Task DAG in correct dependency order |
| `GET_PIPELINE_STATUS()` | Return current pipeline and task status |

### CLI Commands

```bash
# Enable tasks + trigger immediate run
uv run demo data run

# Enable tasks only (wait for schedule)
uv run demo data run --no-trigger

# Disable all tasks
uv run demo data stop

# Check pipeline status
uv run demo data status
```

### Manual Task Execution

To trigger immediate execution without using the CLI:

```sql
-- Ensure tasks are enabled first
CALL HARMONIZED.ENABLE_PARALLEL_PIPELINE_TASKS();

-- Execute root task immediately
EXECUTE TASK HARMONIZED.DEDUP_FASTPATH_TASK;
```



## Accuracy Testing Framework

The accuracy testing framework provides rigorous validation of matching algorithm performance against a curated ground truth test set. This ensures the demo meets the **>85% accuracy target** and provides empirical data to guide weight tuning decisions.

### Architecture

```ascii
┌─────────────────────────────────────────────────────────────────────────────┐
│                      ACCURACY TESTING FRAMEWORK                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────┐           ┌──────────────────────────────────────┐ │
│  │  ACCURACY_TEST_SET  │           │        TEST PROCEDURES               │ │
│  │                     │           │                                      │ │
│  │  38 Ground Truth    │──────────►│  TEST_CORTEX_SEARCH_ACCURACY()       │ │
│  │  Test Cases         │           │  TEST_COSINE_ACCURACY()              │ │
│  │                     │           │  TEST_EDIT_DISTANCE_ACCURACY()       │ │
│  │  • 7 EASY           │           │  TEST_JACCARD_ACCURACY()             │ │
│  │  • 13 MEDIUM        │           │                                      │ │
│  │  • 18 HARD          │           │         │                            │ │
│  └─────────────────────┘           │         ▼                            │ │
│                                    │  RUN_ACCURACY_TESTS()                │ │
│                                    │  (Master Orchestrator)               │ │
│                                    └──────────────┬───────────────────────┘ │
│                                                   │                         │
│                                                   ▼                         │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    ACCURACY_TEST_RESULTS                             │   │
│  │                                                                      │   │
│  │  TEST_ID │ METHOD │ TOP1_MATCH_ID │ IS_CORRECT │ TOP3_CONTAINS │...  │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│            ┌───────────────────────┼───────────────────────┐                │
│            ▼                       ▼                       ▼                │
│  ┌─────────────────┐    ┌─────────────────────┐    ┌────────────────────┐   │
│  │V_ACCURACY_      │    │V_ACCURACY_BY_       │    │V_DEMO_VALIDATION   │   │
│  │SUMMARY          │    │DIFFICULTY           │    │                    │   │
│  │                 │    │                     │    │  PASS/FAIL vs 85%  │   │
│  │Per-method stats │    │EASY/MEDIUM/HARD     │    │  target per method │   │
│  └─────────────────┘    └─────────────────────┘    └────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Test Set Design Philosophy

The test set is designed to reflect real-world retail data challenges:

#### Difficulty Levels

| Level | Count | Characteristics | Example |
|-------|-------|-----------------|---------|
| **EASY** | 7 | Near-exact matches, minor variations | "Coca-Cola 20oz" → "Coca-Cola Classic 20oz Bottle" |
| **MEDIUM** | 13 | Common abbreviations, missing words | "MT DEW 20OZ BTL" → "Mountain Dew 20oz Bottle" |
| **HARD** | 18 | Heavy abbreviation, ambiguous, edge cases | "CK ZERO 20 BTL" → "Coca-Cola Zero Sugar 20oz Bottle" |

#### Abbreviation Patterns Tested

| Pattern | Raw Form | Standard Form |
|---------|----------|---------------|
| Brand abbreviation | CK, PEP, SPRT | Coca-Cola, Pepsi, Sprite |
| Product type | ENRGY, WTR | Energy, Water |
| Modifier | DT, CLA, ZERO | Diet, Classic, Zero Sugar |
| Size | 20Z, 16.9Z, 8.4Z | 20oz, 16.9oz, 8.4oz |
| Container | BTL, CAN | Bottle, Can |

### Test Procedures

#### Per-Method Test Procedures

Each method has a dedicated test procedure that:
1. Iterates through all active test cases
2. Runs the method's matching logic
3. Records Top-1, Top-3, and Top-5 results
4. Compares against expected ground truth

```sql
-- Cortex Search (Python-based for dynamic queries)
CREATE PROCEDURE ANALYTICS.TEST_CORTEX_SEARCH_ACCURACY(RUN_ID VARCHAR)
RETURNS TABLE (METHOD VARCHAR, TOTAL_TESTS INT, TOP1_CORRECT INT, TOP1_ACCURACY FLOAT)
LANGUAGE PYTHON
...

-- Cosine Similarity (SQL-based)
CREATE PROCEDURE ANALYTICS.TEST_COSINE_ACCURACY(RUN_ID VARCHAR)
RETURNS TABLE (METHOD VARCHAR, TOTAL_TESTS INT, TOP1_CORRECT INT, TOP1_ACCURACY FLOAT)
LANGUAGE SQL
...

-- Edit Distance (SQL-based)
CREATE PROCEDURE ANALYTICS.TEST_EDIT_DISTANCE_ACCURACY(RUN_ID VARCHAR)
...

-- Jaccard Similarity (SQL-based)
CREATE PROCEDURE ANALYTICS.TEST_JACCARD_ACCURACY(RUN_ID VARCHAR)
...
```

#### Master Orchestrator

```sql
-- Run all tests
CALL ANALYTICS.RUN_ACCURACY_TESTS();
```

### Metrics Captured

| Metric | Description |
|--------|-------------|
| **TOP1_ACCURACY** | Percentage where top result is correct |
| **TOP3_ACCURACY** | Percentage where correct answer is in top 3 |
| **TOP5_ACCURACY** | Percentage where correct answer is in top 5 |
| **IS_CORRECT** | Boolean: did top-1 match the expected item? |
| **TOP1_SCORE** | Confidence score of the top result |

### Summary Views

#### V_ACCURACY_SUMMARY

Overall accuracy by method:

```sql
SELECT * FROM ANALYTICS.V_ACCURACY_SUMMARY;
```

| METHOD | TOTAL_TESTS | TOP1_CORRECT | TOP1_ACCURACY_PCT | TOP3_ACCURACY_PCT | TOP5_ACCURACY_PCT |
|--------|-------------|--------------|-------------------|-------------------|-------------------|
| CORTEX_SEARCH | 38 | 35 | 92.1 | 97.4 | 100.0 |
| COSINE_SIMILARITY | 38 | 27 | 71.1 | 86.8 | 92.1 |
| EDIT_DISTANCE | 38 | 17 | 44.7 | 63.2 | 76.3 |

#### V_ACCURACY_BY_DIFFICULTY

Accuracy broken down by difficulty level:

```sql
SELECT * FROM ANALYTICS.V_ACCURACY_BY_DIFFICULTY;
```

| METHOD | DIFFICULTY | TESTS | TOP1_PCT | TOP3_PCT | TOP5_PCT |
|--------|------------|-------|----------|----------|----------|
| CORTEX_SEARCH | EASY | 7 | 100.0 | 100.0 | 100.0 |
| CORTEX_SEARCH | MEDIUM | 13 | 92.3 | 100.0 | 100.0 |
| CORTEX_SEARCH | HARD | 18 | 88.9 | 94.4 | 100.0 |
| COSINE_SIMILARITY | EASY | 7 | 100.0 | 100.0 | 100.0 |
| COSINE_SIMILARITY | MEDIUM | 13 | 76.9 | 92.3 | 100.0 |
| COSINE_SIMILARITY | HARD | 18 | 50.0 | 72.2 | 83.3 |

#### V_DEMO_VALIDATION

Pass/fail check against the 85% target:

```sql
SELECT * FROM ANALYTICS.V_DEMO_VALIDATION;
```

| CORTEX_SEARCH_STATUS | CORTEX_SEARCH_ACCURACY | COSINE_STATUS | COSINE_ACCURACY | EDIT_STATUS | EDIT_ACCURACY | TARGET |
|---------------------|------------------------|---------------|-----------------|-------------|---------------|--------|
| PASS | 92.1 | NEEDS_IMPROVEMENT | 71.1 | NEEDS_IMPROVEMENT | 44.7 | 85% |

#### V_ACCURACY_FAILURES

Detailed failure analysis for debugging:

```sql
SELECT * FROM ANALYTICS.V_ACCURACY_FAILURES;
```

| METHOD | DIFFICULTY | RAW_DESCRIPTION | EXPECTED_MATCH | ACTUAL_MATCH | SCORE | NOTES |
|--------|------------|-----------------|----------------|--------------|-------|-------|
| COSINE_SIMILARITY | HARD | CK ZERO 20 BTL | Coca-Cola Zero Sugar 20oz Bottle | Pepsi Zero Sugar 20oz Bottle | 0.78 | CK abbreviation not recognized |

### Why Each Method Performs Differently

#### Cortex Search Advantages

Cortex Search uses a **hybrid lexical+semantic** approach:
- **BM25 lexical matching** catches exact token matches (even abbreviations)
- **Semantic embeddings** capture meaning similarity
- The combination handles retail abbreviations better than pure semantic

#### Cosine Similarity Limitations

Pure semantic embeddings struggle with:
- **Abbreviations**: "CK" doesn't embed near "Coca-Cola"
- **Brand-specific shorthand**: "PEP" vs "Pepsi"
- Works well when text is already similar (EASY cases)

#### Edit Distance Limitations

Character-level similarity fails when:
- Source is heavily abbreviated (10 chars vs 30 chars)
- Brand names are completely different strings
- Best for typo detection, not semantic matching

### Empirical Findings and Weight Decisions

Based on accuracy testing with abbreviated retail data:

| Method | Top-1 Accuracy | Conclusion |
|--------|----------------|------------|
| Cortex Search | ~92% | Best overall, handles abbreviations |
| Cosine Similarity | ~71% | Good for similar text, weak on abbreviations |
| Edit Distance | ~45% | Character similarity insufficient |
| Jaccard Similarity | ~80% | Token overlap catches reordered descriptions |

This drove the weight configuration:

```sql
-- Updated weights based on empirical testing
ENSEMBLE_WEIGHT_SEARCH = 0.55  -- Highest weight (Cortex Search best for abbreviations)
ENSEMBLE_WEIGHT_COSINE = 0.25  -- Strong semantic signal
ENSEMBLE_WEIGHT_EDIT = 0.12    -- Tiebreaker for character matches
ENSEMBLE_WEIGHT_JACCARD = 0.18 -- Catches reordered descriptions
```

### Running Accuracy Tests

#### Via CLI

```bash
# Create accuracy testing objects (if not already created by db up)
uv run demo db run 20_accuracy_testing/
```

#### Via SQL

```sql
-- Run accuracy tests
CALL ANALYTICS.RUN_ACCURACY_TESTS();

-- View results
SELECT * FROM ANALYTICS.V_ACCURACY_SUMMARY;
SELECT * FROM ANALYTICS.V_ACCURACY_BY_DIFFICULTY;
SELECT * FROM ANALYTICS.V_DEMO_VALIDATION;
SELECT * FROM ANALYTICS.V_ACCURACY_FAILURES;
```

### Extending the Test Set

To add new test cases:

```sql
INSERT INTO ANALYTICS.ACCURACY_TEST_SET 
    (RAW_DESCRIPTION, EXPECTED_MATCH, CATEGORY, DIFFICULTY, NOTES)
VALUES
    ('NEW TEST CASE', 'Expected Standard Item Name', 'Beverages', 'HARD', 'Description of challenge');

-- Update expected item ID
MERGE INTO ANALYTICS.ACCURACY_TEST_SET t
USING RAW.STANDARD_ITEMS s
ON LOWER(s.STANDARD_DESCRIPTION) = LOWER(t.EXPECTED_MATCH)
WHEN MATCHED AND t.EXPECTED_ITEM_ID IS NULL 
THEN UPDATE SET t.EXPECTED_ITEM_ID = s.STANDARD_ITEM_ID;
```



## Observability & Monitoring

The pipeline includes comprehensive observability for production monitoring.

### Architecture

```ascii
┌─────────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────┐   │
│  │ PIPELINE_        │    │ METHOD_          │    │ ALERT_       │   │
│  │ EXECUTION_LOG    │    │ PERFORMANCE_LOG  │    │ THRESHOLDS   │   │
│  │                  │    │                  │    │              │   │
│  │ • RUN_ID         │    │ • Method metrics │    │ • WARNING    │   │
│  │ • STEP_NAME      │    │ • Accuracy rates │    │ • CRITICAL   │   │
│  │ • STARTED_AT     │    │ • Latency P50/99 │    │ • Per-metric │   │
│  │ • COMPLETED_AT   │    │ • Agreement rate │    │   config     │   │
│  │ • ITEMS_PROCESSED│    │                  │    │              │   │
│  │ • DURATION_MS    │    │                  │    │              │   │
│  │ • ERROR_MESSAGE  │    │                  │    │              │   │
│  └────────┬─────────┘    └────────┬─────────┘    └──────┬───────┘   │
│           │                       │                     │           │
│           └───────────────────────┼─────────────────────┘           │
│                                   │                                 │
│                                   ▼                                 │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                         VIEWS                                │   │
│  ├──────────────────────────────────────────────────────────────┤   │
│  │ V_PIPELINE_STATUS_REALTIME    │ Current run status + ETA     │   │
│  │ V_PIPELINE_PERFORMANCE_HISTORY│ 30-day performance trends    │   │
│  │ V_METHOD_ACCURACY_COMPARISON  │ Per-method accuracy analysis │   │
│  │ V_AGREEMENT_ANALYSIS          │ Method agreement metrics     │   │
│  │ V_PIPELINE_ERRORS_ANALYSIS    │ Error patterns and root cause│   │
│  │ V_RECENT_ERRORS               │ Last 100 errors with context │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Common Queries

```sql
-- Real-time pipeline status
SELECT * FROM ANALYTICS.V_PIPELINE_STATUS_REALTIME;

-- Method accuracy comparison
SELECT * FROM ANALYTICS.V_METHOD_ACCURACY_COMPARISON;

-- Recent errors with context
SELECT * FROM ANALYTICS.V_RECENT_ERRORS;
```

### CLI Integration

```bash
# Show observability metrics in status command
uv run demo data status

# Output includes:
# - Pipeline performance (last 24h)
# - Early exit effectiveness
```

### Web UI: Logs & Observability Tab

The Logs tab in the web application provides a unified view of pipeline telemetry with filtering, sorting, and auto-refresh capabilities.

**Sections:**

| Section | Data Source | Key Columns |
|---------|-------------|-------------|
| Pipeline Execution | `PIPELINE_EXECUTION_LOG` | RUN_ID, STARTED_AT, COMPLETED_AT, STEP_NAME, STATUS, DURATION |
| Recent Errors | `PIPELINE_EXECUTION_LOG` (FAILED) | ERROR_MESSAGE, QUERY_ID, ITEMS_FAILED |
| Method Performance | `METHOD_PERFORMANCE_LOG` | METHOD_NAME, AVG_SCORE, CACHE_HITS |
| Audit Trail | `MATCH_AUDIT_LOG` | ACTION, REVIEWED_BY, OLD/NEW_STATUS |

**RUN_ID Correlation:**

Each pipeline invocation generates a unique RUN_ID (UUID). All steps within that run share the same RUN_ID, making it easy to trace related operations. The UI shows the first 8 characters with the full ID available on hover.

**Timestamps:**

- `STARTED_AT` — When the step began execution
- `COMPLETED_AT` — When the step finished (NULL if still running or failed before completion)
- `DURATION_MS` — Calculated difference in milliseconds

**Filtering & Sorting:**

All columns in the Pipeline Execution table are sortable. Filters are available for:
- Step name (e.g., CLASSIFY_RAW_ITEMS, VECTOR_PREP_BATCH, MATCH_CORTEX_SEARCH_BATCH)
- Status (STARTED, COMPLETED, FAILED, SKIPPED)
- Batch ID (for parallel vector matching execution)

### Native Snowflake Telemetry

In addition to custom logging tables, the system leverages Snowflake's native telemetry infrastructure for deep observability.

```ascii
┌─────────────────────────────────────────────────────────────────────────┐
│                    NATIVE TELEMETRY ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     SNOWFLAKE EVENT TABLE                        │   │
│  │                 SNOWFLAKE.TELEMETRY.EVENTS                       │   │
│  │                                                                  │   │
│  │  • LOG_LEVEL = INFO (procedure logs)                             │   │
│  │  • TRACE_LEVEL = ON_EVENT (spans with attributes)                │   │
│  │  • METRIC_LEVEL = ALL (resource metrics)                         │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
│              ┌───────────────┼───────────────┐                          │
│              │               │               │                          │
│              ▼               ▼               ▼                          │
│  ┌───────────────┐ ┌────────────────┐ ┌─────────────────┐               │
│  │V_NATIVE_      │ │V_NATIVE_       │ │V_NATIVE_        │               │
│  │EVENT_LOGS     │ │TRACES          │ │METRICS          │               │
│  │               │ │                │ │                 │               │
│  │ • SEVERITY    │ │ • TRACE_ID     │ │ • METRIC_NAME   │               │
│  │ • MESSAGE     │ │ • SPAN_ID      │ │ • METRIC_VALUE  │               │
│  │ • DATABASE    │ │ • SPAN_NAME    │ │ • TIMESTAMP     │               │
│  │ • TRACE_ID    │ │ • DURATION_MS  │ │                 │               │
│  └───────────────┘ └────────────────┘ └─────────────────┘               │
│                              │                                          │
│                              ▼                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    COMBINED OBSERVABILITY                        │   │
│  ├──────────────────────────────────────────────────────────────────┤   │
│  │ V_COMBINED_OBSERVABILITY  │ Custom + Native logs unified view    │   │
│  │ V_TRACE_CORRELATION       │ Pipeline runs correlated with traces │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    PYTHON SDK INSTRUMENTATION                    │   │
│  ├──────────────────────────────────────────────────────────────────┤   │
│  │ snowflake-telemetry-python │ API middleware + query spans        │   │
│  │ TRACE_ID auto-capture      │ LOG_PIPELINE_STEP() stores context  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Configuration** (set on HARMONIZER_DEMO database):

| Setting | Value | Purpose |
|---------|-------|---------|
| `LOG_LEVEL` | INFO | Capture procedure log messages |
| `TRACE_LEVEL` | ON_EVENT | Capture spans with custom attributes |
| `METRIC_LEVEL` | ALL | Capture resource consumption metrics |

**Key Views**:

| View | Purpose |
|------|---------|
| `V_NATIVE_EVENT_LOGS` | Native logs from Event Table (7-day window) |
| `V_NATIVE_TRACES` | Span data with duration and attributes |
| `V_NATIVE_METRICS` | Resource metrics from native telemetry |
| `V_COMBINED_OBSERVABILITY` | Union of custom and native logs |
| `V_TRACE_CORRELATION` | Pipeline runs joined with trace context |

**Trace Correlation**:

The `LOG_PIPELINE_STEP()` procedure automatically captures `TRACE_ID` and `SPAN_ID` using `SYSTEM$GET_TRACE_ID()` and `SYSTEM$GET_SPAN_ID()`. This enables correlation between:
- Custom pipeline execution logs
- Native Snowflake traces
- Python API spans (via `snowflake-telemetry-python`)

**Cost Tracking Views**:

| View | Purpose |
|------|---------|
| `V_CORTEX_TOKEN_USAGE` | Token usage by AI function (AI_COMPLETE, AI_CLASSIFY, etc.) |
| `V_CORTEX_CREDIT_CONSUMPTION` | Daily credit consumption for Cortex AI |



## Web UI Technology Stack

The frontend is a React 19 single-page application built with TypeScript and Vite that consumes the FastAPI backend API.

### React Frontend (frontend/react/)

The React frontend is a standalone single-page application providing rich client-side interactivity.

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Framework | React 19 | Component-based UI |
| Language | TypeScript 5.9 | Type safety |
| Build | Vite 7 | Fast dev server and production builds |
| UI Components | shadcn/ui (Radix UI) | Accessible, customizable components |
| Styling | Tailwind CSS 4 | Utility-first CSS |
| Server State | TanStack Query 5 | Data fetching, caching, synchronization |
| Client State | Zustand 5 | Lightweight state management |
| Routing | React Router DOM 6 | Client-side routing |
| Tables | TanStack Table 8 | Headless table logic |

Key directories:
- `frontend/react/src/features/` — Feature modules (Dashboard, Pipeline, Review, etc.)
- `frontend/react/src/components/` — Shared UI components (data-table, sidebar)
- `frontend/react/src/components/ui/` — shadcn/ui primitives
- `frontend/react/src/hooks/` — Custom React hooks
- `frontend/react/src/stores/` — Zustand state stores
- `frontend/react/src/types/` — TypeScript type definitions



## Cost Optimization Strategies

### De-duplication Math

The de-duplication step provides the largest cost reduction:

```
Without de-duplication:
  48,000,000 items × 4 AI methods = 192,000,000 AI calls

With de-duplication:
  500,000 unique × 4 AI methods = 2,000,000 AI calls

Reduction: 96x fewer AI calls
```

### Fast-Path Cache

As reviewers confirm matches, the cache grows:

```
Week 1: 0% fast-path hit rate
Week 4: 15% fast-path hit rate
Week 12: 40% fast-path hit rate
Week 24: 60%+ fast-path hit rate
```

Each cache hit = **zero AI cost** for that description.

### Category Pre-Filtering

`AI_CLASSIFY` reduces the cosine similarity search space:

```
Without category filter:
  Compare each item against 1,000 standard items

With category filter:
  Compare only within category (~250 items on average)

Reduction: 4x fewer vector comparisons
```

### Combined Impact

```
                              AI Calls per Item
─────────────────────────────────────────────────
Baseline (no optimization)    3.0 calls (Search, Cosine, Classify)
+ Category pre-filter         2.5 calls (0.5 for classify, 2.0 filtered)
+ De-duplication              0.026 calls (96x reduction)
+ Fast-path (40% hit rate)    0.016 calls (40% skip AI entirely)
+ Agreement multipliers       0.014 calls (confidence boosts)
```



## Feedback Loop and Learning

### How Reviewer Actions Feed Back

Every review action creates data that improves future matching:

**Confirm/Thumbs Up:**
```
RAW_DESCRIPTION        CORRECT_STANDARD_ID    IS_POSITIVE
─────────────────      ───────────────────    ───────────
COKE 20OZ BTL          STD-001234             TRUE
```

**Change (picked different standard item):**
```
RAW_DESCRIPTION        CORRECT_STANDARD_ID    IS_POSITIVE
─────────────────      ───────────────────    ───────────
COKE 20OZ BTL          STD-001234             TRUE   (chosen item)
COKE 20OZ BTL          STD-005678             FALSE  (rejected suggestion)
```

**Reject:**
```
RAW_DESCRIPTION        CORRECT_STANDARD_ID    IS_POSITIVE
─────────────────      ───────────────────    ───────────
UNKNOWN ITEM XYZ       STD-001234             FALSE
```

### Confirmed-Match Cache

Positive reviews (Confirm, Change, Thumbs Up) add entries to `CONFIRMED_MATCHES`:

```sql
MERGE INTO HARMONIZED.CONFIRMED_MATCHES
USING (...) src
ON tgt.NORMALIZED_DESCRIPTION = src.NORMALIZED_DESCRIPTION
WHEN MATCHED THEN UPDATE SET
    CONFIRMATION_COUNT = CONFIRMATION_COUNT + 1,
    LAST_CONFIRMED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT ...;
```

The cache enables:
- **Instant matching** for known descriptions
- **Consistency** — same description always maps to same standard item
- **Confidence** — confirmation count indicates reliability



## Database Schema Overview

### RAW Schema

Contains source data and reference tables.

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `STANDARD_ITEMS` | Master item list (~500 items) | STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SRP |
| `RAW_RETAIL_ITEMS` | Unmapped vendor items (~1000 demo) | ITEM_ID, RAW_DESCRIPTION, SOURCE_SYSTEM, MATCH_STATUS |
| `STANDARD_ITEMS_EMBEDDINGS` | Pre-computed 1024-dim vectors | STANDARD_ITEM_ID, EMBEDDING (VECTOR) |
| `CATEGORY_TAXONOMY` | Configurable category hierarchy | CATEGORY, SUBCATEGORY, IS_ACTIVE |

### HARMONIZED Schema

Contains matching results, routing destinations, and caching tables.

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `ITEM_MATCHES` | Match results with scores | MATCH_ID, RAW_ITEM_ID, ENSEMBLE_SCORE, MATCH_METHOD |
| `MATCH_CANDIDATES` | Top-N candidates per method | RAW_ITEM_ID, STANDARD_ITEM_ID, RANK, CONFIDENCE_SCORE |
| `UNIQUE_DESCRIPTIONS` | De-duplicated normalized descriptions | NORMALIZED_DESCRIPTION, ITEM_COUNT |
| `CONFIRMED_MATCHES` | Fast-path cache | NORMALIZED_DESCRIPTION, STANDARD_ITEM_ID |
| `PIPELINE_BATCH_STATE` | Persistent batch state for Task DAG coordination | BATCH_ID, STATUS, ITEM_COUNT |
| `STREAM_STAGING` | Safe batch processing buffer (prevents data loss when stream > batch size) | ITEM_ID, RAW_DESCRIPTION, STAGED_AT |
| **Routing Destinations** | | |
| `HARMONIZED_ITEMS` | High-confidence auto-accepted matches (>= 0.80) | RAW_ITEM_ID, MASTER_ITEM_ID, ENSEMBLE_CONFIDENCE_SCORE |
| `REVIEW_QUEUE` | Low-confidence items requiring human review (< 0.80) | RAW_ITEM_ID, SUGGESTED_MASTER_ID, CONFIDENCE_SCORE |
| `REJECTED_ITEMS` | No-match items (all matchers returned NULL/'None') | RAW_ITEM_ID, REJECTION_REASON, RESOLUTION_STATUS |

### ANALYTICS Schema

Contains configuration, audit logs, and operational metrics.

| Table/View | Purpose | Key Columns |
|------------|---------|-------------|
| `CONFIG` | Runtime configuration | CONFIG_KEY, CONFIG_VALUE |
| `MATCH_AUDIT_LOG` | Review history | MATCH_ID, ACTION, REVIEWED_BY |
| `PIPELINE_RUNS` | Run history | RUN_ID, STATUS, ITEMS_PROCESSED |
| `COST_TRACKING` | Per-run cost metrics | CREDITS_CONSUMED, CUMULATIVE_SAVINGS |
| `PIPELINE_EXECUTION_LOG` | Step-by-step execution logging | RUN_ID, STEP_NAME, DURATION_MS |
| `METHOD_PERFORMANCE_LOG` | Per-method accuracy metrics | METHOD_NAME, ACCURACY_RATE |
| `ALERT_THRESHOLDS` | Configurable alert thresholds | METRIC_NAME, WARNING, CRITICAL |
| `ACCURACY_TEST_SET` | Ground truth test cases | RAW_DESCRIPTION, EXPECTED_MATCH, DIFFICULTY |
| `ACCURACY_TEST_RESULTS` | Per-method test results | TEST_ID, METHOD, IS_CORRECT, TOP3_CONTAINS |
| `V_COST_COMPARISON` | Cumulative cost metrics (Task DAG-based) | TOTAL_RUNS, TOTAL_CREDITS_USED, ROI_PERCENTAGE |
| `V_PIPELINE_HEALTH` | Operational status | LAST_RUN_STATUS, REVIEW_QUEUE_DEPTH |
| `V_PIPELINE_STATUS_REALTIME` | Current run status + ETA | RUN_ID, ITEMS_PENDING |
| `V_METHOD_ACCURACY_COMPARISON` | Per-method accuracy analysis | METHOD_NAME, ACCURACY |
| `V_AGREEMENT_ANALYSIS` | Method agreement metrics | AGREEMENT_RATE, ACCURACY |
| `V_FEEDBACK_METRICS` | Feedback loop analytics | FAST_PATH_HIT_RATE, ACCURACY_RATE |
| `V_ACCURACY_SUMMARY` | Accuracy by method | METHOD, TOP1_ACCURACY_PCT |
| `V_ACCURACY_BY_DIFFICULTY` | Accuracy by difficulty level | METHOD, DIFFICULTY, TOP1_PCT |
| `V_DEMO_VALIDATION` | Pass/fail vs 85% target | CORTEX_SEARCH_STATUS, TARGET_ACCURACY |
| `V_ACCURACY_FAILURES` | Detailed failure analysis | RAW_DESCRIPTION, EXPECTED, ACTUAL |

### FEATURE_STORE Schema

Contains ML Feature Views, training data, and model lifecycle tables.

| Table/View | Purpose | Key Columns |
|------------|---------|-------------|
| `FV_SIMILARITY_SCORES` | Feature View: algorithm confidence scores | MATCH_ID, CORTEX_SEARCH_SCORE, COSINE_SCORE, EDIT_DISTANCE_SCORE, JACCARD_SCORE, ENSEMBLE_SCORE |
| `FV_SIGNAL_AGREEMENT` | Feature View: algorithm consensus metrics | MATCH_ID, AGREEMENT_COUNT, METHODS_PARTICIPATING, MAX_SCORE, AVG_SCORE, SCORE_VARIANCE |
| `FV_MATCH_CONTEXT` | Feature View: contextual difficulty signals | MATCH_ID, CATEGORY_MATCH, HAS_BRAND_IN_DESC, DESCRIPTION_LENGTH, TOKEN_COUNT |
| `ML_TRAINING_DATA` | Labeled training dataset | MATCH_ID, features (joined from FVs), WAS_CORRECT (label), CREATED_AT |
| `MODEL_METADATA` | Model registry metadata | MODEL_ID, MODEL_NAME, VERSION, STAGE, METRICS, HYPERPARAMETERS |
| `MODEL_PREDICTIONS` | Prediction logging for monitoring | PREDICTION_ID, MODEL_ID, MATCH_ID, PREDICTED_CONFIDENCE, ACTUAL_OUTCOME |



## Configuration Reference

All configuration is stored in the unified `ANALYTICS.CONFIG` table with category-based organization.

### Table Schema

| Column | Type | Description |
|--------|------|-------------|
| `CONFIG_KEY` | VARCHAR(100) | Unique configuration key (PRIMARY KEY) |
| `CONFIG_VALUE` | VARCHAR(1000) | Configuration value (stored as string) |
| `DATA_TYPE` | VARCHAR(20) | Type hint: STRING, NUMBER, BOOLEAN |
| `CATEGORY` | VARCHAR(50) | Logical grouping: THRESHOLD, MODEL, BATCH, etc. |
| `DESCRIPTION` | VARCHAR(500) | Human-readable description |
| `IS_ACTIVE` | BOOLEAN | Soft-delete flag (default TRUE) |
| `UPDATED_AT` | TIMESTAMP_NTZ | Last modification time |

### Accessing Configuration

```sql
-- Use the GET_CONFIG helper function
SELECT ANALYTICS.GET_CONFIG('EMBEDDING_MODEL');  -- Returns: 'snowflake-arctic-embed-l-v2.0'

-- Query multiple settings by category
SELECT CONFIG_KEY, CONFIG_VALUE FROM ANALYTICS.CONFIG 
WHERE CATEGORY = 'MODEL' AND IS_ACTIVE = TRUE;

-- Query with type casting
SELECT CONFIG_KEY, TRY_TO_DOUBLE(CONFIG_VALUE) AS NUMERIC_VALUE 
FROM ANALYTICS.CONFIG 
WHERE CATEGORY = 'THRESHOLD' AND IS_ACTIVE = TRUE;

-- Update a configuration value
UPDATE ANALYTICS.CONFIG 
SET CONFIG_VALUE = 'snowflake-arctic-embed-l-v2.0', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONFIG_KEY = 'EMBEDDING_MODEL';
```

### Configuration Categories

| Category | Purpose | Example Keys |
|----------|---------|--------------|
| `THRESHOLD` | Score cutoffs for routing | AUTO_ACCEPT_THRESHOLD, REVIEW_THRESHOLD |
| `SCORING` | Ensemble weights and boosts | ENSEMBLE_WEIGHT_SEARCH, AGREEMENT_MULTIPLIER_4WAY |
| `MODEL` | AI model selection | EMBEDDING_MODEL, CLASSIFICATION_MODEL |
| `BATCH` | Processing batch sizes | DEFAULT_BATCH_SIZE, EMBEDDING_BATCH_SIZE |
| `PARALLELISM` | Concurrent execution limits | CORTEX_PARALLEL_THREADS, EMBEDDING_BATCH_SIZE |
| `RETRY` | Error handling configuration | MAX_RETRIES, RETRY_DELAY_SECONDS |
| `AGREEMENT` | Agreement-based scoring | AGREEMENT_MULTIPLIER_4WAY, AGREEMENT_MULTIPLIER_3WAY |
| `COST` | ROI tracking parameters | CREDIT_RATE_USD, BASELINE_WEEKLY_COST |
| `AUTOMATION` | Scheduled execution | AGENTIC_ENABLED, AGENTIC_SCHEDULE |
| `NOTIFICATION` | Alert configuration | NOTIFICATIONS_ENABLED, NOTIFICATION_RECIPIENTS |
| `UI` | Dashboard settings | DASHBOARD_AUTO_REFRESH, DASHBOARD_REFRESH_INTERVAL |
| `GENERAL` | Miscellaneous settings | LOCK_TIMEOUT_MINUTES, MAX_CANDIDATES |

### Matching Weights (SCORING Category)

| Key | Default | Description |
|-----|---------|-------------|
| `ENSEMBLE_WEIGHT_SEARCH` | 0.55 | Cortex Search weight in ensemble score |
| `ENSEMBLE_WEIGHT_COSINE` | 0.25 | Cosine similarity weight |
| `ENSEMBLE_WEIGHT_EDIT` | 0.12 | Edit distance weight |
| `ENSEMBLE_WEIGHT_JACCARD` | 0.18 | Jaccard token similarity weight |
| `AGREEMENT_MULTIPLIER_4WAY` | 1.20 | Score boost when all 4 methods agree |
| `AGREEMENT_MULTIPLIER_3WAY` | 1.15 | Score boost when 3 methods agree |
| `AGREEMENT_MULTIPLIER_2WAY` | 1.10 | Score boost when 2 methods agree |

### Routing Thresholds (THRESHOLD Category)

| Key | Default | Description |
|-----|---------|-------------|
| `AUTO_ACCEPT_THRESHOLD` | 0.80 | Score for automatic acceptance |
| `REVIEW_THRESHOLD` | 0.70 | Minimum score for auto-accept (reviewable) |
| `MIN_CANDIDATE_SCORE` | 0.50 | Minimum score to include candidate |

### Models (MODEL Category)

| Key | Default | Description |
|-----|---------|-------------|
| `CLASSIFICATION_MODEL` | mistral-large2 | Model for AI_CLASSIFY operations |
| `EMBEDDING_MODEL` | snowflake-arctic-embed-l-v2.0 | Embedding model for cosine (1024 dim) |
| `MAX_CANDIDATES` | 10 | Max candidates per method |

### Processing (BATCH Category)

| Key | Default | Description |
|-----|---------|-------------|
| `DEFAULT_BATCH_SIZE` | 200 | Items per pipeline batch |
| `LOCK_TIMEOUT_MINUTES` | 15 | Minutes before review lock expires |

### Parallelism (PARALLELISM Category)

| Key | Default | Description |
|-----|---------|-------------|
| `CORTEX_PARALLEL_THREADS` | 4 | Concurrent threads for Cortex AI functions |
| `EMBEDDING_BATCH_SIZE` | 50 | Items per embedding batch |

### Retry Configuration (RETRY Category)

| Key | Default | Description |
|-----|---------|-------------|
| `MAX_RETRIES` | 3 | Maximum retry attempts for failed operations |
| `RETRY_DELAY_SECONDS` | 5 | Delay between retry attempts |

### Cost Tracking (COST Category)

| Key | Default | Description |
|-----|---------|-------------|
| `CREDIT_RATE_USD` | 3.00 | USD per Snowflake credit |
| `BASELINE_WEEKLY_COST` | 16000 | Manual process weekly cost |
| `BASELINE_ACCURACY` | 0.75 | Manual process accuracy |

### Automation (AUTOMATION & NOTIFICATION Categories)

| Key | Default | Description |
|-----|---------|-------------|
| `AGENTIC_ENABLED` | false | Enable automated daily runs |
| `AGENTIC_SCHEDULE` | 0 6 * * * | Cron schedule for automation |
| `NOTIFICATIONS_ENABLED` | false | Enable email notifications after pipeline runs |
| `NOTIFICATION_THRESHOLD` | 50 | Minimum PENDING_REVIEW items to trigger notification |
| `NOTIFICATION_RECIPIENTS` | (empty) | Comma-separated email addresses for notifications |
| `NOTIFICATION_INTEGRATION` | HARMONIZER_PRICING_NOTIFICATION | Snowflake email integration name |

### UI Settings (UI Category)

| Key | Default | Description |
|-----|---------|-------------|
| `DASHBOARD_AUTO_REFRESH` | true | Enable automatic dashboard refresh |
| `DASHBOARD_REFRESH_INTERVAL` | 30 | Seconds between dashboard refreshes |



## Build Automation

The project includes a comprehensive `Makefile` for streamlined development workflows. This provides a consistent interface for common operations without requiring knowledge of underlying tool invocations.

### Quick Reference

| Command | Description |
|---------|-------------|
| `make help` | Show all available targets organized by category |
| `make setup` | Full environment setup: database + pipeline + seed data |
| `make validate` | Run lint + tests |
| `make serve` | Start FastAPI web server |

### Target Categories

The Makefile organizes ~30 targets into logical categories:

```ascii
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MAKEFILE TARGETS                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ENVIRONMENT          CODE QUALITY         TESTING                          │
│  ─────────────        ────────────         ───────                          │
│  • install            • lint               • test                           │
│  • install-dev        • format             • test-cov                       │
│  • preflight          • check-format       • test-watch                     │
│                       • validate                                            │
│                                                                             │
│  DATABASE/SQL         DATA PIPELINE        WEB APP                          │
│  ───────────          ─────────────        ───────                          │
│  • db-up              • data-run           • serve                          │
│  • db-down            • data-status        • serve-dev                      │
│  • db-reset           • data-seed                                           │
│  • sql-validate       • data-stop                                           │
│                                                                             │
│  DOCKER               SPCS DEPLOYMENT      ACCURACY                         │
│  ──────               ───────────────      ────────                         │
│  • docker-build       • spcs-deploy        • accuracy-test                  │
│  • docker-run         • spcs-status        • accuracy-report                │
│  • docker-push        • spcs-logs                                           │
│                       • spcs-drop                                           │
│                                                                             │
│  CLEANUP/STATUS                                                             │
│  ──────────────                                                             │
│  • clean              • status                                              │
│  • clean-pyc          • version                                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Snowflake Connection Override

All database-related targets support a configurable Snowflake connection via the `CONN` parameter:

```bash
# Use default connection
make db-up

# Override with specific connection
make db-up CONN=myconn
make data-run CONN=production
make setup CONN=dev_account
```

The connection name is passed to the CLI via `-c` flag: `uv run demo -c $(CONN) ...`

### Common Workflows

**Initial Setup:**
```bash
make preflight          # Check required tools are installed
make setup              # Full setup (database + pipeline + seed data)
make serve              # Start web interface
```

**Development Cycle:**
```bash
make lint               # Check code style
make format             # Auto-fix formatting
make test               # Run test suite
make validate           # Lint + test (CI check)
```

**Pipeline Operations:**
```bash
make data-run           # Enable Task DAG and trigger run
make data-status        # Check pipeline and match status
make data-stop          # Disable Task DAG
```

**Container Deployment:**
```bash
make docker-build       # Build linux/amd64 image
make spcs-deploy        # Deploy to Snowpark Container Services
make spcs-logs          # Tail service logs
```

### Tool Auto-Detection

The Makefile auto-detects tool paths to provide helpful error messages:

```makefile
UV := $(shell command -v uv 2>/dev/null || echo "uv")
DOCKER := $(shell command -v docker 2>/dev/null || echo "docker")
SNOW := $(shell command -v snow 2>/dev/null || echo "snow")
```

If a tool is missing, commands fail with clear "command not found" messages rather than cryptic errors.

### Integration with CI/CD

The Makefile targets are designed for CI/CD integration:

```yaml
# Example GitHub Actions workflow
- name: Install dependencies
  run: make install-dev

- name: Validate code
  run: make validate

- name: Run accuracy tests
  run: make accuracy-test CONN=${{ secrets.SNOWFLAKE_CON