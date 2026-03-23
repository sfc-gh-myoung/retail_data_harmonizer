-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/20_accuracy_testing/20b_accuracy_procedures.sql
-- Purpose: Test procedures for each matching method
-- Depends on: 20a_accuracy_tables.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- START_ACCURACY_TEST_JOB: Queue an accuracy test job
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.START_ACCURACY_TEST_JOB(
    P_INCLUDE_CORTEX_SEARCH BOOLEAN DEFAULT TRUE
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Queues a new accuracy test job for background execution (4-method ensemble)'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_job_id VARCHAR;
    v_active_job_id VARCHAR;
    v_total_tests INTEGER;
BEGIN
    SELECT JOB_ID INTO :v_active_job_id
    FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_JOBS
    WHERE STATUS IN ('QUEUED', 'RUNNING')
    ORDER BY QUEUED_AT DESC
    LIMIT 1;
    
    IF (v_active_job_id IS NOT NULL) THEN
        RETURN '{"status": "error", "message": "Accuracy test already running", "active_job_id": "' || :v_active_job_id || '"}';
    END IF;
    
    SELECT COUNT(*) INTO :v_total_tests
    FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET
    WHERE IS_ACTIVE = TRUE AND EXPECTED_ITEM_ID IS NOT NULL;
    
    v_job_id := UUID_STRING();
    
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_JOBS (
        JOB_ID, STATUS, INCLUDE_CORTEX_SEARCH, TOTAL_TESTS
    ) VALUES (
        :v_job_id, 'QUEUED', :P_INCLUDE_CORTEX_SEARCH, :v_total_tests
    );
    
    RETURN '{"status": "queued", "job_id": "' || :v_job_id || '", "total_tests": ' || :v_total_tests || '}';
END;
$$;

-- ============================================================================
-- UPDATE_ACCURACY_TEST_PROGRESS: Update job progress during test execution
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.UPDATE_ACCURACY_TEST_PROGRESS(
    P_JOB_ID VARCHAR,
    P_CURRENT_METHOD VARCHAR DEFAULT NULL,
    P_TESTS_COMPLETED INTEGER DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Updates accuracy test job progress for UI feedback'
EXECUTE AS OWNER
AS
$$
BEGIN
    UPDATE HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_JOBS
    SET CURRENT_METHOD = COALESCE(:P_CURRENT_METHOD, CURRENT_METHOD),
        TESTS_COMPLETED = COALESCE(:P_TESTS_COMPLETED, TESTS_COMPLETED),
        LAST_UPDATE_AT = CURRENT_TIMESTAMP()
    WHERE JOB_ID = :P_JOB_ID;
    
    RETURN 'OK';
END;
$$;

-- ============================================================================
-- GET_ACCURACY_TEST_JOB: Get currently active accuracy test job
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.GET_ACCURACY_TEST_JOB()
RETURNS TABLE (
    JOB_ID VARCHAR,
    STATUS VARCHAR,
    INCLUDE_CORTEX_SEARCH BOOLEAN,
    TOTAL_TESTS INTEGER,
    TESTS_COMPLETED INTEGER,
    CURRENT_METHOD VARCHAR,
    QUEUED_AT TIMESTAMP_NTZ,
    STARTED_AT TIMESTAMP_NTZ,
    TRIGGERED_BY VARCHAR,
    RESULT_RUN_ID VARCHAR
)
LANGUAGE SQL
COMMENT = 'Returns the currently active accuracy test job if any'
EXECUTE AS OWNER
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    res := (
        SELECT 
            JOB_ID, STATUS, INCLUDE_CORTEX_SEARCH,
            TOTAL_TESTS, TESTS_COMPLETED, CURRENT_METHOD,
            QUEUED_AT, STARTED_AT, TRIGGERED_BY, RESULT_RUN_ID
        FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_JOBS
        WHERE STATUS IN ('QUEUED', 'RUNNING')
        ORDER BY QUEUED_AT DESC
        LIMIT 1
    );
    RETURN TABLE(res);
END;
$$;

-- ============================================================================
-- Ground Truth Test Data
-- ============================================================================
-- Test cases designed to cover:
-- - EASY: Near-exact matches, minor variations
-- - MEDIUM: Common abbreviations, missing words
-- - HARD: Heavy abbreviations, ambiguous, edge cases

INSERT INTO HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET 
    (RAW_DESCRIPTION, EXPECTED_MATCH, CATEGORY, DIFFICULTY, NOTES)
VALUES
    -- ========================================
    -- EASY: Minor variations, clear matches
    -- ========================================
    ('Coca-Cola 20oz', 'Coca-Cola Classic 20oz Bottle', 'Beverages', 'EASY', 'Near-exact match'),
    ('Sprite 20oz Bottle', 'Sprite 20oz Bottle', 'Beverages', 'EASY', 'Exact match'),
    ('Mountain Dew 20oz', 'Mountain Dew 20oz Bottle', 'Beverages', 'EASY', 'Missing container type'),
    ('Pepsi 12oz Can', 'Pepsi Cola 12oz Can', 'Beverages', 'EASY', 'Missing "Cola"'),
    ('Dasani Water 16.9oz', 'Dasani Purified Water 16.9oz Bottle', 'Beverages', 'EASY', 'Simplified description'),
    ('Red Bull 8.4oz', 'Red Bull Energy Drink 8.4oz Can', 'Beverages', 'EASY', 'Missing product type'),
    ('Monster Energy 16oz', 'Monster Energy Original 16oz Can', 'Beverages', 'EASY', 'Missing variant'),
    
    -- ========================================
    -- MEDIUM: Common abbreviations
    -- ========================================
    ('CK CLA 20OZ BTL', 'Coca-Cola Classic 20oz Bottle', 'Beverages', 'MEDIUM', 'CK=Coke, CLA=Classic'),
    ('PEP 20OZ BTL', 'Pepsi Cola 20oz Bottle', 'Beverages', 'MEDIUM', 'PEP=Pepsi'),
    ('MT DEW 20OZ BTL', 'Mountain Dew 20oz Bottle', 'Beverages', 'MEDIUM', 'MT DEW=Mountain Dew'),
    ('DR PEP 20OZ', 'Dr Pepper 20oz Bottle', 'Beverages', 'MEDIUM', 'DR PEP=Dr Pepper'),
    ('SPRT 20OZ BTL', 'Sprite 20oz Bottle', 'Beverages', 'MEDIUM', 'SPRT=Sprite'),
    ('RB ENRGY 8.4Z', 'Red Bull Energy Drink 8.4oz Can', 'Beverages', 'MEDIUM', 'RB=Red Bull'),
    ('MNSTR ENRGY 16Z', 'Monster Energy Original 16oz Can', 'Beverages', 'MEDIUM', 'MNSTR=Monster'),
    ('7UP 20OZ BTL', '7UP 20oz Bottle', 'Beverages', 'MEDIUM', 'Numeric brand name'),
    ('EVIAN 16.9Z', 'Evian Natural Spring Water 16.9oz Bottle', 'Beverages', 'MEDIUM', 'Brand intact'),
    ('FIJI 16.9Z BTL', 'FIJI Natural Artesian Water 16.9oz Bottle', 'Beverages', 'MEDIUM', 'Brand intact'),
    ('MTN DEW CODE RED 20OZ', 'Mountain Dew Code Red 20oz Bottle', 'Beverages', 'MEDIUM', 'MTN=Mountain'),
    ('GATORADE FRUIT PUNCH', 'Gatorade Thirst Quencher Fruit Punch 20oz Bottle', 'Beverages', 'MEDIUM', 'Full name, no size'),
    
    -- ========================================
    -- HARD: Heavy abbreviation, ambiguous
    -- ========================================
    ('CK ZERO 20 BTL', 'Coca-Cola Zero Sugar 20oz Bottle', 'Beverages', 'HARD', 'CK ZERO vs Diet Coke'),
    ('DT CK 20OZ', 'Diet Coke 20oz Bottle', 'Beverages', 'HARD', 'DT=Diet'),
    ('DT PEP 20OZ', 'Diet Pepsi 20oz Bottle', 'Beverages', 'HARD', 'DT=Diet'),
    ('CK CHRY 20OZ BTL', 'Coca-Cola Cherry 20oz Bottle', 'Beverages', 'HARD', 'CHRY=Cherry'),
    ('FANTA ORG 20Z', 'Fanta Orange 20oz Bottle', 'Beverages', 'HARD', 'ORG=Orange'),
    ('GTRDE LMN LM 20Z', 'Gatorade Thirst Quencher Lemon Lime 20oz Bottle', 'Beverages', 'HARD', 'GTRDE=Gatorade, LMN LM=Lemon Lime'),
    ('GTRDE ZERO CHRY 20Z', 'Gatorade Zero Glacier Cherry 20oz Bottle', 'Beverages', 'HARD', 'Multiple abbreviations'),
    ('SMRT WTR 20Z', 'Smartwater Vapor Distilled Water 20oz Bottle', 'Beverages', 'HARD', 'SMRT WTR=Smartwater'),
    ('AQUA 16.9Z BTL', 'Aquafina Purified Water 16.9oz Bottle', 'Beverages', 'HARD', 'AQUA=Aquafina'),
    ('GTRDE CL BLU 20Z', 'Gatorade Thirst Quencher Cool Blue 20oz Bottle', 'Beverages', 'HARD', 'CL BLU=Cool Blue'),
    ('GTRDE ORNG 20Z', 'Gatorade Thirst Quencher Orange 20oz Bottle', 'Beverages', 'HARD', 'ORNG=Orange'),
    ('GTRDE GRP 20Z', 'Gatorade Thirst Quencher Grape 20oz Bottle', 'Beverages', 'HARD', 'GRP=Grape'),
    ('PWRDE BLUE 20Z', 'Powerade Mountain Berry Blast 20oz Bottle', 'Beverages', 'HARD', 'Color vs flavor name'),
    ('VITAMIN WATER XXX', 'Vitaminwater XXX Acai Blueberry Pomegranate 20oz Bottle', 'Beverages', 'HARD', 'Partial product name'),
    
    -- ========================================
    -- Edge cases - no size or ambiguous
    -- ========================================
    ('COKE CLASSIC', 'Coca-Cola Classic 20oz Bottle', 'Beverages', 'HARD', 'No size specified'),
    ('DIET COKE CAN', 'Diet Coke 12oz Can', 'Beverages', 'HARD', 'No size specified'),
    ('SPRITE ZERO', 'Sprite Zero Sugar 20oz Bottle', 'Beverages', 'HARD', 'No size specified'),
    ('PEPSI ZERO', 'Pepsi Zero Sugar 20oz Bottle', 'Beverages', 'HARD', 'No size specified');

-- Update test set with expected item IDs from standard items
MERGE INTO HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET t
USING HARMONIZER_DEMO.RAW.STANDARD_ITEMS s
ON LOWER(s.STANDARD_DESCRIPTION) = LOWER(t.EXPECTED_MATCH)
WHEN MATCHED THEN UPDATE SET t.EXPECTED_ITEM_ID = s.STANDARD_ITEM_ID;

-- ============================================================================
-- Accuracy Test Procedures
-- ============================================================================

-- Procedure to test Cosine Similarity accuracy
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.ANALYTICS.TEST_COSINE_ACCURACY(
    P_RUN_ID VARCHAR,
    P_PARENT_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS TABLE (METHOD VARCHAR, TOTAL_TESTS INT, TOP1_CORRECT INT, TOP1_ACCURACY FLOAT)
LANGUAGE SQL
COMMENT = 'Tests cosine similarity accuracy against ground truth test set'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_error_message VARCHAR;
    v_rows_inserted INTEGER;
    v_run_id_param VARCHAR;
    res RESULTSET;
BEGIN
    v_run_id := COALESCE(:P_PARENT_RUN_ID, :P_RUN_ID);
    v_run_id_param := :P_RUN_ID;
    v_started_at := CURRENT_TIMESTAMP();

    -- Log step start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'TEST_COSINE_ACCURACY', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    -- Run cosine similarity tests (optimized with pre-computed embeddings and category filtering)
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS 
        (TEST_ID, METHOD, TOP1_MATCH_ID, TOP1_DESCRIPTION, TOP1_SCORE, IS_CORRECT, TOP3_CONTAINS, TOP5_CONTAINS, RUN_ID)
    WITH cosine_ranked AS (
        SELECT 
            t.TEST_ID,
            t.EXPECTED_ITEM_ID,
            s.STANDARD_ITEM_ID,
            s.STANDARD_DESCRIPTION,
            VECTOR_COSINE_SIMILARITY(t.EMBEDDING, e.EMBEDDING) AS cosine_score,
            ROW_NUMBER() OVER (PARTITION BY t.TEST_ID ORDER BY 
                VECTOR_COSINE_SIMILARITY(t.EMBEDDING, e.EMBEDDING) DESC
            ) AS rank
        FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET t
        JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS s 
            ON s.CATEGORY = t.CATEGORY
        JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS_EMBEDDINGS e 
            ON e.STANDARD_ITEM_ID = s.STANDARD_ITEM_ID
        WHERE t.IS_ACTIVE = TRUE 
          AND t.EXPECTED_ITEM_ID IS NOT NULL
          AND t.EMBEDDING IS NOT NULL
    ),
    aggregated AS (
        SELECT 
            TEST_ID,
            EXPECTED_ITEM_ID,
            MAX(CASE WHEN rank = 1 THEN STANDARD_ITEM_ID END) AS top1_id,
            MAX(CASE WHEN rank = 1 THEN STANDARD_DESCRIPTION END) AS top1_desc,
            MAX(CASE WHEN rank = 1 THEN cosine_score END) AS top1_score,
            MAX(CASE WHEN rank <= 3 AND STANDARD_ITEM_ID = EXPECTED_ITEM_ID THEN 1 ELSE 0 END) AS in_top3,
            MAX(CASE WHEN rank <= 5 AND STANDARD_ITEM_ID = EXPECTED_ITEM_ID THEN 1 ELSE 0 END) AS in_top5
        FROM cosine_ranked
        WHERE rank <= 5
        GROUP BY TEST_ID, EXPECTED_ITEM_ID
    )
    SELECT 
        TEST_ID,
        'COSINE_SIMILARITY',
        top1_id,
        top1_desc,
        top1_score,
        (top1_id = EXPECTED_ITEM_ID),
        (in_top3 = 1),
        (in_top5 = 1),
        :P_RUN_ID
    FROM aggregated;

    -- Capture row count immediately after INSERT
    v_rows_inserted := SQLROWCOUNT;

    -- Log completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'TEST_COSINE_ACCURACY', 'COMPLETED',
        :v_rows_inserted, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );
    
    -- Return results using RESULTSET (avoids cursor bind variable issues)
    res := (SELECT 'COSINE_SIMILARITY' AS METHOD, COUNT(*)::INT AS TOTAL_TESTS, 
               SUM(CASE WHEN IS_CORRECT THEN 1 ELSE 0 END)::INT AS TOP1_CORRECT,
               SUM(CASE WHEN IS_CORRECT THEN 1 ELSE 0 END)::FLOAT / COUNT(*) AS TOP1_ACCURACY
        FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS
        WHERE RUN_ID = :v_run_id_param AND METHOD = 'COSINE_SIMILARITY');
    RETURN TABLE(res);
EXCEPTION
    WHEN OTHER THEN
        v_error_message := SQLERRM;
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'TEST_COSINE_ACCURACY', 'FAILED',
            0, 0, 1, :v_started_at, :v_error_message, NULL, 'SERIAL', NULL
        );
        RAISE;
END;
$$;

-- Procedure to test Cortex Search accuracy (Python required - SEARCH_PREVIEW requires literal constant arguments)
-- Note: SEARCH_PREVIEW/SEARCH functions cannot accept dynamic query values, even bind variables
-- This is a Snowflake limitation - for per-row dynamic queries, Python is required
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.ANALYTICS.TEST_CORTEX_SEARCH_ACCURACY(
    P_RUN_ID VARCHAR,
    P_PARENT_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS TABLE (METHOD VARCHAR, TOTAL_TESTS INT, TOP1_CORRECT INT, TOP1_ACCURACY FLOAT)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_cortex_search_test'
COMMENT = 'Tests Cortex Search accuracy against ground truth test set'
EXECUTE AS OWNER
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col
from datetime import datetime
import json

def run_cortex_search_test(session: snowpark.Session, p_run_id: str, p_parent_run_id: str = None) -> snowpark.DataFrame:
    effective_run_id = p_parent_run_id if p_parent_run_id else p_run_id
    started_at = datetime.now()
    rows_inserted = 0
    
    try:
        # Log start
        session.call('HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP',
            effective_run_id, 'TEST_CORTEX_SEARCH_ACCURACY', 'STARTED',
            0, 0, 0, started_at, None, None, 'SERIAL', None)
        
        # Get test cases
        test_cases = session.table('HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET').filter(
            (col('IS_ACTIVE') == True) & (col('EXPECTED_ITEM_ID').is_not_null())
        ).collect()
        
        for test in test_cases:
            test_id = test['TEST_ID']
            raw_desc = test['RAW_DESCRIPTION'] or ''
            expected_id = test['EXPECTED_ITEM_ID']
            
            try:
                # Call Cortex Search via parameterized SQL
                search_query = json.dumps({
                    "query": raw_desc, 
                    "columns": ["STANDARD_ITEM_ID", "STANDARD_DESCRIPTION"], 
                    "limit": 5
                })
                response_row = session.sql(
                    """SELECT PARSE_JSON(
                        SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                            'HARMONIZER_DEMO.HARMONIZED.STANDARD_ITEM_SEARCH',
                            ?
                        )
                    ) AS response""",
                    params=[search_query]
                ).collect()[0]
                search_response = json.loads(response_row['RESPONSE']) if response_row['RESPONSE'] else {}
                
                matches = search_response.get('results', [])
                top1_id = matches[0].get('STANDARD_ITEM_ID') if matches else None
                top1_desc = (matches[0].get('STANDARD_DESCRIPTION') or '')[:500] if matches else None
                top1_score = matches[0].get('@search_score', 0) if matches else 0
                
                is_correct = (top1_id == expected_id) if top1_id else False
                top3_ids = [m.get('STANDARD_ITEM_ID') for m in matches[:3]]
                top5_ids = [m.get('STANDARD_ITEM_ID') for m in matches[:5]]
                in_top3 = expected_id in top3_ids
                in_top5 = expected_id in top5_ids
                
                # Insert using parameterized SQL to prevent SQL injection
                session.sql(
                    """INSERT INTO HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS 
                    (TEST_ID, METHOD, TOP1_MATCH_ID, TOP1_DESCRIPTION, TOP1_SCORE, IS_CORRECT, TOP3_CONTAINS, TOP5_CONTAINS, RUN_ID)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    params=[test_id, 'CORTEX_SEARCH', top1_id, top1_desc, top1_score, is_correct, in_top3, in_top5, p_run_id]
                ).collect()
                rows_inserted += 1
                
            except Exception as e:
                error_msg = str(e)[:500]
                session.sql(
                    """INSERT INTO HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS 
                    (TEST_ID, METHOD, TOP1_MATCH_ID, TOP1_DESCRIPTION, TOP1_SCORE, IS_CORRECT, TOP3_CONTAINS, TOP5_CONTAINS, RUN_ID)
                    VALUES (?, ?, NULL, ?, 0, FALSE, FALSE, FALSE, ?)""",
                    params=[test_id, 'CORTEX_SEARCH', error_msg, p_run_id]
                ).collect()
                rows_inserted += 1
        
        # Log completion
        session.call('HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP',
            effective_run_id, 'TEST_CORTEX_SEARCH_ACCURACY', 'COMPLETED',
            rows_inserted, 0, 0, started_at, None, None, 'SERIAL', None)
        
        # Return summary
        return session.sql(f"""
            SELECT 'CORTEX_SEARCH' AS METHOD, COUNT(*)::INT AS TOTAL_TESTS,
                   SUM(CASE WHEN IS_CORRECT THEN 1 ELSE 0 END)::INT AS TOP1_CORRECT,
                   SUM(CASE WHEN IS_CORRECT THEN 1 ELSE 0 END)::FLOAT / COUNT(*) AS TOP1_ACCURACY
            FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS
            WHERE RUN_ID = '{p_run_id}' AND METHOD = 'CORTEX_SEARCH'
        """)
        
    except Exception as e:
        session.call('HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP',
            effective_run_id, 'TEST_CORTEX_SEARCH_ACCURACY', 'FAILED',
            0, 0, 1, started_at, str(e)[:1000], None, 'SERIAL', None)
        raise
$$;

-- Procedure to test Edit Distance accuracy
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.ANALYTICS.TEST_EDIT_DISTANCE_ACCURACY(
    P_RUN_ID VARCHAR,
    P_PARENT_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS TABLE (METHOD VARCHAR, TOTAL_TESTS INT, TOP1_CORRECT INT, TOP1_ACCURACY FLOAT)
LANGUAGE SQL
COMMENT = 'Tests edit distance accuracy against ground truth test set'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_error_message VARCHAR;
    v_rows_inserted INTEGER;
    v_run_id_param VARCHAR;
    res RESULTSET;
BEGIN
    v_run_id := COALESCE(:P_PARENT_RUN_ID, :P_RUN_ID);
    v_run_id_param := :P_RUN_ID;
    v_started_at := CURRENT_TIMESTAMP();
    
    -- Log step start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'TEST_EDIT_DISTANCE_ACCURACY', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );
    
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS 
        (TEST_ID, METHOD, TOP1_MATCH_ID, TOP1_DESCRIPTION, TOP1_SCORE, IS_CORRECT, TOP3_CONTAINS, TOP5_CONTAINS, RUN_ID)
    WITH edit_ranked AS (
        SELECT 
            t.TEST_ID,
            t.EXPECTED_ITEM_ID,
            s.STANDARD_ITEM_ID,
            s.STANDARD_DESCRIPTION,
            1.0 - (EDITDISTANCE(UPPER(t.RAW_DESCRIPTION), UPPER(s.STANDARD_DESCRIPTION))::FLOAT / 
                   GREATEST(LENGTH(t.RAW_DESCRIPTION), LENGTH(s.STANDARD_DESCRIPTION))) AS edit_score,
            ROW_NUMBER() OVER (PARTITION BY t.TEST_ID ORDER BY 
                EDITDISTANCE(UPPER(t.RAW_DESCRIPTION), UPPER(s.STANDARD_DESCRIPTION)) ASC
            ) AS rank
        FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET t
        JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS s 
            ON s.CATEGORY = t.CATEGORY
        WHERE t.IS_ACTIVE = TRUE AND t.EXPECTED_ITEM_ID IS NOT NULL
    ),
    aggregated AS (
        SELECT 
            TEST_ID,
            EXPECTED_ITEM_ID,
            MAX(CASE WHEN rank = 1 THEN STANDARD_ITEM_ID END) AS top1_id,
            MAX(CASE WHEN rank = 1 THEN STANDARD_DESCRIPTION END) AS top1_desc,
            MAX(CASE WHEN rank = 1 THEN edit_score END) AS top1_score,
            MAX(CASE WHEN rank <= 3 AND STANDARD_ITEM_ID = EXPECTED_ITEM_ID THEN 1 ELSE 0 END) AS in_top3,
            MAX(CASE WHEN rank <= 5 AND STANDARD_ITEM_ID = EXPECTED_ITEM_ID THEN 1 ELSE 0 END) AS in_top5
        FROM edit_ranked
        WHERE rank <= 5
        GROUP BY TEST_ID, EXPECTED_ITEM_ID
    )
    SELECT 
        TEST_ID,
        'EDIT_DISTANCE',
        top1_id,
        top1_desc,
        top1_score,
        (top1_id = EXPECTED_ITEM_ID),
        (in_top3 = 1),
        (in_top5 = 1),
        :P_RUN_ID
    FROM aggregated;
    
    -- Capture row count immediately after INSERT
    v_rows_inserted := SQLROWCOUNT;
    
    -- Log step completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'TEST_EDIT_DISTANCE_ACCURACY', 'COMPLETED',
        :v_rows_inserted, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );
    
    -- Return results using RESULTSET (avoids cursor bind variable issues)
    res := (SELECT 'EDIT_DISTANCE' AS METHOD, COUNT(*)::INT AS TOTAL_TESTS, 
               SUM(CASE WHEN IS_CORRECT THEN 1 ELSE 0 END)::INT AS TOP1_CORRECT,
               SUM(CASE WHEN IS_CORRECT THEN 1 ELSE 0 END)::FLOAT / COUNT(*) AS TOP1_ACCURACY
        FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS
        WHERE RUN_ID = :v_run_id_param AND METHOD = 'EDIT_DISTANCE');
    RETURN TABLE(res);
EXCEPTION
    WHEN OTHER THEN
        v_error_message := SQLERRM;
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'TEST_EDIT_DISTANCE_ACCURACY', 'FAILED',
            0, 0, 1, :v_started_at, :v_error_message, NULL, 'SERIAL', NULL
        );
        RAISE;
END;
$$;

-- Master procedure to run all accuracy tests (4-method ensemble)
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.ANALYTICS.RUN_ACCURACY_TESTS(
    INCLUDE_CORTEX_SEARCH BOOLEAN DEFAULT TRUE,
    P_RUN_ID VARCHAR DEFAULT NULL,
    P_JOB_ID VARCHAR DEFAULT NULL
)
RETURNS TABLE (METHOD VARCHAR, DIFFICULTY VARCHAR, TOTAL_TESTS INT, TOP1_ACCURACY FLOAT, TOP3_ACCURACY FLOAT, TOP5_ACCURACY FLOAT)
LANGUAGE SQL
COMMENT = 'Master procedure to run all accuracy tests (4-method ensemble: Cortex Search, Cosine, Edit Distance, Jaccard)'
EXECUTE AS OWNER
AS
$$
DECLARE
    run_id VARCHAR;
    v_run_id VARCHAR;
    v_job_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_error_message VARCHAR;
    v_tests_done INTEGER DEFAULT 0;
    res RESULTSET;
BEGIN
    run_id := UUID_STRING();
    v_run_id := COALESCE(:P_RUN_ID, :run_id);
    v_job_id := :P_JOB_ID;
    v_started_at := CURRENT_TIMESTAMP();
    
    -- Mark job as running if job_id provided
    IF (v_job_id IS NOT NULL) THEN
        UPDATE HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_JOBS
        SET STATUS = 'RUNNING',
            STARTED_AT = CURRENT_TIMESTAMP(),
            RESULT_RUN_ID = :run_id,
            LAST_UPDATE_AT = CURRENT_TIMESTAMP()
        WHERE JOB_ID = :v_job_id;
    END IF;
    
    -- Log step start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'RUN_ACCURACY_TESTS', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );
    
    -- Log the run
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RUNS (RUN_ID, NOTES)
    VALUES (:run_id, 'Accuracy test run (4-method ensemble)');
    
    -- Clear previous results for this run
    DELETE FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS WHERE RUN_ID = :run_id;
    
    -- Run Cortex Search tests (if enabled and service is ready)
    IF (:INCLUDE_CORTEX_SEARCH) THEN
        IF (v_job_id IS NOT NULL) THEN
            CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_ACCURACY_TEST_PROGRESS(:v_job_id, 'CORTEX_SEARCH', :v_tests_done);
        END IF;
        CALL HARMONIZER_DEMO.ANALYTICS.TEST_CORTEX_SEARCH_ACCURACY(:run_id, :v_run_id);
        v_tests_done := v_tests_done + 1;
    END IF;
    
    -- Run cosine similarity tests
    IF (v_job_id IS NOT NULL) THEN
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_ACCURACY_TEST_PROGRESS(:v_job_id, 'COSINE_SIMILARITY', :v_tests_done);
    END IF;
    CALL HARMONIZER_DEMO.ANALYTICS.TEST_COSINE_ACCURACY(:run_id, :v_run_id);
    v_tests_done := v_tests_done + 1;
    
    -- Run edit distance tests
    IF (v_job_id IS NOT NULL) THEN
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_ACCURACY_TEST_PROGRESS(:v_job_id, 'EDIT_DISTANCE', :v_tests_done);
    END IF;
    CALL HARMONIZER_DEMO.ANALYTICS.TEST_EDIT_DISTANCE_ACCURACY(:run_id, :v_run_id);
    v_tests_done := v_tests_done + 1;
    
    -- Run Jaccard similarity tests
    IF (v_job_id IS NOT NULL) THEN
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_ACCURACY_TEST_PROGRESS(:v_job_id, 'JACCARD_SIMILARITY', :v_tests_done);
    END IF;
    CALL HARMONIZER_DEMO.ANALYTICS.TEST_JACCARD_ACCURACY(:run_id, :v_run_id);
    v_tests_done := v_tests_done + 1;
    
    -- Update run summary
    UPDATE HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RUNS
    SET TOTAL_TESTS = (SELECT COUNT(DISTINCT TEST_ID) FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS WHERE RUN_ID = :run_id),
        METHODS_TESTED = (SELECT LISTAGG(DISTINCT METHOD, ', ') FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS WHERE RUN_ID = :run_id)
    WHERE RUN_ID = :run_id;
    
    -- Mark job as completed if job_id provided
    IF (v_job_id IS NOT NULL) THEN
        UPDATE HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_JOBS
        SET STATUS = 'COMPLETED',
            COMPLETED_AT = CURRENT_TIMESTAMP(),
            TESTS_COMPLETED = :v_tests_done,
            CURRENT_METHOD = 'DONE',
            LAST_UPDATE_AT = CURRENT_TIMESTAMP()
        WHERE JOB_ID = :v_job_id;
    END IF;
    
    -- Log step completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'RUN_ACCURACY_TESTS', 'COMPLETED',
        0, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );
    
    res := (
        SELECT 
            r.METHOD,
            t.DIFFICULTY,
            COUNT(*)::INT AS TOTAL_TESTS,
            ROUND(SUM(CASE WHEN r.IS_CORRECT THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 1) AS TOP1_ACCURACY,
            ROUND(SUM(CASE WHEN r.TOP3_CONTAINS THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 1) AS TOP3_ACCURACY,
            ROUND(SUM(CASE WHEN r.TOP5_CONTAINS THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 1) AS TOP5_ACCURACY
        FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS r
        JOIN HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET t ON r.TEST_ID = t.TEST_ID
        WHERE r.RUN_ID = :run_id
        GROUP BY r.METHOD, t.DIFFICULTY
        ORDER BY r.METHOD, t.DIFFICULTY
    );
    RETURN TABLE(res);
EXCEPTION
    WHEN OTHER THEN
        v_error_message := SQLERRM;
        
        -- Mark job as failed if job_id provided
        IF (v_job_id IS NOT NULL) THEN
            UPDATE HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_JOBS
            SET STATUS = 'FAILED',
                COMPLETED_AT = CURRENT_TIMESTAMP(),
                ERROR_MESSAGE = :v_error_message,
                LAST_UPDATE_AT = CURRENT_TIMESTAMP()
            WHERE JOB_ID = :v_job_id;
        END IF;
        
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'RUN_ACCURACY_TESTS', 'FAILED',
            0, 0, 1, :v_started_at, :v_error_message, NULL, 'SERIAL', NULL
        );
        RAISE;
END;
$$;

-- ============================================================================
-- Ensemble Test: Search + Cosine Combined
-- ============================================================================
-- This procedure tests how well Cortex Search and Cosine Similarity work
-- together as an ensemble. It combines both methods' rankings to produce
-- a final candidate selection.
--
-- Strategy:
-- 1. Get top-5 candidates from Cortex Search (rank-based score: 1.0, 0.9, 0.8, 0.7, 0.6)
-- 2. Get cosine similarity scores for all standard items
-- 3. Combine: ensemble_score = (search_rank_score * 0.5) + (cosine_score * 0.5)
-- 4. Select top candidate by combined score
-- ============================================================================

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.ANALYTICS.TEST_ENSEMBLE_ACCURACY(
    P_RUN_ID VARCHAR,
    P_PARENT_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS TABLE (METHOD VARCHAR, TOTAL_TESTS INT, TOP1_CORRECT INT, TOP1_ACCURACY FLOAT)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_test'
COMMENT = 'Tests ensemble (Search + Cosine) accuracy against ground truth test set'
EXECUTE AS OWNER
AS
$$
import json
from datetime import datetime
from snowflake.snowpark import Session

def run_test(session: Session, p_run_id: str, p_parent_run_id: str = None):
    v_run_id = p_parent_run_id if p_parent_run_id else p_run_id
    started_at = datetime.now()
    
    # Log step start
    try:
        session.call(
            'HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP',
            v_run_id, 'TEST_ENSEMBLE_ACCURACY', 'STARTED',
            0, 0, 0, started_at, None, None, 'SERIAL', None
        )
    except:
        pass
    
    # Get test cases
    test_cases = session.sql("""
        SELECT TEST_ID, RAW_DESCRIPTION, EXPECTED_ITEM_ID, EXPECTED_MATCH
        FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET
        WHERE IS_ACTIVE = TRUE AND EXPECTED_ITEM_ID IS NOT NULL
    """).collect()
    
    results = []
    for test in test_cases:
        test_id = test['TEST_ID']
        raw_desc = test['RAW_DESCRIPTION']
        expected_id = test['EXPECTED_ITEM_ID']
        
        # Step 1: Get Cortex Search results (top 5)
        search_candidates = {}
        try:
            search_query = json.dumps({
                "query": raw_desc,
                "columns": ["STANDARD_ITEM_ID", "STANDARD_DESCRIPTION"],
                "limit": 5
            })
            
            search_result = session.sql(
                """SELECT PARSE_JSON(
                    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                        'HARMONIZER_DEMO.HARMONIZED.STANDARD_ITEM_SEARCH',
                        ?
                    )
                ) AS result""",
                params=[search_query]
            ).collect()
            
            if search_result and search_result[0]['RESULT']:
                result_json = json.loads(search_result[0]['RESULT'])
                search_results = result_json.get('results', [])
                
                # Assign rank-based scores: rank 1 = 1.0, rank 2 = 0.9, etc.
                for rank, r in enumerate(search_results[:5], 1):
                    item_id = r['STANDARD_ITEM_ID']
                    search_candidates[item_id] = {
                        'description': r['STANDARD_DESCRIPTION'],
                        'search_rank': rank,
                        'search_score': 1.0 - (rank - 1) * 0.1  # 1.0, 0.9, 0.8, 0.7, 0.6
                    }
        except Exception as e:
            pass
        
        # Step 2: Get Cosine scores for search candidates
        if search_candidates:
            candidate_ids = list(search_candidates.keys())
            placeholders = ', '.join(['?' for _ in candidate_ids])
            
            try:
                cosine_results = session.sql(f"""
                    SELECT 
                        s.STANDARD_ITEM_ID,
                        s.STANDARD_DESCRIPTION,
                        VECTOR_COSINE_SIMILARITY(t.EMBEDDING, e.EMBEDDING) AS cosine_score
                    FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET t
                    JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS_EMBEDDINGS e 
                        ON e.STANDARD_ITEM_ID IN ({placeholders})
                    JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS s 
                        ON e.STANDARD_ITEM_ID = s.STANDARD_ITEM_ID
                    WHERE t.TEST_ID = ?
                      AND t.EMBEDDING IS NOT NULL
                """, params=candidate_ids + [test_id]).collect()
                
                for row in cosine_results:
                    item_id = row['STANDARD_ITEM_ID']
                    if item_id in search_candidates:
                        search_candidates[item_id]['cosine_score'] = float(row['COSINE_SCORE'])
            except Exception as e:
                # If cosine fails, use search_score only
                for item_id in search_candidates:
                    search_candidates[item_id]['cosine_score'] = 0.5
        
        # Step 3: Calculate ensemble score and find best candidate
        best_candidate = None
        best_score = -1
        
        for item_id, data in search_candidates.items():
            search_score = data.get('search_score', 0)
            cosine_score = data.get('cosine_score', 0.5)
            
            # Ensemble: equal weight to search rank and cosine similarity
            ensemble_score = (search_score * 0.5) + (cosine_score * 0.5)
            
            if ensemble_score > best_score:
                best_score = ensemble_score
                best_candidate = {
                    'id': item_id,
                    'description': data['description'],
                    'score': ensemble_score
                }
        
        # Step 4: Check if correct and in top-N
        if best_candidate:
            is_correct = (best_candidate['id'] == expected_id)
            
            # For top-3/top-5, re-rank all candidates by ensemble score
            sorted_candidates = sorted(
                search_candidates.items(),
                key=lambda x: (x[1].get('search_score', 0) * 0.5) + (x[1].get('cosine_score', 0.5) * 0.5),
                reverse=True
            )
            top_ids = [c[0] for c in sorted_candidates]
            in_top3 = expected_id in top_ids[:3]
            in_top5 = expected_id in top_ids[:5]
            
            results.append({
                'TEST_ID': test_id,
                'METHOD': 'ENSEMBLE',
                'TOP1_MATCH_ID': best_candidate['id'],
                'TOP1_DESCRIPTION': best_candidate['description'],
                'TOP1_SCORE': best_candidate['score'],
                'IS_CORRECT': is_correct,
                'TOP3_CONTAINS': in_top3,
                'TOP5_CONTAINS': in_top5,
                'RUN_ID': p_run_id
            })
    
    # Insert results
    if results:
        for r in results:
            session.sql(
                """INSERT INTO HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS 
                    (TEST_ID, METHOD, TOP1_MATCH_ID, TOP1_DESCRIPTION, TOP1_SCORE, 
                     IS_CORRECT, TOP3_CONTAINS, TOP5_CONTAINS, RUN_ID)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                params=[
                    r['TEST_ID'],
                    r['METHOD'],
                    r['TOP1_MATCH_ID'],
                    r['TOP1_DESCRIPTION'],
                    r['TOP1_SCORE'],
                    r['IS_CORRECT'],
                    r['TOP3_CONTAINS'],
                    r['TOP5_CONTAINS'],
                    r['RUN_ID']
                ]
            ).collect()
    
    # Log completion
    try:
        session.call(
            'HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP',
            v_run_id, 'TEST_ENSEMBLE_ACCURACY', 'COMPLETED',
            len(results), 0, 0, started_at, None, None, 'SERIAL', None
        )
    except:
        pass
    
    # Return summary
    correct_count = sum(1 for r in results if r['IS_CORRECT'])
    total_count = len(results)
    accuracy = correct_count / total_count if total_count > 0 else 0
    
    return session.create_dataframe([{
        'METHOD': 'ENSEMBLE',
        'TOTAL_TESTS': total_count,
        'TOP1_CORRECT': correct_count,
        'TOP1_ACCURACY': accuracy
    }])
$$;

-- ============================================================================
-- TEST_JACCARD_ACCURACY: Jaccard token similarity accuracy test
-- ============================================================================
-- Uses the JACCARD_SCORE UDF to compute token-based similarity:
-- Jaccard = |intersection(tokens)| / |union(tokens)|
-- Good for catching word order variations like "COKE ZERO" vs "ZERO COKE"
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.ANALYTICS.TEST_JACCARD_ACCURACY(
    P_RUN_ID VARCHAR,
    P_PARENT_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS TABLE (METHOD VARCHAR, TOTAL_TESTS INT, TOP1_CORRECT INT, TOP1_ACCURACY FLOAT)
LANGUAGE SQL
COMMENT = 'Tests Jaccard token similarity accuracy against ground truth test set'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_error_message VARCHAR;
    v_rows_inserted INTEGER;
    v_run_id_param VARCHAR;
    res RESULTSET;
BEGIN
    v_run_id := COALESCE(:P_PARENT_RUN_ID, :P_RUN_ID);
    v_run_id_param := :P_RUN_ID;
    v_started_at := CURRENT_TIMESTAMP();
    
    -- Log step start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'TEST_JACCARD_ACCURACY', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );
    
    -- Jaccard similarity using the same UDF used by the matching pipeline
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS 
        (TEST_ID, METHOD, TOP1_MATCH_ID, TOP1_DESCRIPTION, TOP1_SCORE, IS_CORRECT, TOP3_CONTAINS, TOP5_CONTAINS, RUN_ID)
    WITH jaccard_ranked AS (
        SELECT 
            t.TEST_ID,
            t.EXPECTED_ITEM_ID,
            s.STANDARD_ITEM_ID,
            s.STANDARD_DESCRIPTION,
            HARMONIZER_DEMO.HARMONIZED.JACCARD_SCORE(t.RAW_DESCRIPTION, s.STANDARD_DESCRIPTION) AS jaccard_score,
            ROW_NUMBER() OVER (PARTITION BY t.TEST_ID ORDER BY 
                HARMONIZER_DEMO.HARMONIZED.JACCARD_SCORE(t.RAW_DESCRIPTION, s.STANDARD_DESCRIPTION) DESC
            ) AS rank
        FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET t
        JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS s 
            ON s.CATEGORY = t.CATEGORY
        WHERE t.IS_ACTIVE = TRUE AND t.EXPECTED_ITEM_ID IS NOT NULL
    ),
    aggregated AS (
        SELECT 
            TEST_ID,
            EXPECTED_ITEM_ID,
            MAX(CASE WHEN rank = 1 THEN STANDARD_ITEM_ID END) AS top1_id,
            MAX(CASE WHEN rank = 1 THEN STANDARD_DESCRIPTION END) AS top1_desc,
            MAX(CASE WHEN rank = 1 THEN jaccard_score END) AS top1_score,
            MAX(CASE WHEN rank <= 3 AND STANDARD_ITEM_ID = EXPECTED_ITEM_ID THEN 1 ELSE 0 END) AS in_top3,
            MAX(CASE WHEN rank <= 5 AND STANDARD_ITEM_ID = EXPECTED_ITEM_ID THEN 1 ELSE 0 END) AS in_top5
        FROM jaccard_ranked
        WHERE rank <= 5
        GROUP BY TEST_ID, EXPECTED_ITEM_ID
    )
    SELECT 
        TEST_ID,
        'JACCARD_SIMILARITY',
        top1_id,
        top1_desc,
        top1_score,
        (top1_id = EXPECTED_ITEM_ID),
        (in_top3 = 1),
        (in_top5 = 1),
        :P_RUN_ID
    FROM aggregated;
    
    -- Capture row count immediately after INSERT
    v_rows_inserted := SQLROWCOUNT;
    
    -- Log step completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'TEST_JACCARD_ACCURACY', 'COMPLETED',
        :v_rows_inserted, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );
    
    -- Return results using RESULTSET (avoids cursor bind variable issues)
    res := (SELECT 'JACCARD_SIMILARITY' AS METHOD, COUNT(*)::INT AS TOTAL_TESTS, 
               SUM(CASE WHEN IS_CORRECT THEN 1 ELSE 0 END)::INT AS TOP1_CORRECT,
               SUM(CASE WHEN IS_CORRECT THEN 1 ELSE 0 END)::FLOAT / COUNT(*) AS TOP1_ACCURACY
        FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS
        WHERE RUN_ID = :v_run_id_param AND METHOD = 'JACCARD_SIMILARITY');
    RETURN TABLE(res);
EXCEPTION
    WHEN OTHER THEN
        v_error_message := SQLERRM;
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'TEST_JACCARD_ACCURACY', 'FAILED',
            0, 0, 1, :v_started_at, :v_error_message, NULL, 'SERIAL', NULL
        );
        RAISE;
END;
$$;

