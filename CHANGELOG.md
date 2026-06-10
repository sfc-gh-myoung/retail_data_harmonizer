# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- feat(api): `POST /api/v2/settings` endpoint to persist weights, thresholds, performance, and automation settings to `ANALYTICS.CONFIG` via bulk VARIANT upsert
- feat(web): editable Settings page with persistent save bar, dirty-state detection, and toast success/error feedback on save
- feat(web): dual-handle range slider on the Thresholds card, replacing four independent threshold sliders with a single reject/accept boundary control
- feat(sql): three-band routing in `ROUTE_MATCHED_ITEMS` — configurable auto-reject band (gated by `AUTO_REJECT_ENABLED`, logged as `LOW_CONFIDENCE_AUTO`) alongside existing auto-accept and review bands
- feat(sql): seed `AUTO_REJECT_THRESHOLD`, `AUTO_ACCEPT_ENABLED`, `AUTO_REJECT_ENABLED`, `MIN_AGREEMENT_LEVEL`, and `CACHE_ENABLED` keys in `ANALYTICS.CONFIG`; default `AUTO_ACCEPT_THRESHOLD` lowered from 0.80 to 0.75
- feat(make): `make resume` and `make suspend` targets to start or stop the warehouse, pipeline tasks, and all dynamic tables in a single command
- test(api): `POST /api/v2/settings` test suite covering valid payload, threshold ordering validation, and error propagation

### Changed

- refactor(sql): `UPDATE_CONFIG` procedure signature changed from single-key `(KEY_NAME VARCHAR, KEY_VALUE VARCHAR)` to bulk-VARIANT `(P_SETTINGS VARIANT)` with MERGE-based upsert; old single-key overload dropped
- refactor(api): threshold fields normalized to fractional range `0.0–1.0` (correcting prior `0–100` schema); review band derived as `[reject, autoAccept)` from two editable boundaries; `AGENTIC_ENABLED` config key renamed to `AUTO_ACCEPT_ENABLED`
- refactor(api): settings route logic inlined into route handlers — `SettingsService` removed, replaced by `_load_config` and `_build_response` helpers
- refactor(web): `useSaveSettings` hook replaces `useUpdateSettings`, `useResetSettings`, and `useReEvaluate`; writes now use `POST /v2/settings` instead of `PATCH`
- refactor(web): `Slider` component extended to support multiple thumbs by rendering one `Thumb` per value element
- refactor(web): Settings page performance and automation inputs (batch size, parallelism, cache toggle) are now editable

### Removed

- refactor(sql): deleted `11d_stream_handlers.sql` (`MATCH_ITEMS_STREAM` single-pass alternative to Task DAG), `12_parallel_matchers.sql` (parallel staging matchers), legacy function overloads in `11b_matcher_functions.sql` (`COUNT_SIGNAL_AGREEMENT` and others), and the `COMPUTE_ENSEMBLE_WITH_NOTIFICATION` backward-compatibility wrapper; the Task DAG is now the sole pipeline path
- refactor(api): removed `services/review.py`, `services/pipeline.py`, `services/settings.py`, and `services/dashboard.py`; route handlers no longer delegate to a dedicated service layer
- refactor(api): removed legacy aggregated `GET /comparison` endpoint; individual sub-endpoints (`/agreement`, `/source-performance`, `/method-accuracy`) remain
- refactor(web): removed `useSkipMatch`, `useFeedback`, and `useSelectAlternative` hooks (legacy `postFormApi` form-submission mutations)
- refactor(test): deleted `tests/test_services.py` and reduced legacy coverage tests consistent with service-layer and hook removals

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
