-- ============================================================================
-- sql/utils/spcs_deploy.sql
-- Retail Data Harmonizer - Snowpark Container Services Deployment
--
-- Purpose: Deploy the Retail Data Harmonizer web application to SPCS
--          Creates compute pool, image repository, service, and endpoint
--
-- Creates:
--   - IMAGE REPOSITORY: HARMONIZED.HARMONIZER_REPO
--   - COMPUTE POOL: HARMONIZER_POOL (CPU_X64_XS, 1 node)
--   - SERVICE: HARMONIZED.HARMONIZER_SERVICE (FastAPI app)
--
-- Prerequisites:
--   - Docker image built and tagged: retail-data-harmonizer:latest
--   - Image pushed to repository (see deployment docs)
--   - Network rule/external access configured if needed
--
-- Depends on: 01_roles_and_warehouse.sql (database, schemas, role, warehouse)
--
-- Note: This is an optional deployment for web UI access.
--       Core functionality works without SPCS deployment.
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- 1. Image Repository
CREATE IMAGE REPOSITORY IF NOT EXISTS HARMONIZER_DEMO.HARMONIZED.HARMONIZER_REPO;

-- 2. Compute Pool (GPU not needed — CPU-only FastAPI service)
CREATE COMPUTE POOL IF NOT EXISTS HARMONIZER_POOL
    MIN_NODES = 1
    MAX_NODES = 1
    INSTANCE_FAMILY = CPU_X64_XS
    AUTO_RESUME = TRUE
    AUTO_SUSPEND_SECS = 300
    COMMENT = 'Retail Data Harmonizer web app';

-- 3. Service specification (inline YAML)
CREATE SERVICE IF NOT EXISTS HARMONIZER_DEMO.HARMONIZED.HARMONIZER_SERVICE
    IN COMPUTE POOL HARMONIZER_POOL
    MIN_INSTANCES = 1
    MAX_INSTANCES = 1
    EXTERNAL_ACCESS_INTEGRATIONS = ()
    QUERY_WAREHOUSE = HARMONIZER_DEMO_WH
    SPEC = $$
spec:
  containers:
    - name: harmonizer
      image: /harmonizer_demo/harmonized/harmonizer_repo/retail-data-harmonizer:latest
      env:
        SNOWFLAKE_MODE: snowpark
      resources:
        requests:
          cpu: "0.5"
          memory: 512M
        limits:
          cpu: "2"
          memory: 2G
      readinessProbe:
        port: 8000
        path: /api/health
  endpoints:
    - name: harmonizer-ui
      port: 8000
      public: true
$$;

-- 4. Grant service access
GRANT USAGE ON SERVICE HARMONIZER_DEMO.HARMONIZED.HARMONIZER_SERVICE TO ROLE HARMONIZER_DEMO_ROLE;

-- 5. Show service URL
SHOW ENDPOINTS IN SERVICE HARMONIZER_DEMO.HARMONIZED.HARMONIZER_SERVICE;

SELECT '=== SPCS Deployment Complete ===' AS status;
SELECT 'Visit the endpoint URL above to access the Harmonizer UI' AS next_step;
