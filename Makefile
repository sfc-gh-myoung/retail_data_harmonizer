# ============================================================================
# Retail Data Harmonizer — Makefile
# ============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Auto-detect tool paths
UV := $(shell command -v uv 2>/dev/null || echo "uv")
UVX := $(shell command -v uvx 2>/dev/null || echo "uvx")
DOCKER := $(shell command -v docker 2>/dev/null || echo "docker")
SNOW := $(shell command -v snow 2>/dev/null || echo "snow")
NPM := $(shell command -v npm 2>/dev/null || echo "npm")
PROJECT_VERSION := $(shell awk -F'"' '/^version = "/ {print $$2; exit}' pyproject.toml 2>/dev/null || echo "unknown")

# React frontend directory
REACT_DIR := frontend/react

# Configurable Snowflake connection (override with CONN=myconn)
CONN ?= default

# Docker configuration
IMAGE_NAME := retail-data-harmonizer
IMAGE_TAG ?= latest

# ============================================================================
# Help
# ============================================================================

.PHONY: help
help: ## Show this help message
	@echo "════════════════════════════════════════════════════════════════════════"
	@echo "Retail Data Harmonizer v$(PROJECT_VERSION) — Development Commands"
	@echo "════════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "QUICKSTART"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make setup                     Full setup: database + pipeline + seed data"
	@echo "  make serve                     Start FastAPI web app on port 8000"
	@echo "  make test                      Run all pytest tests"
	@echo "  make validate                  Run all validation checks"
	@echo "  make teardown                  Remove all database objects"
	@echo ""
	@echo "ENVIRONMENT SETUP"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make env-sync                  Sync dev dependencies"
	@echo "  make env-deps                  Lock and sync dependencies"
	@echo "  make preflight                 Verify environment is ready"
	@echo ""
	@echo "CODE QUALITY"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make lint                      Run ruff linter (check only)"
	@echo "  make format                    Run ruff formatter (check only)"
	@echo "  make typecheck                 Run ty type checker"
	@echo "  make lint-fix                  Fix lint issues"
	@echo "  make format-fix                Fix format issues"
	@echo "  make quality-check             Run all quality checks"
	@echo "  make quality-fix               Fix all quality issues"
	@echo ""
	@echo "TESTING"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make test                      Run all pytest tests"
	@echo "  make test-cov                  Run tests with coverage report"
	@echo "  make test-cov-open             Coverage + open in browser"
	@echo ""
	@echo "DATABASE & SQL"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make setup                     Full demo setup (CONN=... optional)"
	@echo "  make teardown                  Remove all database objects (CONN=...)"
	@echo "  make db-up                     Run all SQL setup files"
	@echo "  make db-down                   Teardown database"
	@echo "  make db-verify                 Check table row counts"
	@echo "  make sql-validate FILE=...    Compile-check a SQL file"
	@echo ""
	@echo "DATA PIPELINE"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make data-run                  Enable Task DAG + trigger execution"
	@echo "  make data-stop                 Disable Task DAG"
	@echo "  make data-status               Show match status and metrics"
	@echo "  make data-reset                Reset pipeline results"
	@echo ""
	@echo "WEB APPLICATION"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make serve                     Start FastAPI on port 8000"
	@echo "  make serve-dev                 Development mode with auto-reload"
	@echo ""
	@echo "API SERVER"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make api-serve                  Start JSON API on port 8000"
	@echo "  make api-serve-dev              Development mode with auto-reload"
	@echo "  make dev                        Same-origin dev (API+React on :8000)"
	@echo ""
	@echo "REACT FRONTEND"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make react-install             Install npm dependencies"
	@echo "  make react-dev                 Start React dev server (port 5173)"
	@echo "  make react-build               Build React for production"
	@echo "  make react-lint                Run ESLint on React code"
	@echo "  make react-test                Run React/Vitest tests"
	@echo "  make react-test-cov            Run React tests with coverage"
	@echo "  make react-preview             Preview production build"
	@echo ""
	@echo "DOCKER"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make docker-build              Build all Docker images"
	@echo "  make docker-up                 Start all services (docker-compose)"
	@echo "  make docker-down               Stop all services (docker-compose)"
	@echo "  make docker-run                Build + run API container standalone"
	@echo "  make docker-push REGISTRY=... Push image to registry"
	@echo ""
	@echo "SPCS DEPLOYMENT"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make spcs-deploy               Deploy to Snowpark Container Services"
	@echo "  make spcs-status               Check SPCS service status"
	@echo "  make spcs-logs                 View SPCS service logs"
	@echo ""
	@echo "ACCURACY TESTING"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make accuracy-run              Run accuracy tests"
	@echo "  make accuracy-report           View accuracy summary"
	@echo ""
	@echo "CLEANUP"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make clean-cache               Remove Python cache files"
	@echo "  make clean-venv                Remove virtual environment"
	@echo "  make clean                     Remove all generated files"
	@echo ""
	@echo "STATUS"
	@echo "────────────────────────────────────────────────────────────────────────"
	@echo "  make status                    Show project status summary"
	@echo "════════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Snowflake connection: Use CONN=<name> to override (default: $(CONN))"
	@echo "Example: make setup CONN=myconn"

# ============================================================================
# Environment Setup
# ============================================================================

.PHONY: env-sync
env-sync: ## Sync dev dependencies
	$(UV) sync --all-groups

.PHONY: env-deps
env-deps: ## Lock and sync dependencies
	$(UV) lock
	$(UV) sync --all-groups

.PHONY: preflight
preflight: ## Verify environment is ready
	@command -v $(UV) >/dev/null 2>&1 || { echo "ERROR: uv not found. Install: https://docs.astral.sh/uv/"; exit 1; }
	@test -f pyproject.toml || { echo "ERROR: pyproject.toml not found. Run from project root."; exit 1; }
	@command -v $(SNOW) >/dev/null 2>&1 || { echo "ERROR: snow CLI not found. Install: https://docs.snowflake.com/en/developer-guide/snowflake-cli/"; exit 1; }
	@echo "Environment ready"

# ============================================================================
# Code Quality
# ============================================================================

.PHONY: lint
lint: ## Run ruff linter (check only)
	$(UVX) ruff check .

.PHONY: format
format: ## Run ruff formatter (check only)
	$(UVX) ruff format --check .

.PHONY: lint-fix
lint-fix: ## Fix lint issues
	$(UVX) ruff check --fix .

.PHONY: format-fix
format-fix: ## Fix format issues
	$(UVX) ruff format .

.PHONY: typecheck
typecheck: ## Run ty type checker
	$(UVX) ty check .

.PHONY: quality-check
quality-check: lint format typecheck ## Run all quality checks

.PHONY: quality-fix
quality-fix: lint-fix format-fix ## Fix all quality issues

# ============================================================================
# Testing
# ============================================================================

.PHONY: test
test: ## Run all pytest tests
	$(UV) run pytest tests/ --tb=short

.PHONY: test-cov
test-cov: ## Run tests with coverage report
	$(UV) run pytest --cov=backend --cov=cli --cov-report=term-missing --cov-report=html tests/

.PHONY: test-cov-open
test-cov-open: test-cov ## Coverage + open in browser
	@if [ "$$(uname)" = "Darwin" ]; then \
		open htmlcov/index.html; \
	elif [ "$$(uname)" = "Linux" ]; then \
		xdg-open htmlcov/index.html; \
	else \
		echo "Coverage report generated at htmlcov/index.html"; \
	fi

# ============================================================================
# Database & SQL
# ============================================================================

.PHONY: setup
setup: ## Full demo setup: database + pipeline + seed data (CONN=... optional)
	$(UV) run demo -c $(CONN) setup

.PHONY: teardown
teardown: ## Remove all database objects (CONN=... optional)
	$(UV) run demo -c $(CONN) teardown

.PHONY: db-up
db-up: ## Run all SQL setup files
	$(UV) run demo -c $(CONN) db up

.PHONY: db-down
db-down: ## Teardown database
	$(UV) run demo -c $(CONN) db down

.PHONY: db-verify
db-verify: ## Check table row counts
	$(UV) run demo -c $(CONN) db verify

.PHONY: sql-validate
sql-validate: ## Compile-check a SQL file (FILE=... required)
ifndef FILE
	$(error FILE is required. Usage: make sql-validate FILE=sql/setup/05_taxonomy.sql)
endif
	$(UV) run demo -c $(CONN) db run $(FILE)

# ============================================================================
# Data Pipeline
# ============================================================================

.PHONY: data-run
data-run: ## Enable Task DAG + trigger execution
	$(UV) run demo -c $(CONN) data run

.PHONY: data-stop
data-stop: ## Disable Task DAG
	$(UV) run demo -c $(CONN) data stop

.PHONY: data-status
data-status: ## Show match status and metrics
	$(UV) run demo -c $(CONN) data status

.PHONY: data-reset
data-reset: ## Reset pipeline results
	$(UV) run demo -c $(CONN) data reset

# ============================================================================
# Web Application
# ============================================================================

.PHONY: serve
serve: ## Start FastAPI on port 8000
	$(UV) run demo web serve

.PHONY: serve-dev
serve-dev: ## Development mode with auto-reload
	$(UV) run demo web serve --reload

# ============================================================================
# API Server
# ============================================================================

.PHONY: api-serve
api-serve: ## Start JSON API on port 8000
	$(UV) run demo api serve

.PHONY: api-serve-dev
api-serve-dev: ## Development mode with auto-reload
	$(UV) run demo api serve --reload

.PHONY: dev
dev: ## Start API + React (same-origin on port 8000, for Prisma Browser)
	@echo "Starting Vite dev server (background) and FastAPI with dev proxy..."
	@echo "Access the app at http://localhost:8000"
	@cd $(REACT_DIR) && $(NPM) run dev &
	@sleep 2
	APP_DEV_PROXY=true $(UV) run demo api serve --reload

# ============================================================================
# React Frontend (via CLI)
# ============================================================================

.PHONY: react-install
react-install: ## Install React frontend dependencies
	$(UV) run demo web react-install

.PHONY: react-dev
react-dev: ## Start React dev server on port 5173
	$(UV) run demo web react-dev

.PHONY: react-build
react-build: ## Build React frontend for production
	$(UV) run demo web react-build

.PHONY: react-lint
react-lint: ## Run ESLint on React frontend
	$(UV) run demo web react-lint

.PHONY: react-test
react-test: ## Run React/Vitest tests
	cd $(REACT_DIR) && $(NPM) run test -- --run

.PHONY: react-test-cov
react-test-cov: ## Run React tests with coverage
	cd $(REACT_DIR) && $(NPM) run test -- --run --coverage

.PHONY: react-preview
react-preview: ## Preview React production build
	$(UV) run demo web react-preview

# ============================================================================
# Docker
# ============================================================================

.PHONY: docker-build
docker-build: ## Build Docker images via docker-compose
	$(DOCKER) compose -f docker/docker-compose.yml build

.PHONY: docker-up
docker-up: ## Start all services via docker-compose
	$(DOCKER) compose -f docker/docker-compose.yml up -d

.PHONY: docker-down
docker-down: ## Stop all services via docker-compose
	$(DOCKER) compose -f docker/docker-compose.yml down

.PHONY: docker-run
docker-run: ## Run API container locally (standalone)
	$(DOCKER) build --platform linux/amd64 -f docker/Dockerfile.api -t $(IMAGE_NAME):$(IMAGE_TAG) .
	$(DOCKER) run --rm -p 8000:8000 $(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: docker-push
docker-push: ## Push image to registry (REGISTRY=... required)
ifndef REGISTRY
	$(error REGISTRY is required. Usage: make docker-push REGISTRY=myregistry.azurecr.io)
endif
	$(DOCKER) tag $(IMAGE_NAME):$(IMAGE_TAG) $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	$(DOCKER) push $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

# ============================================================================
# SPCS Deployment
# ============================================================================

.PHONY: spcs-deploy
spcs-deploy: ## Deploy to Snowpark Container Services
	SNOWFLAKE_CONNECTION=$(CONN) ./deploy_spcs.sh

.PHONY: spcs-status
spcs-status: ## Check SPCS service status
	$(SNOW) sql -c $(CONN) -q "SELECT SYSTEM\$$GET_SERVICE_STATUS('HARMONIZER_DEMO.HARMONIZED.HARMONIZER_SERVICE')"

.PHONY: spcs-logs
spcs-logs: ## View SPCS service logs
	$(SNOW) sql -c $(CONN) -q "SELECT SYSTEM\$$GET_SERVICE_LOGS('HARMONIZER_DEMO.HARMONIZED.HARMONIZER_SERVICE', 0, 'harmonizer')"

# ============================================================================
# Accuracy Testing
# ============================================================================

.PHONY: accuracy-run
accuracy-run: ## Run accuracy tests
	$(SNOW) sql -c $(CONN) -q "CALL HARMONIZER_DEMO.ANALYTICS.RUN_ACCURACY_TESTS(FALSE, TRUE)"

.PHONY: accuracy-report
accuracy-report: ## View accuracy summary
	$(SNOW) sql -c $(CONN) -q "SELECT * FROM HARMONIZER_DEMO.ANALYTICS.V_ACCURACY_SUMMARY"

# ============================================================================
# Cleanup
# ============================================================================

.PHONY: clean-cache
clean-cache: ## Remove Python cache files
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true

.PHONY: clean-venv
clean-venv: ## Remove virtual environment
	rm -rf .venv

.PHONY: clean
clean: clean-cache clean-venv ## Remove all generated files
	rm -rf htmlcov .coverage .ruff_cache

# ============================================================================
# Validation & Status
# ============================================================================

.PHONY: validate
validate: quality-check test ## Run all validation checks
	@echo "All validation checks passed!"

.PHONY: status
status: ## Show project status summary
	@echo "════════════════════════════════════════════════════════════════════════"
	@echo "Retail Data Harmonizer v$(PROJECT_VERSION) — Project Status"
	@echo "════════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Python:     $$(python3 --version 2>/dev/null || echo 'not found')"
	@echo "UV:         $$($(UV) --version 2>/dev/null || echo 'not found')"
	@echo "Docker:     $$($(DOCKER) --version 2>/dev/null || echo 'not found')"
	@echo "Snow CLI:   $$($(SNOW) --version 2>/dev/null || echo 'not found')"
	@echo "Node.js:    $$(node --version 2>/dev/null || echo 'not found')"
	@echo "npm:        $$($(NPM) --version 2>/dev/null || echo 'not found')"
	@echo "Venv:       $$(test -d .venv && echo 'present' || echo 'missing')"
	@echo "node_modules: $$(test -d $(REACT_DIR)/node_modules && echo 'present' || echo 'missing')"
	@echo ""
	@echo "Source:     $$(find cli backend -name '*.py' | wc -l | tr -d ' ') Python files"
	@echo "SQL:        $$(find sql -name '*.sql' | wc -l | tr -d ' ') SQL files"
	@echo "Tests:      $$(find tests -name 'test_*.py' | wc -l | tr -d ' ') test files"
	@echo "React:      $$(find $(REACT_DIR)/src -name '*.tsx' 2>/dev/null | wc -l | tr -d ' ') TSX components"
	@echo ""
	@echo "Connection: $(CONN)"
	@echo "════════════════════════════════════════════════════════════════════════"
