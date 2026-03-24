# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Escape pipe characters in README Jaccard Similarity table row to fix broken Score Source rendering on GitHub
- Reformat agreement filter conditionals in search endpoint for consistent quote style and readability

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
