# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-05-01

### Added

- feat(api): structured error envelope with classified Snowflake errors (13 categories: network_policy, auth_expired, permission, transient, connection, sql_compilation, etc.) using precedence-based pattern matching
- feat(api): request correlation via X-Request-ID response headers and UUID tracking middleware
- feat(api): in-memory circular log buffer (1000 entries) exposed at `/api/v2/logs/app` with level and time filtering
- feat(api): client-side error reporting endpoint at `POST /api/v2/logs/app/client-error` for centralized debugging
- feat(web): reusable `AppErrorAlert` component with envelope parsing, severity-based variants, collapsible technical details, VPN guidance, and retry buttons
- feat(web): typed `ApiError` with automatic ErrorEnvelope parsing preserving endpoint, status, request ID, category, and actions
- feat(api): credential sanitization for technical details (passwords, tokens, account names, IP addresses)
- test(api): 35-test coverage suite for error classification system — ErrorEnvelope model, AppError exception, classify_snowflake_error precedence, and sanitization against committed error message fixtures
- test(fixtures): committed Snowflake error message corpus for network_policy, auth, connection, permission, and sql error categories

### Changed

- refactor(api): `/api/v2/status` now returns structured Snowflake health with classified error envelopes instead of generic error strings
- refactor(api): `snowflake_client.test_connection` raises exceptions to surface failures instead of silently returning `False`
- refactor(api): broad exception handlers removed from `/api/v2/logs/errors` so infrastructure failures propagate to the global exception handler
- refactor(web): `FeatureErrorBoundary` and `SectionWrapper` unified on shared `AppErrorAlert` to remove duplicate error display logic
- refactor(test): system endpoint tests migrated to `create_app()` factory pattern with error classification scenario coverage (network_policy, auth_expired, object_not_found, query failure)
- refactor(test): logs and snowflake_client tests updated to match exception-propagating error envelope behavior

### Fixed

- fix(web): VPN/network-policy errors now display actionable guidance with request IDs instead of appearing as empty data or generic server errors
- fix(web): nested `<button>` hydration warning in pipeline funnel by using `asChild` on `TooltipTrigger`
- fix(web): React Router v7 future flag warnings by opting into `v7_startTransition` and `v7_relativeSplatPath`
- fix(api): deprecation warning in app log buffer by mapping `warn` level to Python logging `warning` method
- fix(test): replace `type: ignore[arg-type]` with `cast(Any, ...)` in Pydantic validation tests for type-safe invalid-input assertions

## [1.1.0] - 2026-04-03

### Added

- feat(api): reverse-proxy middleware for same-origin Vite dev serving, eliminating cross-port browser blocks
- feat(sql): Python vectorized JACCARD_SCORE UDF for faster batch token-similarity scoring
- feat(make): `make dev` target to launch API and React on a single origin

### Changed

- refactor(sql): rename original JavaScript Jaccard UDF to JACCARD_SCORE_JS

### Fixed

- fix(cli): mock `subprocess.run` in validate command tests to prevent `FileNotFoundError` in CI environments without Snowflake CLI
- Escape pipe characters in README Jaccard Similarity table row to fix broken Score Source rendering on GitHub
- Reformat agreement filter conditionals in search endpoint for consistent quote style and readability
- Correct ensemble scoring documentation: remove phantom subcategory penalty from formula, fix routing from inaccurate 3-tier to actual single-threshold logic, add majority vote and rejection path details

## [1.0.0] - 2026-03-23

### Added

- Four-method ensemble matching pipeline using Snowflake Cortex AI (Cortex Search, Cosine Similarity, Edit Distance, Jaccard Similarity) running in parallel via Task DAG
- De-duplication engine that collapses raw items to unique normalized descriptions before matching (96x cost reduction at scale)
- Confirmed-match fast-path cache that skips AI entirely for previously human-confirmed mappings
- Two-phase category/subcategory classification using AI_CLASSIFY with subcategory-filtered matching and cross-category penalties
- Configurable ensemble scoring with normalized weights, agreement multipliers (4-way/3-way/2-way), and confidence-based routing (auto-accept, review, reject)
- Human review workflow with record locking, lock auto-expiry, bulk actions, and confirm/reject propagation to duplicate items
- Accuracy testing framework with per-method and ensemble accuracy verification against labeled test sets
- React frontend with Dashboard, Pipeline, Review, Comparison, Testing, Logs, and Settings pages
- FastAPI backend with feature-organized REST API (v2), async Snowflake queries, and Pydantic response schemas
- Typer/Rich CLI for setup, teardown, pipeline control, and database management
- Cost tracking and ROI estimation with configurable credit rates and manual-process comparison
- Pipeline observability with task coordination tables, DAG run history, and telemetry logging
- Synthetic seed data across multiple venue types and source systems for demo deployment
- Runtime configuration via ANALYTICS.CONFIG table for all tunable parameters (thresholds, weights, batch sizes)
