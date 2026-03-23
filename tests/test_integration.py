"""Integration tests — cross-cutting consistency checks.

Validates that column names, config keys, and code consistency
are maintained across all layers (SQL → Python backend).
"""

from __future__ import annotations

from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent


# ---------------------------------------------------------------------------
# Cross-layer column name consistency
# ---------------------------------------------------------------------------


class TestCrossLayerColumnNames:
    """Verify column names match across SQL and Python API."""

    CORRECT_COLUMNS = {
        "ENSEMBLE_SCORE",
        "CORTEX_SEARCH_SCORE",
        "COSINE_SCORE",
        "LLM_SCORE",
        "RAW_ITEM_ID",
        "SUGGESTED_STANDARD_ID",
        "CONFIDENCE_SCORE",
        "MATCH_ID",
    }

    DEPRECATED = {
        "ENSEMBLE_CONFIDENCE": "ENSEMBLE_SCORE",
        "SEARCH_SCORE": "CORTEX_SEARCH_SCORE (must have CORTEX_ prefix)",
    }

    def _all_backend_python_files(self) -> list[Path]:
        return list((ROOT / "backend").rglob("*.py"))

    def test_no_ensemble_confidence_in_python(self) -> None:
        """Test that no Python file uses deprecated ENSEMBLE_CONFIDENCE column."""
        for f in self._all_backend_python_files():
            content = f.read_text()
            # Skip test files
            if "tests/" in str(f):
                continue
            assert "ENSEMBLE_CONFIDENCE" not in content, f"{f.relative_to(ROOT)}: uses deprecated ENSEMBLE_CONFIDENCE"


# ---------------------------------------------------------------------------
# File structure
# ---------------------------------------------------------------------------


@pytest.mark.integration
class TestProjectStructure:
    """Test that required project files and directories exist."""

    def test_backend_api_exists(self) -> None:
        """Test that the backend API module exists."""
        assert (ROOT / "backend" / "api" / "__init__.py").exists()

    def test_backend_services_exists(self) -> None:
        """Test that the backend services module exists."""
        assert (ROOT / "backend" / "services" / "__init__.py").exists()

    def test_dockerfile_exists(self) -> None:
        """Test that the Dockerfile exists at project root."""
        assert (ROOT / "Dockerfile").exists()

    def test_deploy_script_exists(self) -> None:
        """Test that the SPCS deploy shell script exists."""
        deploy = ROOT / "deploy_spcs.sh"
        assert deploy.exists()

    def test_deploy_script_executable(self) -> None:
        """Test that the SPCS deploy script has executable permissions."""
        import os

        deploy = ROOT / "deploy_spcs.sh"
        assert os.access(deploy, os.X_OK)

    def test_pyproject_toml_exists(self) -> None:
        """Test that pyproject.toml exists at project root."""
        assert (ROOT / "pyproject.toml").exists()

    def test_all_sql_files_present(self) -> None:
        """Verify core SQL setup files exist in sql/setup/."""
        expected = [
            "01_roles_and_warehouse.sql",
            "02_schema_and_tables.sql",
        ]
        setup_dir = ROOT / "sql" / "setup"
        for fname in expected:
            assert (setup_dir / fname).exists(), f"Missing {fname}"
