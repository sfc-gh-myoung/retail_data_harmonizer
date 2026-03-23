-- ============================================================================
-- sql/setup/12_parallel_matchers.sql
-- Retail Data Harmonizer - Method-Level Parallel Vector Matching
--
-- Creates batch procedures for TRUE parallel execution via Snowflake Task DAG:
--   1. VECTOR_PREP_BATCH() - Consumes stream, generates embeddings, creates batch stubs
--   2. MATCH_CORTEX_SEARCH_BATCH() - Cortex Search matching -> CORTEX_SEARCH_STAGING
--   3. MATCH_COSINE_BATCH() - Cosine similarity matching -> COSINE_MATCH_STAGING
--   4. MATCH_EDIT_BATCH() - Edit distance matching -> EDIT_MATCH_STAGING
--   5. MATCH_JACCARD_BATCH() - Jaccard similarity matching -> JACCARD_MATCH_STAGING
--
-- Architecture:
--   - Stream (RAW_ITEMS_STREAM) provides exactly-once processing
--   - Each method writes to its own TRANSIENT staging table (no locking)
--   - BATCH_ID ties all staging tables together for ensemble scoring
--   - Task DAG: DEDUP_FASTPATH_TASK -> CLASSIFY_UNIQUE_TASK -> VECTOR_PREP_TASK -> [4 parallel tasks] -> VECTOR_ENSEMBLE_TASK
--
-- Task Coordination:
--   Uses TASK_COORDINATION table (message queue pattern) instead of
--   SYSTEM$SET_RETURN_VALUE / SYSTEM$GET_PREDECESSOR_RETURN_VALUE.
--   Each procedure checks parent task status and registers its own status.
--
-- Depends on: 02_schema_and_tables.sql (staging tables, stream), 11_matching/, 15_task_coordination.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- VECTOR_PREP_BATCH: Third-stage procedure (after DEDUP and CLASSIFY steps)
-- Consumes stream if available, otherwise falls back to pending items
-- Generates embeddings and returns batch ID for downstream tasks
-- Uses TASK_COORDINATION table for task-to-task communication
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_BATCH(
    P_BATCH_SIZE INT DEFAULT 500
)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Prepares batch for matching. Uses stream if available, falls back to pending items. Uses coordination table.'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_batch_id VARCHAR;
    v_items_consumed INTEGER DEFAULT 0;
    v_embeddings_created INTEGER DEFAULT 0;
    v_has_stream_data VARCHAR;
    v_run_id VARCHAR;
    v_parent_status VARIANT;
BEGIN
    v_batch_id := UUID_STRING();
    
    -- Get run_id from parent task (CLASSIFY_UNIQUE)
    v_run_id := HARMONIZER_DEMO.HARMONIZED.GET_LATEST_RUN_ID('CLASSIFY_UNIQUE');
    IF (v_run_id IS NULL) THEN
        v_run_id := HARMONIZER_DEMO.HARMONIZED.GET_LATEST_RUN_ID('DEDUP_FASTPATH');
    END IF;
    IF (v_run_id IS NULL) THEN
        v_run_id := UUID_STRING();
    END IF;
    
    -- Check parent task status - skip if parent skipped/failed
    v_parent_status := HARMONIZER_DEMO.HARMONIZED.GET_PARENT_TASK_STATUS('CLASSIFY_UNIQUE', 10);
    IF (v_parent_status IS NOT NULL AND v_parent_status:status::VARCHAR IN ('SKIPPED', 'FAILED')) THEN
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'VECTOR_PREP', 'SKIPPED',
            OBJECT_CONSTRUCT('reason', 'Parent task CLASSIFY_UNIQUE was ' || v_parent_status:status::VARCHAR)
        );
        RETURN OBJECT_CONSTRUCT(
            'batch_id', :v_batch_id,
            'run_id', :v_run_id,
            'status', 'skipped',
            'reason', 'Parent task CLASSIFY_UNIQUE was ' || v_parent_status:status::VARCHAR
        );
    END IF;
    
    -- Register task start in coordination table
    CALL HARMONIZER_DEMO.HARMONIZED.REGISTER_TASK_START(:v_run_id, 'VECTOR_PREP');
    
    -- =========================================================================
    -- Step 1: Check stream for new items, fall back to pending items if empty
    -- FIX: Consume ALL stream rows first to prevent data loss, then batch
    -- =========================================================================
    SELECT SYSTEM$STREAM_HAS_DATA('HARMONIZER_DEMO.HARMONIZED.RAW_ITEMS_STREAM') INTO :v_has_stream_data;
    
    IF (v_has_stream_data = 'true') THEN
        -- CRITICAL FIX: First, consume ALL stream rows into persistent staging
        -- This prevents data loss when stream has more rows than batch size
        -- The stream offset advances atomically when we SELECT from it in DML
        MERGE INTO HARMONIZER_DEMO.HARMONIZED.STREAM_STAGING tgt
        USING (
            SELECT 
                ITEM_ID,
                RAW_DESCRIPTION,
                SOURCE_SYSTEM,
                INFERRED_CATEGORY,
                CURRENT_TIMESTAMP() AS STAGED_AT
            FROM HARMONIZER_DEMO.HARMONIZED.RAW_ITEMS_STREAM
        ) src
        ON tgt.ITEM_ID = src.ITEM_ID
        WHEN NOT MATCHED THEN INSERT 
            (ITEM_ID, RAW_DESCRIPTION, SOURCE_SYSTEM, INFERRED_CATEGORY, STAGED_AT)
        VALUES 
            (src.ITEM_ID, src.RAW_DESCRIPTION, src.SOURCE_SYSTEM, src.INFERRED_CATEGORY, src.STAGED_AT);
    END IF;
    
    -- Build batch from UNIQUE_DESCRIPTIONS that are PENDING and have staged raw items.
    -- Staging items -> dedup to unique desc IDs, pick oldest staged_at per group.
    -- ITEM_ID in BATCH_ITEMS is UNIQUE_DESC_ID; RAW_DESCRIPTION is NORMALIZED_DESCRIPTION.
    -- NOTE: Using permanent table (not TEMPORARY) so child tasks can access it.
    CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.BATCH_ITEMS AS
    SELECT 
        ud.UNIQUE_DESC_ID     AS ITEM_ID,
        ud.NORMALIZED_DESCRIPTION AS RAW_DESCRIPTION,
        MIN(ss.SOURCE_SYSTEM) AS SOURCE_SYSTEM,
        ri.INFERRED_CATEGORY,
        :v_batch_id           AS BATCH_ID
    FROM HARMONIZER_DEMO.HARMONIZED.STREAM_STAGING ss
    JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.RAW_ITEM_ID = ss.ITEM_ID
    JOIN HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud ON ud.UNIQUE_DESC_ID = rum.UNIQUE_DESC_ID
    JOIN (
        SELECT rum2.UNIQUE_DESC_ID, ri2.INFERRED_CATEGORY
        FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum2
        JOIN HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri2 ON ri2.ITEM_ID = rum2.RAW_ITEM_ID
        QUALIFY ROW_NUMBER() OVER (PARTITION BY rum2.UNIQUE_DESC_ID ORDER BY ri2.ITEM_ID) = 1
    ) ri ON ri.UNIQUE_DESC_ID = ud.UNIQUE_DESC_ID
    WHERE ud.MATCH_STATUS = 'PENDING'
    GROUP BY ud.UNIQUE_DESC_ID, ud.NORMALIZED_DESCRIPTION, ri.INFERRED_CATEGORY
    ORDER BY MIN(ss.STAGED_AT) ASC
    LIMIT :P_BATCH_SIZE;
    
    -- If staging has nothing, fall back to all PENDING unique descriptions
    SELECT COUNT(*) INTO :v_items_consumed FROM HARMONIZER_DEMO.HARMONIZED.BATCH_ITEMS;
    
    IF (:v_items_consumed = 0) THEN
        CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.BATCH_ITEMS AS
        SELECT 
            ud.UNIQUE_DESC_ID     AS ITEM_ID,
            ud.NORMALIZED_DESCRIPTION AS RAW_DESCRIPTION,
            NULL                  AS SOURCE_SYSTEM,
            ri.INFERRED_CATEGORY,
            :v_batch_id           AS BATCH_ID
        FROM HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud
        JOIN (
            SELECT rum.UNIQUE_DESC_ID, ri2.INFERRED_CATEGORY
            FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum
            JOIN HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri2 ON ri2.ITEM_ID = rum.RAW_ITEM_ID
            QUALIFY ROW_NUMBER() OVER (PARTITION BY rum.UNIQUE_DESC_ID ORDER BY ri2.ITEM_ID) = 1
        ) ri ON ri.UNIQUE_DESC_ID = ud.UNIQUE_DESC_ID
        WHERE ud.MATCH_STATUS = 'PENDING'
        LIMIT :P_BATCH_SIZE;
    END IF;
    
    SELECT COUNT(*) INTO :v_items_consumed FROM HARMONIZER_DEMO.HARMONIZED.BATCH_ITEMS;
    
    -- Early exit if no items: do NOT update PIPELINE_BATCH_STATE.
    -- Overwriting the ACTIVE batch_id with an empty batch would cause VECTOR_ENSEMBLE_TASK
    -- to query the wrong (empty) batch_id, orphaning any staging data from the real batch.
    IF (:v_items_consumed = 0) THEN
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'VECTOR_PREP', 'SKIPPED',
            OBJECT_CONSTRUCT('reason', 'No pending items to process')
        );
        RETURN OBJECT_CONSTRUCT(
            'batch_id', :v_batch_id,
            'run_id', :v_run_id,
            'status', 'empty',
            'items_consumed', 0,
            'message', 'No pending items to process'
        );
    END IF;
    
    -- Only register a new active batch when we actually have items to process.
    -- Mark previous active batch COMPLETED and insert the new one atomically.
    UPDATE HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE
    SET STATUS = 'COMPLETED', COMPLETED_AT = CURRENT_TIMESTAMP()
    WHERE STATUS = 'ACTIVE';
    
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE (BATCH_ID, ITEM_COUNT, STATUS)
    VALUES (:v_batch_id, :v_items_consumed, 'ACTIVE');
    
    -- =========================================================================
    -- Step 2: Generate embeddings for unique descriptions missing them
    -- Stored in UNIQUE_DESC_EMBEDDINGS (one vector per unique description)
    -- =========================================================================
    -- Step 2: Generate embeddings for unique descriptions missing them
    -- Stored in UNIQUE_DESC_EMBEDDINGS (one vector per unique description)
    -- =========================================================================
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESC_EMBEDDINGS (UNIQUE_DESC_ID, NORMALIZED_DESCRIPTION, EMBEDDING)
    SELECT
        bi.ITEM_ID,
        bi.RAW_DESCRIPTION,
        SNOWFLAKE.CORTEX.EMBED_TEXT_1024('snowflake-arctic-embed-l-v2.0', bi.RAW_DESCRIPTION)
    FROM HARMONIZER_DEMO.HARMONIZED.BATCH_ITEMS bi
    WHERE NOT EXISTS (
        SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESC_EMBEDDINGS ude
        WHERE ude.UNIQUE_DESC_ID = bi.ITEM_ID
    );
    
    v_embeddings_created := SQLROWCOUNT;
    
    -- =========================================================================
    -- Step 3: Create ITEM_MATCHES stubs for ALL raw items that map to each
    -- unique description in this batch (fan-out from unique → raw).
    -- This ensures every raw item gets a match record keyed by its own ITEM_ID.
    -- =========================================================================
    MERGE INTO HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES tgt
    USING (
        SELECT DISTINCT rum.RAW_ITEM_ID
        FROM HARMONIZER_DEMO.HARMONIZED.BATCH_ITEMS bi
        JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.UNIQUE_DESC_ID = bi.ITEM_ID
    ) src
    ON tgt.RAW_ITEM_ID = src.RAW_ITEM_ID
    WHEN NOT MATCHED THEN INSERT
        (MATCH_ID, RAW_ITEM_ID, MATCH_METHOD, CREATED_AT)
    VALUES
        (UUID_STRING(), src.RAW_ITEM_ID, 'PENDING', CURRENT_TIMESTAMP());
    
    -- =========================================================================
    -- Step 4: Clean up stream staging rows for raw items whose unique
    -- description is now being processed in this batch.
    -- =========================================================================
    DELETE FROM HARMONIZER_DEMO.HARMONIZED.STREAM_STAGING
    WHERE ITEM_ID IN (
        SELECT rum.RAW_ITEM_ID
        FROM HARMONIZER_DEMO.HARMONIZED.BATCH_ITEMS bi
        JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.UNIQUE_DESC_ID = bi.ITEM_ID
    );
    
    -- Update coordination table with COMPLETED status
    CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
        :v_run_id, 'VECTOR_PREP', 'COMPLETED',
        OBJECT_CONSTRUCT(
            'batch_id', :v_batch_id,
            'items_consumed', :v_items_consumed,
            'embeddings_created', :v_embeddings_created
        )
    );
    
    RETURN OBJECT_CONSTRUCT(
        'batch_id', :v_batch_id,
        'run_id', :v_run_id,
        'status', 'ready',
        'items_consumed', :v_items_consumed,
        'embeddings_created', :v_embeddings_created
    );
EXCEPTION
    WHEN OTHER THEN
        LET err_msg VARCHAR := SQLERRM;
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'VECTOR_PREP', 'FAILED',
            OBJECT_CONSTRUCT('error', :err_msg)
        );
        RETURN OBJECT_CONSTRUCT(
            'batch_id', :v_batch_id,
            'run_id', :v_run_id,
            'status', 'error',
            'error', :err_msg
        );
END;
$$;


-- ============================================================================
-- MATCH_CORTEX_SEARCH_BATCH: Cortex Search matching (PARALLELIZED with RATE LIMITING)
-- Runs in parallel with MATCH_COSINE_BATCH and MATCH_EDIT_BATCH
-- Writes results to CORTEX_SEARCH_STAGING (no locking conflicts)
-- Uses TASK_COORDINATION table for status tracking
--
-- OPTIMIZATION v3: Rate-limited parallel API calls with exponential backoff
-- - Reduced default parallelism (4 threads) to avoid rate limits
-- - Exponential backoff with 3 retry attempts per item
-- - Skips items with UNKNOWN/NULL category (no valid search results)
-- - Balanced approach: ~5% acceptable failure rate for speed
--
-- NOTE: SEARCH_PREVIEW requires literal constant arguments (Snowflake limitation)
-- so we parallelize at the Python level using concurrent.futures
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.MATCH_CORTEX_SEARCH_BATCH(
    P_BATCH_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
COMMENT = 'Cortex Search matching for batch. Rate-limited parallelism with exponential backoff. Uses coordination table.'
EXECUTE AS OWNER
AS
$$
import json
import uuid
import time
import random
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from typing import List, Dict, Any, Tuple, Optional
import threading

# Rate limiting constants
MAX_RETRIES = 3
BASE_DELAY_SECONDS = 0.5
MAX_DELAY_SECONDS = 8.0
JITTER_FACTOR = 0.3

def escape_sql_string(s: str) -> str:
    """Safely escape a string for SQL insertion."""
    if s is None:
        return ""
    return s.replace("\\", "\\\\").replace("'", "''")

def get_config_value(session, key: str, default: int) -> int:
    """Get configured value from CONFIG."""
    try:
        result = session.sql(f"""
            SELECT CONFIG_VALUE FROM HARMONIZER_DEMO.ANALYTICS.CONFIG 
            WHERE CONFIG_KEY = '{key}'
        """).collect()
        if result:
            return int(result[0]["CONFIG_VALUE"])
    except:
        pass
    return default

def calculate_backoff(attempt: int) -> float:
    """Calculate exponential backoff with jitter."""
    delay = min(BASE_DELAY_SECONDS * (2 ** attempt), MAX_DELAY_SECONDS)
    jitter = delay * JITTER_FACTOR * random.random()
    return delay + jitter

def is_rate_limit_error(error_str: str) -> bool:
    """Check if error is a rate limit that should trigger retry."""
    rate_limit_indicators = [
        "rate limit",
        "429",
        "399129",
        "too many requests",
        "throttl",
        "Service rate limit exceeded"
    ]
    error_lower = error_str.lower()
    return any(indicator.lower() in error_lower for indicator in rate_limit_indicators)

def search_single_item_with_retry(session, item: Dict, db: str) -> Dict[str, Any]:
    """
    Execute Cortex Search for a single item with exponential backoff retry.
    Thread-safe: each call uses the shared session for read-only SQL.
    """
    item_id = item["ITEM_ID"]
    raw_desc = item["RAW_DESCRIPTION"]
    category = item["INFERRED_CATEGORY"]
    
    result = {
        "item_id": item_id,
        "search_matched_id": None,
        "search_score": 0.0,
        "search_reasoning": "No match found",
        "candidates": [],
        "error": None,
        "skipped": False,
        "retries": 0
    }
    
    # Skip items with UNKNOWN or NULL category - they won't match anything
    if not category or category.upper() in ("UNKNOWN", "NULL", "NONE", ""):
        result["skipped"] = True
        result["search_reasoning"] = f"Skipped: category is {category or 'NULL'}"
        return result
    
    last_error = None
    for attempt in range(MAX_RETRIES):
        try:
            # Build Cortex Search query
            safe_desc_json = raw_desc.replace("\\", "\\\\").replace('"', '\\"').replace("'", "''")
            safe_cat_json = category.replace("\\", "\\\\").replace('"', '\\"')
            query_json = (
                '{'
                f'"query": "{safe_desc_json}",'
                '"columns": ["STANDARD_ITEM_ID", "STANDARD_DESCRIPTION", "CATEGORY", "BRAND", "SRP"],'
                f'"filter": {{"@eq": {{"CATEGORY": "{safe_cat_json}"}}}},'
                '"limit": 5'
                '}'
            )
            
            results = session.sql(f"""
                SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                    'HARMONIZER_DEMO.HARMONIZED.STANDARD_ITEM_SEARCH',
                    '{query_json}'
                ) AS results
            """).collect()
            
            if results and results[0]["RESULTS"]:
                search_results = json.loads(results[0]["RESULTS"]) if isinstance(results[0]["RESULTS"], str) else results[0]["RESULTS"]
                if "results" in search_results and search_results["results"]:
                    all_candidates = search_results["results"]
                    best = all_candidates[0]
                    result["search_matched_id"] = best.get("STANDARD_ITEM_ID", "")
                    
                    # Extract cosine_similarity from @scores and normalize to [0,1]
                    scores = best.get("@scores", {})
                    cosine_sim = scores.get("cosine_similarity", 0)
                    result["search_score"] = (cosine_sim + 1) / 2 if cosine_sim else 0.5
                    result["search_reasoning"] = f"Matched to {best.get('STANDARD_DESCRIPTION', '')[:100]}"
                    
                    # Collect ALL candidates for alternatives display
                    for rank, cand in enumerate(all_candidates):
                        cand_scores = cand.get("@scores", {})
                        cand_cosine = cand_scores.get("cosine_similarity", 0)
                        result["candidates"].append({
                            "id": cand.get("STANDARD_ITEM_ID", ""),
                            "desc": cand.get("STANDARD_DESCRIPTION", "")[:500],
                            "score": (cand_cosine + 1) / 2 if cand_cosine else 0.5,
                            "rank": rank + 1
                        })
            
            result["retries"] = attempt
            return result  # Success - exit retry loop
                    
        except Exception as e:
            last_error = str(e)[:200]
            result["retries"] = attempt + 1
            
            # Only retry on rate limit errors
            if is_rate_limit_error(last_error) and attempt < MAX_RETRIES - 1:
                backoff = calculate_backoff(attempt)
                time.sleep(backoff)
                continue
            else:
                # Non-rate-limit error or final attempt - don't retry
                break
    
    # All retries exhausted or non-retryable error
    result["error"] = last_error
    return result

def run(session, p_batch_id: str) -> Dict[str, Any]:
    """
    Rate-limited Cortex Search matching for all items in the batch.
    
    Key features:
    1. Reduced parallelism (default 4 threads) to avoid rate limits
    2. Exponential backoff with jitter on rate limit errors
    3. Skips UNKNOWN category items (no valid matches possible)
    4. Bulk INSERT for database writes
    5. Uses TASK_COORDINATION table for status tracking
    
    Writes results to CORTEX_SEARCH_STAGING and MATCH_CANDIDATES tables.
    """
    db = "HARMONIZER_DEMO"
    batch_id = p_batch_id
    CHUNK_SIZE = 100  # Rows per bulk INSERT
    start_time = datetime.now()
    
    # Get run_id from parent task (VECTOR_PREP)
    run_id = None
    try:
        result = session.sql(f"""
            SELECT HARMONIZER_DEMO.HARMONIZED.GET_LATEST_RUN_ID('VECTOR_PREP') AS run_id
        """).collect()
        if result and result[0]["RUN_ID"]:
            run_id = result[0]["RUN_ID"]
    except:
        pass
    if not run_id:
        run_id = str(uuid.uuid4())
    
    # Check parent task status - skip if parent skipped/failed
    try:
        parent_status = session.sql(f"""
            SELECT HARMONIZER_DEMO.HARMONIZED.GET_PARENT_TASK_STATUS('VECTOR_PREP', 10) AS status
        """).collect()
        if parent_status and parent_status[0]["STATUS"]:
            status_obj = json.loads(parent_status[0]["STATUS"]) if isinstance(parent_status[0]["STATUS"], str) else parent_status[0]["STATUS"]
            if status_obj and status_obj.get("status") in ("SKIPPED", "FAILED"):
                session.call('HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS',
                    run_id, 'CORTEX_SEARCH', 'SKIPPED',
                    json.dumps({"reason": f"Parent task VECTOR_PREP was {status_obj.get('status')}"}))
                return {
                    "batch_id": batch_id,
                    "run_id": run_id,
                    "status": "skipped",
                    "reason": f"Parent task was {status_obj.get('status')}"
                }
    except:
        pass  # Continue even if check fails
    
    # Register task start in coordination table
    try:
        session.call('HARMONIZER_DEMO.HARMONIZED.REGISTER_TASK_START', run_id, 'CORTEX_SEARCH')
    except:
        pass  # Don't fail on coordination errors
    
    # Log STARTED for telemetry
    try:
        session.call('HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP',
            batch_id, 'MATCH_CORTEX_SEARCH_BATCH', 'STARTED', 0, 0, 0, start_time)
    except:
        pass  # Don't fail on telemetry errors
    
    # Get configured parallelism - default reduced to 4 for rate limiting
    parallel_threads = get_config_value(session, 'CORTEX_PARALLEL_THREADS', 4)
    parallel_threads = max(1, min(parallel_threads, 6))  # Clamp 1-6 for rate limit safety
    
    # Get batch items from BATCH_ITEMS (keyed by UNIQUE_DESC_ID)
    # Only process unique descs that don't yet have a Cortex Search score in staging
    items = session.sql(f"""
        SELECT bi.ITEM_ID, bi.RAW_DESCRIPTION, bi.INFERRED_CATEGORY
        FROM {db}.HARMONIZED.BATCH_ITEMS bi
        WHERE bi.INFERRED_CATEGORY IS NOT NULL
          AND UPPER(bi.INFERRED_CATEGORY) NOT IN ('UNKNOWN', 'NULL', 'NONE', '')
          AND NOT EXISTS (
              SELECT 1 FROM {db}.HARMONIZED.CORTEX_SEARCH_STAGING css
              WHERE css.RAW_ITEM_ID = bi.ITEM_ID
          )
        LIMIT 500
    """).collect()
    
    if not items:
        try:
            session.call('HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS',
                run_id, 'CORTEX_SEARCH', 'SKIPPED',
                json.dumps({"reason": "No eligible items (UNKNOWN categories excluded)"}))
        except:
            pass
        return {
            "batch_id": batch_id,
            "run_id": run_id,
            "status": "empty", 
            "matched": 0, 
            "parallel_threads": parallel_threads,
            "note": "No eligible items (UNKNOWN categories excluded)"
        }
    
    # =========================================================================
    # PHASE 1: Rate-limited parallel API calls with retry
    # =========================================================================
    all_results: List[Dict] = []
    errors: List[str] = []
    skipped_count = 0
    retry_count = 0
    
    with ThreadPoolExecutor(max_workers=parallel_threads) as executor:
        # Submit all search tasks
        future_to_item = {
            executor.submit(search_single_item_with_retry, session, item, db): item 
            for item in items
        }
        
        # Collect results as they complete
        for future in as_completed(future_to_item):
            try:
                result = future.result()
                all_results.append(result)
                
                if result.get("skipped"):
                    skipped_count += 1
                elif result.get("error"):
                    errors.append(f"{result['item_id']}: {result['error']}")
                
                retry_count += result.get("retries", 0)
                    
            except Exception as e:
                item = future_to_item[future]
                errors.append(f"{item['ITEM_ID']}: {str(e)[:100]}")
    
    # =========================================================================
    # PHASE 2: Bulk INSERT all collected results
    # =========================================================================
    staging_values: List[str] = []
    candidates_values: List[str] = []
    
    for result in all_results:
        # Skip items that were skipped (UNKNOWN category) or had errors without matches
        if result.get("skipped"):
            continue
        if result.get("error") and not result.get("search_matched_id"):
            continue
            
        item_id = result["item_id"]
        safe_item_id = escape_sql_string(item_id)
        safe_batch_id = escape_sql_string(batch_id)
        matched_id_sql = f"'{escape_sql_string(result['search_matched_id'])}'" if result['search_matched_id'] else "NULL"
        safe_reasoning = escape_sql_string(result['search_reasoning'])[:500]
        
        staging_values.append(
            f"('{safe_item_id}', '{safe_batch_id}', {matched_id_sql}, "
            f"{result['search_score']:.6f}, '{safe_reasoning}', CURRENT_TIMESTAMP())"
        )
        
        # Collect candidates for MATCH_CANDIDATES table
        # Column order: CANDIDATE_ID, RAW_ITEM_ID, STANDARD_ITEM_ID, STANDARD_DESCRIPTION, RANK, CONFIDENCE_SCORE, MATCH_METHOD
        for cand in result.get("candidates", []):
            cand_uuid = str(uuid.uuid4())
            cand_id = escape_sql_string(cand["id"])
            cand_desc = escape_sql_string(cand["desc"])
            candidates_values.append(
                f"('{cand_uuid}', '{safe_item_id}', '{cand_id}', "
                f"'{cand_desc}', {cand['rank']}, {cand['score']:.6f}, 'CORTEX_SEARCH')"
            )
    
    # Bulk insert staging results
    staging_inserted = 0
    for i in range(0, len(staging_values), CHUNK_SIZE):
        chunk = staging_values[i:i+CHUNK_SIZE]
        values_sql = ",\n".join(chunk)
        try:
            session.sql(f"""
                INSERT INTO {db}.HARMONIZED.CORTEX_SEARCH_STAGING
                    (RAW_ITEM_ID, BATCH_ID, SEARCH_MATCHED_ID, SEARCH_SCORE, SEARCH_REASONING, PROCESSED_AT)
                VALUES
                {values_sql}
            """).collect()
            staging_inserted += len(chunk)
        except Exception as e:
            errors.append(f"Staging bulk insert failed at chunk {i//CHUNK_SIZE}: {str(e)[:100]}")
    
    # Bulk insert candidates using temp table + MERGE
    candidates_inserted = 0
    if candidates_values:
        try:
            session.sql(f"""
                CREATE OR REPLACE TEMPORARY TABLE {db}.HARMONIZED.TEMP_CANDIDATES (
                    CANDIDATE_ID VARCHAR(36),
                    RAW_ITEM_ID VARCHAR(50),
                    STANDARD_ITEM_ID VARCHAR(50),
                    STANDARD_DESCRIPTION VARCHAR(500),
                    RANK INT,
                    CONFIDENCE_SCORE FLOAT,
                    MATCH_METHOD VARCHAR(50)
                )
            """).collect()
            
            for i in range(0, len(candidates_values), CHUNK_SIZE):
                chunk = candidates_values[i:i+CHUNK_SIZE]
                values_sql = ",\n".join(chunk)
                session.sql(f"""
                    INSERT INTO {db}.HARMONIZED.TEMP_CANDIDATES
                        (CANDIDATE_ID, RAW_ITEM_ID, STANDARD_ITEM_ID, STANDARD_DESCRIPTION, 
                         RANK, CONFIDENCE_SCORE, MATCH_METHOD)
                    VALUES
                    {values_sql}
                """).collect()
            
            session.sql(f"""
                MERGE INTO {db}.HARMONIZED.MATCH_CANDIDATES tgt
                USING {db}.HARMONIZED.TEMP_CANDIDATES src
                ON tgt.RAW_ITEM_ID = src.RAW_ITEM_ID 
                   AND tgt.STANDARD_ITEM_ID = src.STANDARD_ITEM_ID
                WHEN NOT MATCHED THEN INSERT
                    (CANDIDATE_ID, RAW_ITEM_ID, STANDARD_ITEM_ID, STANDARD_DESCRIPTION,
                     RANK, CONFIDENCE_SCORE, MATCH_METHOD)
                VALUES
                    (src.CANDIDATE_ID, src.RAW_ITEM_ID, src.STANDARD_ITEM_ID, src.STANDARD_DESCRIPTION,
                     src.RANK, src.CONFIDENCE_SCORE, src.MATCH_METHOD)
            """).collect()
            
            candidates_inserted = len(candidates_values)
            session.sql(f"DROP TABLE IF EXISTS {db}.HARMONIZED.TEMP_CANDIDATES").collect()
            
        except Exception as e:
            errors.append(f"Candidates bulk insert failed: {str(e)[:100]}")
    
    # Log COMPLETED for telemetry
    matched_count = len([r for r in all_results if r.get("search_matched_id")])
    try:
        session.call('HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP',
            batch_id, 'MATCH_CORTEX_SEARCH_BATCH', 'COMPLETED', matched_count, 0, 0, start_time)
    except:
        pass  # Don't fail on telemetry errors
    
    # Update coordination table with COMPLETED status
    try:
        session.call('HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS',
            run_id, 'CORTEX_SEARCH', 'COMPLETED',
            json.dumps({"batch_id": batch_id, "matched": matched_count}))
    except:
        pass  # Don't fail on coordination errors
    
    return {
        "batch_id": batch_id,
        "run_id": run_id,
        "status": "complete",
        "items_processed": len(items),
        "matched": matched_count,
        "skipped_unknown_category": skipped_count,
        "staging_inserted": staging_inserted,
        "candidates_inserted": candidates_inserted,
        "parallel_threads": parallel_threads,
        "total_retries": retry_count,
        "errors": errors[:5],
        "error_count": len(errors)
    }
$$;


-- ============================================================================
-- BACKFILL_MATCH_CANDIDATES: Populate candidates for existing matched items
-- 
-- One-time utility to backfill MATCH_CANDIDATES for items that already have
-- CORTEX_SEARCH_SCORE but no saved candidates (due to prior rate limiting issues).
--
-- Uses same rate-limited approach as MATCH_CORTEX_SEARCH_BATCH:
-- - 4 parallel threads (configurable)
-- - Exponential backoff on rate limit errors
-- - Skips UNKNOWN categories
--
-- Parameters:
--   P_BATCH_SIZE: Number of items to process per call (default 100)
--   P_MAX_BATCHES: Maximum batches to run (NULL = all items)
--
-- Returns: Summary of backfill operation
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.BACKFILL_MATCH_CANDIDATES(
    P_BATCH_SIZE INT DEFAULT 100,
    P_MAX_BATCHES INT DEFAULT NULL
)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
COMMENT = 'Backfill MATCH_CANDIDATES for items with Cortex Search scores but no saved candidates.'
EXECUTE AS OWNER
AS
$$
import json
import uuid
import time
import random
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from typing import List, Dict, Any, Optional

# Rate limiting constants (same as MATCH_CORTEX_SEARCH_BATCH)
MAX_RETRIES = 3
BASE_DELAY_SECONDS = 0.5
MAX_DELAY_SECONDS = 8.0
JITTER_FACTOR = 0.3
DEFAULT_PARALLEL_THREADS = 4

def escape_sql_string(s: str) -> str:
    """Safely escape a string for SQL insertion."""
    if s is None:
        return ""
    return s.replace("\\", "\\\\").replace("'", "''")

def calculate_backoff(attempt: int) -> float:
    """Calculate exponential backoff with jitter."""
    delay = min(BASE_DELAY_SECONDS * (2 ** attempt), MAX_DELAY_SECONDS)
    jitter = delay * JITTER_FACTOR * random.random()
    return delay + jitter

def is_rate_limit_error(error_str: str) -> bool:
    """Check if error is a rate limit that should trigger retry."""
    rate_limit_indicators = [
        "rate limit", "429", "399129", "too many requests",
        "throttl", "Service rate limit exceeded"
    ]
    error_lower = error_str.lower()
    return any(indicator.lower() in error_lower for indicator in rate_limit_indicators)

def search_for_candidates(session, item: Dict, db: str) -> Dict[str, Any]:
    """
    Execute Cortex Search to get candidates for an item.
    Returns candidates list for insertion into MATCH_CANDIDATES.
    """
    item_id = item["RAW_ITEM_ID"]
    raw_desc = item["RAW_DESCRIPTION"]
    category = item["INFERRED_CATEGORY"]
    
    result = {
        "item_id": item_id,
        "candidates": [],
        "error": None,
        "skipped": False,
        "retries": 0
    }
    
    # Skip items with UNKNOWN or NULL category
    if not category or category.upper() in ("UNKNOWN", "NULL", "NONE", ""):
        result["skipped"] = True
        return result
    
    last_error = None
    for attempt in range(MAX_RETRIES):
        try:
            safe_desc_json = raw_desc.replace("\\", "\\\\").replace('"', '\\"').replace("'", "''")
            safe_cat_json = category.replace("\\", "\\\\").replace('"', '\\"')
            query_json = (
                '{'
                f'"query": "{safe_desc_json}",'
                '"columns": ["STANDARD_ITEM_ID", "STANDARD_DESCRIPTION", "CATEGORY", "BRAND", "SRP"],'
                f'"filter": {{"@eq": {{"CATEGORY": "{safe_cat_json}"}}}},'
                '"limit": 5'
                '}'
            )
            
            results = session.sql(f"""
                SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                    'HARMONIZER_DEMO.HARMONIZED.STANDARD_ITEM_SEARCH',
                    '{query_json}'
                ) AS results
            """).collect()
            
            if results and results[0]["RESULTS"]:
                search_results = json.loads(results[0]["RESULTS"]) if isinstance(results[0]["RESULTS"], str) else results[0]["RESULTS"]
                if "results" in search_results and search_results["results"]:
                    for rank, cand in enumerate(search_results["results"]):
                        cand_scores = cand.get("@scores", {})
                        cand_cosine = cand_scores.get("cosine_similarity", 0)
                        result["candidates"].append({
                            "id": cand.get("STANDARD_ITEM_ID", ""),
                            "desc": cand.get("STANDARD_DESCRIPTION", "")[:500],
                            "score": (cand_cosine + 1) / 2 if cand_cosine else 0.5,
                            "rank": rank + 1
                        })
            
            result["retries"] = attempt
            return result
                    
        except Exception as e:
            last_error = str(e)[:200]
            result["retries"] = attempt + 1
            
            if is_rate_limit_error(last_error) and attempt < MAX_RETRIES - 1:
                time.sleep(calculate_backoff(attempt))
                continue
            else:
                break
    
    result["error"] = last_error
    return result

def run(session, p_batch_size: int = 100, p_max_batches: int = None) -> Dict[str, Any]:
    """
    Backfill MATCH_CANDIDATES for items that have Cortex Search scores
    but no saved candidates.
    """
    db = "HARMONIZER_DEMO"
    CHUNK_SIZE = 100
    
    # Get parallelism config
    try:
        config = session.sql(f"""
            SELECT CONFIG_VALUE FROM {db}.ANALYTICS.CONFIG 
            WHERE CONFIG_KEY = 'CORTEX_PARALLEL_THREADS'
        """).collect()
        parallel_threads = int(config[0]["CONFIG_VALUE"]) if config else DEFAULT_PARALLEL_THREADS
    except:
        parallel_threads = DEFAULT_PARALLEL_THREADS
    parallel_threads = max(1, min(parallel_threads, 6))  # Clamp 1-6 for rate limit safety
    
    # Count total items needing backfill
    total_count_result = session.sql(f"""
        SELECT COUNT(*) AS cnt
        FROM {db}.HARMONIZED.ITEM_MATCHES im
        JOIN {db}.RAW.RAW_RETAIL_ITEMS ri ON im.RAW_ITEM_ID = ri.ITEM_ID
        WHERE im.CORTEX_SEARCH_SCORE IS NOT NULL
          AND im.CORTEX_SEARCH_SCORE > 0
          AND NOT EXISTS (
              SELECT 1 FROM {db}.HARMONIZED.MATCH_CANDIDATES mc
              WHERE mc.RAW_ITEM_ID = im.RAW_ITEM_ID
          )
          AND ri.INFERRED_CATEGORY IS NOT NULL
          AND UPPER(ri.INFERRED_CATEGORY) NOT IN ('UNKNOWN', 'NULL', 'NONE', '')
    """).collect()
    total_needing_backfill = total_count_result[0]["CNT"] if total_count_result else 0
    
    if total_needing_backfill == 0:
        return {
            "status": "complete",
            "message": "No items need backfill",
            "total_needing_backfill": 0,
            "batches_processed": 0,
            "candidates_inserted": 0
        }
    
    # Calculate batches
    max_batches = p_max_batches if p_max_batches else (total_needing_backfill // p_batch_size) + 1
    
    total_candidates_inserted = 0
    total_items_processed = 0
    total_errors = 0
    total_skipped = 0
    batches_processed = 0
    all_errors: List[str] = []
    
    for batch_num in range(max_batches):
        # Get batch of items needing backfill
        items = session.sql(f"""
            SELECT im.RAW_ITEM_ID, ri.RAW_DESCRIPTION, ri.INFERRED_CATEGORY
            FROM {db}.HARMONIZED.ITEM_MATCHES im
            JOIN {db}.RAW.RAW_RETAIL_ITEMS ri ON im.RAW_ITEM_ID = ri.ITEM_ID
            WHERE im.CORTEX_SEARCH_SCORE IS NOT NULL
              AND im.CORTEX_SEARCH_SCORE > 0
              AND NOT EXISTS (
                  SELECT 1 FROM {db}.HARMONIZED.MATCH_CANDIDATES mc
                  WHERE mc.RAW_ITEM_ID = im.RAW_ITEM_ID
              )
              AND ri.INFERRED_CATEGORY IS NOT NULL
              AND UPPER(ri.INFERRED_CATEGORY) NOT IN ('UNKNOWN', 'NULL', 'NONE', '')
            LIMIT {p_batch_size}
        """).collect()
        
        if not items:
            break
        
        # Process batch with parallel threads
        all_results: List[Dict] = []
        
        with ThreadPoolExecutor(max_workers=parallel_threads) as executor:
            future_to_item = {
                executor.submit(search_for_candidates, session, item, db): item 
                for item in items
            }
            
            for future in as_completed(future_to_item):
                try:
                    result = future.result()
                    all_results.append(result)
                    if result.get("error"):
                        all_errors.append(f"{result['item_id']}: {result['error']}")
                except Exception as e:
                    item = future_to_item[future]
                    all_errors.append(f"{item['RAW_ITEM_ID']}: {str(e)[:100]}")
        
        # Collect candidates for bulk insert
        candidates_values: List[str] = []
        
        for result in all_results:
            if result.get("skipped"):
                total_skipped += 1
                continue
            if result.get("error"):
                total_errors += 1
                continue
                
            item_id = result["item_id"]
            safe_item_id = escape_sql_string(item_id)
            
            for cand in result.get("candidates", []):
                cand_uuid = str(uuid.uuid4())
                cand_id = escape_sql_string(cand["id"])
                cand_desc = escape_sql_string(cand["desc"])
                # Column order: CANDIDATE_ID, RAW_ITEM_ID, STANDARD_ITEM_ID, STANDARD_DESCRIPTION, RANK, CONFIDENCE_SCORE, MATCH_METHOD
                candidates_values.append(
                    f"('{cand_uuid}', '{safe_item_id}', '{cand_id}', "
                    f"'{cand_desc}', {cand['rank']}, {cand['score']:.6f}, 'CORTEX_SEARCH')"
                )
        
        # Bulk insert candidates
        if candidates_values:
            try:
                session.sql(f"""
                    CREATE OR REPLACE TEMPORARY TABLE {db}.HARMONIZED.TEMP_BACKFILL_CANDIDATES (
                        CANDIDATE_ID VARCHAR(36),
                        RAW_ITEM_ID VARCHAR(50),
                        STANDARD_ITEM_ID VARCHAR(50),
                        STANDARD_DESCRIPTION VARCHAR(500),
                        RANK INT,
                        CONFIDENCE_SCORE FLOAT,
                        MATCH_METHOD VARCHAR(50)
                    )
                """).collect()
                
                for i in range(0, len(candidates_values), CHUNK_SIZE):
                    chunk = candidates_values[i:i+CHUNK_SIZE]
                    values_sql = ",\n".join(chunk)
                    session.sql(f"""
                        INSERT INTO {db}.HARMONIZED.TEMP_BACKFILL_CANDIDATES
                            (CANDIDATE_ID, RAW_ITEM_ID, STANDARD_ITEM_ID, STANDARD_DESCRIPTION, 
                             RANK, CONFIDENCE_SCORE, MATCH_METHOD)
                        VALUES {values_sql}
                    """).collect()
                
                session.sql(f"""
                    MERGE INTO {db}.HARMONIZED.MATCH_CANDIDATES tgt
                    USING {db}.HARMONIZED.TEMP_BACKFILL_CANDIDATES src
                    ON tgt.RAW_ITEM_ID = src.RAW_ITEM_ID 
                       AND tgt.STANDARD_ITEM_ID = src.STANDARD_ITEM_ID
                    WHEN NOT MATCHED THEN INSERT
                        (CANDIDATE_ID, RAW_ITEM_ID, STANDARD_ITEM_ID, STANDARD_DESCRIPTION,
                         RANK, CONFIDENCE_SCORE, MATCH_METHOD)
                    VALUES
                        (src.CANDIDATE_ID, src.RAW_ITEM_ID, src.STANDARD_ITEM_ID, src.STANDARD_DESCRIPTION,
                         src.RANK, src.CONFIDENCE_SCORE, src.MATCH_METHOD)
                """).collect()
                
                total_candidates_inserted += len(candidates_values)
                session.sql(f"DROP TABLE IF EXISTS {db}.HARMONIZED.TEMP_BACKFILL_CANDIDATES").collect()
                
            except Exception as e:
                all_errors.append(f"Batch {batch_num} insert failed: {str(e)[:100]}")
        
        total_items_processed += len(items)
        batches_processed += 1
    
    return {
        "status": "complete",
        "total_needing_backfill": total_needing_backfill,
        "batches_processed": batches_processed,
        "items_processed": total_items_processed,
        "candidates_inserted": total_candidates_inserted,
        "skipped_unknown_category": total_skipped,
        "errors": total_errors,
        "parallel_threads": parallel_threads,
        "sample_errors": all_errors[:5]
    }
$$;


-- ============================================================================
-- MATCH_COSINE_BATCH: Cosine similarity matching
-- Runs in parallel with MATCH_CORTEX_SEARCH_BATCH and MATCH_EDIT_BATCH
-- Writes results to COSINE_MATCH_STAGING (no locking conflicts)
-- Uses TASK_COORDINATION table for status tracking
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.MATCH_COSINE_BATCH(
    P_BATCH_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Cosine similarity matching for batch. Writes to COSINE_MATCH_STAGING. Uses coordination table.'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_matched INTEGER DEFAULT 0;
    v_start_time TIMESTAMP_NTZ;
    v_run_id VARCHAR;
    v_parent_status VARIANT;
BEGIN
    v_start_time := CURRENT_TIMESTAMP();
    
    -- Get run_id from parent task (VECTOR_PREP)
    v_run_id := HARMONIZER_DEMO.HARMONIZED.GET_LATEST_RUN_ID('VECTOR_PREP');
    IF (v_run_id IS NULL) THEN
        v_run_id := UUID_STRING();
    END IF;
    
    -- Check parent task status - skip if parent skipped/failed
    v_parent_status := HARMONIZER_DEMO.HARMONIZED.GET_PARENT_TASK_STATUS('VECTOR_PREP', 10);
    IF (v_parent_status IS NOT NULL AND v_parent_status:status::VARCHAR IN ('SKIPPED', 'FAILED')) THEN
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'COSINE_MATCH', 'SKIPPED',
            OBJECT_CONSTRUCT('reason', 'Parent task VECTOR_PREP was ' || v_parent_status:status::VARCHAR)
        );
        RETURN OBJECT_CONSTRUCT(
            'batch_id', :P_BATCH_ID,
            'run_id', :v_run_id,
            'status', 'skipped',
            'reason', 'Parent task was ' || v_parent_status:status::VARCHAR
        );
    END IF;
    
    -- Register task start in coordination table
    CALL HARMONIZER_DEMO.HARMONIZED.REGISTER_TASK_START(:v_run_id, 'COSINE_MATCH');
    
    -- Log STARTED for telemetry
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :P_BATCH_ID, 'MATCH_COSINE_BATCH', 'STARTED', 0, 0, 0, :v_start_time
    );
    
    -- Insert best cosine match for each unique description into staging
    -- BATCH_ITEMS.ITEM_ID = UNIQUE_DESC_ID; staging RAW_ITEM_ID stores UNIQUE_DESC_ID
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_STAGING
        (RAW_ITEM_ID, BATCH_ID, COSINE_MATCHED_ID, COSINE_SCORE, COSINE_REASONING, PROCESSED_AT)
    WITH ranked_matches AS (
        SELECT
            bi.ITEM_ID AS RAW_ITEM_ID,
            se.STANDARD_ITEM_ID,
            si.STANDARD_DESCRIPTION,
            VECTOR_COSINE_SIMILARITY(ude.EMBEDDING, se.EMBEDDING) AS cosine_score,
            ROW_NUMBER() OVER (
                PARTITION BY bi.ITEM_ID 
                ORDER BY VECTOR_COSINE_SIMILARITY(ude.EMBEDDING, se.EMBEDDING) DESC
            ) AS rn
        FROM HARMONIZER_DEMO.HARMONIZED.BATCH_ITEMS bi
        JOIN HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESC_EMBEDDINGS ude ON bi.ITEM_ID = ude.UNIQUE_DESC_ID
        JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS si ON si.CATEGORY = bi.INFERRED_CATEGORY
        JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS_EMBEDDINGS se ON si.STANDARD_ITEM_ID = se.STANDARD_ITEM_ID
        WHERE NOT EXISTS (
            SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_STAGING cms
            WHERE cms.RAW_ITEM_ID = bi.ITEM_ID
        )
    )
    SELECT 
        RAW_ITEM_ID,
        :P_BATCH_ID,
        STANDARD_ITEM_ID,
        cosine_score,
        'Cosine similarity match to ' || LEFT(STANDARD_DESCRIPTION, 100),
        CURRENT_TIMESTAMP()
    FROM ranked_matches
    WHERE rn = 1;
    
    v_matched := SQLROWCOUNT;
    
    -- Log COMPLETED for telemetry
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :P_BATCH_ID, 'MATCH_COSINE_BATCH', 'COMPLETED', :v_matched, 0, 0, :v_start_time
    );
    
    -- Update coordination table with COMPLETED status
    CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
        :v_run_id, 'COSINE_MATCH', 'COMPLETED',
        OBJECT_CONSTRUCT('batch_id', :P_BATCH_ID, 'matched', :v_matched)
    );
    
    RETURN OBJECT_CONSTRUCT(
        'batch_id', :P_BATCH_ID,
        'run_id', :v_run_id,
        'status', 'complete',
        'matched', :v_matched
    );
EXCEPTION
    WHEN OTHER THEN
        LET err_msg VARCHAR := SQLERRM;
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'COSINE_MATCH', 'FAILED',
            OBJECT_CONSTRUCT('error', :err_msg)
        );
        RETURN OBJECT_CONSTRUCT(
            'batch_id', :P_BATCH_ID,
            'run_id', :v_run_id,
            'status', 'error',
            'error', :err_msg
        );
END;
$$;


-- ============================================================================
-- MATCH_EDIT_BATCH: Edit distance (Levenshtein) matching
-- Runs in parallel with MATCH_CORTEX_SEARCH_BATCH and MATCH_COSINE_BATCH
-- Writes results to EDIT_MATCH_STAGING (no locking conflicts)
-- Uses TASK_COORDINATION table for status tracking
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.MATCH_EDIT_BATCH(
    P_BATCH_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Edit distance matching for batch. Writes to EDIT_MATCH_STAGING. Uses coordination table.'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_matched INTEGER DEFAULT 0;
    v_start_time TIMESTAMP_NTZ;
    v_run_id VARCHAR;
    v_parent_status VARIANT;
BEGIN
    v_start_time := CURRENT_TIMESTAMP();
    
    -- Get run_id from parent task (VECTOR_PREP)
    v_run_id := HARMONIZER_DEMO.HARMONIZED.GET_LATEST_RUN_ID('VECTOR_PREP');
    IF (v_run_id IS NULL) THEN
        v_run_id := UUID_STRING();
    END IF;
    
    -- Check parent task status - skip if parent skipped/failed
    v_parent_status := HARMONIZER_DEMO.HARMONIZED.GET_PARENT_TASK_STATUS('VECTOR_PREP', 10);
    IF (v_parent_status IS NOT NULL AND v_parent_status:status::VARCHAR IN ('SKIPPED', 'FAILED')) THEN
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'EDIT_MATCH', 'SKIPPED',
            OBJECT_CONSTRUCT('reason', 'Parent task VECTOR_PREP was ' || v_parent_status:status::VARCHAR)
        );
        RETURN OBJECT_CONSTRUCT(
            'batch_id', :P_BATCH_ID,
            'run_id', :v_run_id,
            'status', 'skipped',
            'reason', 'Parent task was ' || v_parent_status:status::VARCHAR
        );
    END IF;
    
    -- Register task start in coordination table
    CALL HARMONIZER_DEMO.HARMONIZED.REGISTER_TASK_START(:v_run_id, 'EDIT_MATCH');
    
    -- Log STARTED for telemetry
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :P_BATCH_ID, 'MATCH_EDIT_BATCH', 'STARTED', 0, 0, 0, :v_start_time
    );
    
    -- Insert best edit distance match for each unique description into staging
    -- BATCH_ITEMS.ITEM_ID = UNIQUE_DESC_ID; uses NORMALIZED_DESCRIPTION for matching
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_STAGING
        (RAW_ITEM_ID, BATCH_ID, EDIT_MATCHED_ID, EDIT_SCORE, EDIT_REASONING, PROCESSED_AT)
    WITH ranked_matches AS (
        SELECT
            bi.ITEM_ID AS RAW_ITEM_ID,
            si.STANDARD_ITEM_ID,
            si.STANDARD_DESCRIPTION,
            HARMONIZER_DEMO.HARMONIZED.EDIT_DISTANCE_SCORE(bi.RAW_DESCRIPTION, si.STANDARD_DESCRIPTION) AS edit_score,
            ROW_NUMBER() OVER (
                PARTITION BY bi.ITEM_ID 
                ORDER BY HARMONIZER_DEMO.HARMONIZED.EDIT_DISTANCE_SCORE(bi.RAW_DESCRIPTION, si.STANDARD_DESCRIPTION) DESC
            ) AS rn
        FROM HARMONIZER_DEMO.HARMONIZED.BATCH_ITEMS bi
        JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS si ON si.CATEGORY = bi.INFERRED_CATEGORY
        WHERE NOT EXISTS (
            SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_STAGING ems
            WHERE ems.RAW_ITEM_ID = bi.ITEM_ID
        )
    )
    SELECT 
        RAW_ITEM_ID,
        :P_BATCH_ID,
        STANDARD_ITEM_ID,
        edit_score,
        'Edit distance match to ' || LEFT(STANDARD_DESCRIPTION, 100),
        CURRENT_TIMESTAMP()
    FROM ranked_matches
    WHERE rn = 1;
    
    v_matched := SQLROWCOUNT;
    
    -- Log COMPLETED for telemetry
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :P_BATCH_ID, 'MATCH_EDIT_BATCH', 'COMPLETED', :v_matched, 0, 0, :v_start_time
    );
    
    -- Update coordination table with COMPLETED status
    CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
        :v_run_id, 'EDIT_MATCH', 'COMPLETED',
        OBJECT_CONSTRUCT('batch_id', :P_BATCH_ID, 'matched', :v_matched)
    );
    
    RETURN OBJECT_CONSTRUCT(
        'batch_id', :P_BATCH_ID,
        'run_id', :v_run_id,
        'status', 'complete',
        'matched', :v_matched
    );
EXCEPTION
    WHEN OTHER THEN
        LET err_msg VARCHAR := SQLERRM;
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'EDIT_MATCH', 'FAILED',
            OBJECT_CONSTRUCT('error', :err_msg)
        );
        RETURN OBJECT_CONSTRUCT(
            'batch_id', :P_BATCH_ID,
            'run_id', :v_run_id,
            'status', 'error',
            'error', :err_msg
        );
END;
$$;


-- ============================================================================
-- GET_LATEST_BATCH_ID: Helper function for Task DAG
-- Returns the most recent batch_id from any staging table
-- Used by sibling tasks to know which batch to process
-- ============================================================================
CREATE OR REPLACE FUNCTION HARMONIZER_DEMO.HARMONIZED.GET_LATEST_BATCH_ID()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT BATCH_ID 
    FROM (
        SELECT BATCH_ID, PROCESSED_AT FROM HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_STAGING
        UNION ALL
        SELECT BATCH_ID, PROCESSED_AT FROM HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_STAGING
        UNION ALL
        SELECT BATCH_ID, PROCESSED_AT FROM HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_STAGING
        UNION ALL
        SELECT BATCH_ID, PROCESSED_AT FROM HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_STAGING
    )
    ORDER BY PROCESSED_AT DESC
    LIMIT 1
$$;


-- ============================================================================
-- JACCARD_SCORE: Token-based similarity function (Phase 2)
-- ============================================================================
-- Returns Jaccard similarity: |intersection| / |union| of word tokens
-- Catches word-level matches that embeddings/edit distance miss
-- Example: "COKE ZERO 20OZ" vs "ZERO COKE 20 OZ" → high Jaccard despite word order
-- FIX: Uses JavaScript UDF instead of SQL subquery to avoid "Unsupported subquery type" error
CREATE OR REPLACE FUNCTION HARMONIZER_DEMO.HARMONIZED.JACCARD_SCORE(STR1 VARCHAR, STR2 VARCHAR)
RETURNS FLOAT
LANGUAGE JAVASCRIPT
IMMUTABLE
COMMENT = 'Returns Jaccard token similarity (intersection/union of word sets)'
AS
$$
    if (STR1 == null || STR2 == null) return 0.0;
    var s1 = STR1.trim(), s2 = STR2.trim();
    if (s1.length === 0 || s2.length === 0) return 0.0;
    
    // Tokenize: uppercase, remove non-alphanumeric, split on space
    var tokens1 = new Set(s1.toUpperCase().replace(/[^A-Za-z0-9 ]/g, ' ').split(/\s+/).filter(t => t.length > 0));
    var tokens2 = new Set(s2.toUpperCase().replace(/[^A-Za-z0-9 ]/g, ' ').split(/\s+/).filter(t => t.length > 0));
    
    // Intersection
    var intersection = new Set([...tokens1].filter(x => tokens2.has(x)));
    var intersectionSize = intersection.size;
    
    // Union = |A| + |B| - |intersection|
    var unionSize = tokens1.size + tokens2.size - intersectionSize;
    
    return unionSize === 0 ? 0.0 : intersectionSize / unionSize;
$$;


-- ============================================================================
-- MATCH_JACCARD_BATCH: Jaccard token similarity matching (Phase 2)
-- Runs in parallel with other matching methods
-- Writes results to JACCARD_MATCH_STAGING (no locking conflicts)
-- Uses TASK_COORDINATION table for status tracking
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.MATCH_JACCARD_BATCH(
    P_BATCH_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Jaccard token similarity matching for batch. Writes to JACCARD_MATCH_STAGING. Uses coordination table.'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_matched INTEGER DEFAULT 0;
    v_batch_size INTEGER DEFAULT 500;
    v_start_time TIMESTAMP_NTZ;
    v_run_id VARCHAR;
    v_parent_status VARIANT;
BEGIN
    v_start_time := CURRENT_TIMESTAMP();
    
    -- Get run_id from parent task (VECTOR_PREP)
    v_run_id := HARMONIZER_DEMO.HARMONIZED.GET_LATEST_RUN_ID('VECTOR_PREP');
    IF (v_run_id IS NULL) THEN
        v_run_id := UUID_STRING();
    END IF;
    
    -- Check parent task status - skip if parent skipped/failed
    v_parent_status := HARMONIZER_DEMO.HARMONIZED.GET_PARENT_TASK_STATUS('VECTOR_PREP', 10);
    IF (v_parent_status IS NOT NULL AND v_parent_status:status::VARCHAR IN ('SKIPPED', 'FAILED')) THEN
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'JACCARD_MATCH', 'SKIPPED',
            OBJECT_CONSTRUCT('reason', 'Parent task VECTOR_PREP was ' || v_parent_status:status::VARCHAR)
        );
        RETURN OBJECT_CONSTRUCT(
            'batch_id', :P_BATCH_ID,
            'run_id', :v_run_id,
            'status', 'skipped',
            'reason', 'Parent task was ' || v_parent_status:status::VARCHAR
        );
    END IF;
    
    -- Register task start in coordination table
    CALL HARMONIZER_DEMO.HARMONIZED.REGISTER_TASK_START(:v_run_id, 'JACCARD_MATCH');
    
    -- Log STARTED for telemetry
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :P_BATCH_ID, 'MATCH_JACCARD_BATCH', 'STARTED', 0, 0, 0, :v_start_time
    );
    
    -- Get batch size from config
    BEGIN
        SELECT CONFIG_VALUE::INTEGER INTO :v_batch_size
        FROM HARMONIZER_DEMO.ANALYTICS.CONFIG
        WHERE CONFIG_KEY = 'BATCH_SIZE_JACCARD' AND IS_ACTIVE = TRUE;
    EXCEPTION
        WHEN OTHER THEN
            v_batch_size := 500;
    END;

    -- Insert Jaccard matches into staging table
    -- BATCH_ITEMS.ITEM_ID = UNIQUE_DESC_ID; uses NORMALIZED_DESCRIPTION for token matching
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_STAGING
        (RAW_ITEM_ID, BATCH_ID, JACCARD_MATCHED_ID, JACCARD_SCORE, JACCARD_REASONING, PROCESSED_AT)
    WITH candidate_pairs AS (
        -- Phase 1: Get all candidate pairs from BATCH_ITEMS (unique descriptions)
        SELECT
            bi.ITEM_ID,
            bi.RAW_DESCRIPTION,
            si.STANDARD_ITEM_ID,
            si.STANDARD_DESCRIPTION
        FROM (
            SELECT bi2.ITEM_ID, bi2.RAW_DESCRIPTION, bi2.INFERRED_CATEGORY,
                   ri_rep.INFERRED_SUBCATEGORY
            FROM HARMONIZER_DEMO.HARMONIZED.BATCH_ITEMS bi2
            LEFT JOIN (
                SELECT rum.UNIQUE_DESC_ID, ri3.INFERRED_SUBCATEGORY
                FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum
                JOIN HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri3 ON ri3.ITEM_ID = rum.RAW_ITEM_ID
                QUALIFY ROW_NUMBER() OVER (PARTITION BY rum.UNIQUE_DESC_ID ORDER BY ri3.ITEM_ID) = 1
            ) ri_rep ON ri_rep.UNIQUE_DESC_ID = bi2.ITEM_ID
            WHERE bi2.INFERRED_CATEGORY IS NOT NULL
              AND UPPER(bi2.INFERRED_CATEGORY) NOT IN ('UNKNOWN', 'NULL', 'NONE', '')
              AND NOT EXISTS (
                  SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_STAGING jms
                  WHERE jms.RAW_ITEM_ID = bi2.ITEM_ID
              )
            LIMIT :v_batch_size
        ) bi
        JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS si 
            ON si.CATEGORY = bi.INFERRED_CATEGORY
    ),
    scored_pairs AS (
        -- Phase 2: Compute scores (UDF called once per pair, outside window)
        SELECT
            ITEM_ID,
            STANDARD_ITEM_ID,
            STANDARD_DESCRIPTION,
            HARMONIZER_DEMO.HARMONIZED.JACCARD_SCORE(RAW_DESCRIPTION, STANDARD_DESCRIPTION) AS score
        FROM candidate_pairs
    ),
    ranked_pairs AS (
        -- Phase 3: Rank using pre-computed score (no UDF in window function)
        -- Note: No score threshold here - always record best match even if score is low
        -- The ensemble task uses scores to weight results; filtering here blocks pipeline progress
        SELECT
            ITEM_ID,
            STANDARD_ITEM_ID,
            STANDARD_DESCRIPTION,
            score,
            ROW_NUMBER() OVER (PARTITION BY ITEM_ID ORDER BY score DESC) AS rn
        FROM scored_pairs
    )
    SELECT 
        ITEM_ID,
        :P_BATCH_ID,
        STANDARD_ITEM_ID,
        score,
        'Jaccard match: ' || LEFT(STANDARD_DESCRIPTION, 100),
        CURRENT_TIMESTAMP()
    FROM ranked_pairs
    WHERE rn = 1;

    v_matched := SQLROWCOUNT;

    -- Log COMPLETED for telemetry
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :P_BATCH_ID, 'MATCH_JACCARD_BATCH', 'COMPLETED', :v_matched, 0, 0, :v_start_time
    );

    -- Update coordination table with COMPLETED status
    CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
        :v_run_id, 'JACCARD_MATCH', 'COMPLETED',
        OBJECT_CONSTRUCT('batch_id', :P_BATCH_ID, 'matched', :v_matched)
    );

    RETURN OBJECT_CONSTRUCT(
        'batch_id', :P_BATCH_ID,
        'run_id', :v_run_id,
        'status', 'complete',
        'matched', :v_matched
    );
EXCEPTION
    WHEN OTHER THEN
        LET err_msg VARCHAR := SQLERRM;
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'JACCARD_MATCH', 'FAILED',
            OBJECT_CONSTRUCT('error', :err_msg)
        );
        RETURN OBJECT_CONSTRUCT(
            'batch_id', :P_BATCH_ID,
            'run_id', :v_run_id,
            'status', 'error',
            'error', :err_msg
        );
END;
$$;


-- ============================================================================
-- MERGE_STAGING_TO_MATCHES: Merge all staging results into ITEM_MATCHES
-- Called by ensemble task after all 3 parallel methods complete
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.MERGE_STAGING_TO_MATCHES(
    P_BATCH_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Merges staging table results into ITEM_MATCHES for ensemble scoring.'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_search_merged INTEGER DEFAULT 0;
    v_cosine_merged INTEGER DEFAULT 0;
    v_edit_merged INTEGER DEFAULT 0;
    v_jaccard_merged INTEGER DEFAULT 0;
BEGIN
    -- =========================================================================
    -- Staging rows are keyed by UNIQUE_DESC_ID (stored in RAW_ITEM_ID column).
    -- Each MERGE fans out: for every UNIQUE_DESC_ID in staging, update ITEM_MATCHES
    -- for ALL raw items that map to that unique description via RAW_TO_UNIQUE_MAP.
    -- =========================================================================

    -- Merge Cortex Search results
    MERGE INTO HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES tgt
    USING (
        SELECT rum.RAW_ITEM_ID, css.SEARCH_MATCHED_ID, css.SEARCH_SCORE, css.SEARCH_REASONING
        FROM HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_STAGING css
        JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.UNIQUE_DESC_ID = css.RAW_ITEM_ID
        WHERE css.BATCH_ID = :P_BATCH_ID
    ) src
    ON tgt.RAW_ITEM_ID = src.RAW_ITEM_ID
    WHEN MATCHED AND tgt.CORTEX_SEARCH_SCORE IS NULL THEN UPDATE SET
        SEARCH_MATCHED_ID = src.SEARCH_MATCHED_ID,
        CORTEX_SEARCH_SCORE = src.SEARCH_SCORE,
        UPDATED_AT = CURRENT_TIMESTAMP();
    
    v_search_merged := SQLROWCOUNT;
    
    -- Merge Cosine results
    MERGE INTO HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES tgt
    USING (
        SELECT rum.RAW_ITEM_ID, cms.COSINE_MATCHED_ID, cms.COSINE_SCORE, cms.COSINE_REASONING
        FROM HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_STAGING cms
        JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.UNIQUE_DESC_ID = cms.RAW_ITEM_ID
        WHERE cms.BATCH_ID = :P_BATCH_ID
    ) src
    ON tgt.RAW_ITEM_ID = src.RAW_ITEM_ID
    WHEN MATCHED AND tgt.COSINE_SCORE IS NULL THEN UPDATE SET
        COSINE_MATCHED_ID = src.COSINE_MATCHED_ID,
        COSINE_SCORE = src.COSINE_SCORE,
        UPDATED_AT = CURRENT_TIMESTAMP();
    
    v_cosine_merged := SQLROWCOUNT;
    
    -- Merge Edit Distance results
    MERGE INTO HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES tgt
    USING (
        SELECT rum.RAW_ITEM_ID, ems.EDIT_MATCHED_ID, ems.EDIT_SCORE, ems.EDIT_REASONING
        FROM HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_STAGING ems
        JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.UNIQUE_DESC_ID = ems.RAW_ITEM_ID
        WHERE ems.BATCH_ID = :P_BATCH_ID
    ) src
    ON tgt.RAW_ITEM_ID = src.RAW_ITEM_ID
    WHEN MATCHED AND tgt.EDIT_DISTANCE_SCORE IS NULL THEN UPDATE SET
        EDIT_DISTANCE_MATCHED_ID = src.EDIT_MATCHED_ID,
        EDIT_DISTANCE_SCORE = src.EDIT_SCORE,
        UPDATED_AT = CURRENT_TIMESTAMP();
    
    v_edit_merged := SQLROWCOUNT;
    
    -- Merge Jaccard results (Phase 2)
    MERGE INTO HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES tgt
    USING (
        SELECT rum.RAW_ITEM_ID, jms.JACCARD_MATCHED_ID, jms.JACCARD_SCORE, jms.JACCARD_REASONING
        FROM HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_STAGING jms
        JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.UNIQUE_DESC_ID = jms.RAW_ITEM_ID
        WHERE jms.BATCH_ID = :P_BATCH_ID
    ) src
    ON tgt.RAW_ITEM_ID = src.RAW_ITEM_ID
    WHEN MATCHED AND tgt.JACCARD_SCORE IS NULL THEN UPDATE SET
        JACCARD_MATCHED_ID = src.JACCARD_MATCHED_ID,
        JACCARD_SCORE = src.JACCARD_SCORE,
        JACCARD_REASONING = src.JACCARD_REASONING,
        UPDATED_AT = CURRENT_TIMESTAMP();
    
    v_jaccard_merged := SQLROWCOUNT;
    
    -- Clean up staging tables for this batch
    DELETE FROM HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_STAGING WHERE BATCH_ID = :P_BATCH_ID;
    DELETE FROM HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_STAGING WHERE BATCH_ID = :P_BATCH_ID;
    DELETE FROM HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_STAGING WHERE BATCH_ID = :P_BATCH_ID;
    DELETE FROM HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_STAGING WHERE BATCH_ID = :P_BATCH_ID;
    
    RETURN OBJECT_CONSTRUCT(
        'batch_id', :P_BATCH_ID,
        'status', 'complete',
        'search_merged', :v_search_merged,
        'cosine_merged', :v_cosine_merged,
        'edit_merged', :v_edit_merged,
        'jaccard_merged', :v_jaccard_merged
    );
END;
$$;


-- ============================================================================
-- Legacy compatibility: Keep GET_PENDING_CATEGORIES for any external callers
-- ============================================================================
CREATE OR REPLACE FUNCTION HARMONIZER_DEMO.HARMONIZED.GET_PENDING_CATEGORIES()
RETURNS ARRAY
LANGUAGE SQL
COMMENT = 'Legacy function - returns categories with pending items'
AS
$$
    SELECT ARRAY_AGG(DISTINCT INFERRED_CATEGORY)
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
    WHERE MATCH_STATUS = 'PENDING'
      AND INFERRED_CATEGORY IS NOT NULL
$$;
