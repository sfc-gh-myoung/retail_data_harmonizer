"""Unit tests for auth API endpoints and auth service.

Covers auth endpoints, service functions, and dependencies.
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

# ---------------------------------------------------------------------------
# Auth Service Tests
# ---------------------------------------------------------------------------


class TestAuthService:
    """Test auth service functions."""

    def test_detect_environment_local(self) -> None:
        """Test detect_environment returns 'local' when no SPCS token."""
        from backend.api.auth.service import detect_environment

        with patch("backend.api.auth.service.Path") as mock_path:
            mock_path.return_value.exists.return_value = False
            assert detect_environment() == "local"

    def test_detect_environment_spcs(self) -> None:
        """Test detect_environment returns 'spcs' when token exists."""
        from backend.api.auth.service import detect_environment

        with patch("backend.api.auth.service.Path") as mock_path:
            mock_path.return_value.exists.return_value = True
            assert detect_environment() == "spcs"

    def test_get_spcs_user_no_token(self) -> None:
        """Test get_spcs_user returns None when no token."""
        from backend.api.auth.service import get_spcs_user

        with patch("backend.api.auth.service.Path") as mock_path:
            mock_path.return_value.exists.return_value = False
            assert get_spcs_user() is None

    def test_get_spcs_user_with_env_var(self) -> None:
        """Test get_spcs_user returns SNOWFLAKE_USER env var."""
        from backend.api.auth.service import get_spcs_user

        with patch("backend.api.auth.service.Path") as mock_path:
            mock_path.return_value.exists.return_value = True
            with patch.dict("os.environ", {"SNOWFLAKE_USER": "test_user"}):
                assert get_spcs_user() == "test_user"

    def test_get_spcs_user_with_host_fallback(self) -> None:
        """Test get_spcs_user falls back to host-based user."""
        from backend.api.auth.service import get_spcs_user

        with patch("backend.api.auth.service.Path") as mock_path:
            mock_path.return_value.exists.return_value = True
            with patch.dict(
                "os.environ", {"SNOWFLAKE_USER": "", "SNOWFLAKE_HOST": "account.snowflakecomputing.com"}, clear=False
            ):
                result = get_spcs_user()
                assert result == "spcs_user@account"

    def test_get_spcs_user_default_fallback(self) -> None:
        """Test get_spcs_user returns default when no env vars."""
        from backend.api.auth.service import get_spcs_user

        with patch("backend.api.auth.service.Path") as mock_path:
            mock_path.return_value.exists.return_value = True
            with patch.dict("os.environ", {"SNOWFLAKE_USER": "", "SNOWFLAKE_HOST": ""}, clear=False):
                assert get_spcs_user() == "spcs_user"

    def test_get_local_user_success(self) -> None:
        """Test get_local_user returns username from Snowflake."""
        from backend.api.auth.service import get_local_user

        mock_client = MagicMock()
        mock_client.query.return_value = [{"USERNAME": "local_user"}]

        with patch("backend.snowflake.get_client", return_value=mock_client):
            assert get_local_user() == "local_user"

    def test_get_local_user_no_client(self) -> None:
        """Test get_local_user returns None when no client."""
        from backend.api.auth.service import get_local_user

        with patch("backend.snowflake.get_client", return_value=None):
            assert get_local_user() is None

    def test_get_local_user_exception(self) -> None:
        """Test get_local_user returns None on exception."""
        from backend.api.auth.service import get_local_user

        with patch("backend.snowflake.get_client", side_effect=Exception("Connection failed")):
            assert get_local_user() is None

    def test_get_auth_context_local_authenticated(self) -> None:
        """Test get_auth_context returns authenticated local context."""
        from backend.api.auth.service import get_auth_context

        with patch("backend.api.auth.service.detect_environment", return_value="local"):
            with patch("backend.api.auth.service.get_local_user", return_value="test_user"):
                ctx = get_auth_context()
                assert ctx.user == "test_user"
                assert ctx.environment == "local"
                assert ctx.authenticated is True

    def test_get_auth_context_local_not_authenticated(self) -> None:
        """Test get_auth_context returns unauthenticated context."""
        from backend.api.auth.service import get_auth_context

        with patch("backend.api.auth.service.detect_environment", return_value="local"):
            with patch("backend.api.auth.service.get_local_user", return_value=None):
                ctx = get_auth_context()
                assert ctx.user == "unknown"
                assert ctx.environment == "local"
                assert ctx.authenticated is False

    def test_get_auth_context_spcs(self) -> None:
        """Test get_auth_context returns SPCS context."""
        from backend.api.auth.service import get_auth_context

        with patch("backend.api.auth.service.detect_environment", return_value="spcs"):
            with patch("backend.api.auth.service.get_spcs_user", return_value="spcs_user"):
                ctx = get_auth_context()
                assert ctx.user == "spcs_user"
                assert ctx.environment == "spcs"
                assert ctx.authenticated is True


# ---------------------------------------------------------------------------
# Auth Dependencies Tests
# ---------------------------------------------------------------------------


@pytest.mark.unit
class TestAuthDependencies:
    """Test auth dependency functions."""

    @pytest.mark.asyncio
    async def test_get_current_user_authenticated(self) -> None:
        """Test get_current_user returns context when authenticated."""
        from backend.api.auth.deps import get_current_user
        from backend.api.auth.service import AuthContext

        mock_ctx = AuthContext(user="test_user", environment="local", authenticated=True)

        with patch("backend.api.auth.deps.get_auth_context", return_value=mock_ctx):
            result = await get_current_user()
            assert result.user == "test_user"
            assert result.authenticated is True

    @pytest.mark.asyncio
    async def test_get_current_user_not_authenticated(self) -> None:
        """Test get_current_user raises 401 when not authenticated."""
        from fastapi import HTTPException

        from backend.api.auth.deps import get_current_user
        from backend.api.auth.service import AuthContext

        mock_ctx = AuthContext(user="unknown", environment="local", authenticated=False)

        with patch("backend.api.auth.deps.get_auth_context", return_value=mock_ctx):
            with pytest.raises(HTTPException) as exc_info:
                await get_current_user()
            assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_get_optional_user_authenticated(self) -> None:
        """Test get_optional_user returns context when authenticated."""
        from backend.api.auth.deps import get_optional_user
        from backend.api.auth.service import AuthContext

        mock_ctx = AuthContext(user="test_user", environment="local", authenticated=True)

        with patch("backend.api.auth.deps.get_auth_context", return_value=mock_ctx):
            result = await get_optional_user()
            assert result is not None
            assert result.user == "test_user"

    @pytest.mark.asyncio
    async def test_get_optional_user_not_authenticated(self) -> None:
        """Test get_optional_user returns None when not authenticated."""
        from backend.api.auth.deps import get_optional_user
        from backend.api.auth.service import AuthContext

        mock_ctx = AuthContext(user="unknown", environment="local", authenticated=False)

        with patch("backend.api.auth.deps.get_auth_context", return_value=mock_ctx):
            result = await get_optional_user()
            assert result is None


# ---------------------------------------------------------------------------
# Auth Router Tests
# ---------------------------------------------------------------------------


class TestAuthRouter:
    """Test auth API endpoints."""

    def test_get_current_user_info_authenticated(self, app_client) -> None:
        """Test GET /auth/me returns user info when authenticated."""
        from backend.api.auth.service import AuthContext

        mock_ctx = AuthContext(user="test_user", environment="local", authenticated=True)

        with patch("backend.api.auth.deps.get_auth_context", return_value=mock_ctx):
            resp = app_client.get("/auth/me")
            assert resp.status_code == 200
            data = resp.json()
            assert data["user"] == "test_user"
            assert data["environment"] == "local"
            assert data["authenticated"] is True

    def test_get_current_user_info_not_authenticated(self, app_client) -> None:
        """Test GET /auth/me returns 401 when not authenticated."""
        from backend.api.auth.service import AuthContext

        mock_ctx = AuthContext(user="unknown", environment="local", authenticated=False)

        with patch("backend.api.auth.deps.get_auth_context", return_value=mock_ctx):
            resp = app_client.get("/auth/me")
            assert resp.status_code == 401

    def test_get_auth_status_authenticated(self, app_client) -> None:
        """Test GET /auth/status returns authenticated status."""
        from backend.api.auth.service import AuthContext

        mock_ctx = AuthContext(user="test_user", environment="local", authenticated=True)

        with patch("backend.api.auth.deps.get_auth_context", return_value=mock_ctx):
            resp = app_client.get("/auth/status")
            assert resp.status_code == 200
            data = resp.json()
            assert data["authenticated"] is True
            assert data["user"] == "test_user"
            assert data["environment"] == "local"

    def test_get_auth_status_not_authenticated(self, app_client) -> None:
        """Test GET /auth/status returns unauthenticated status."""
        from backend.api.auth.service import AuthContext

        mock_ctx = AuthContext(user="unknown", environment="local", authenticated=False)

        with patch("backend.api.auth.deps.get_auth_context", return_value=mock_ctx):
            resp = app_client.get("/auth/status")
            assert resp.status_code == 200
            data = resp.json()
            assert data["authenticated"] is False
            assert data["user"] is None


# ---------------------------------------------------------------------------
# Auth Schema Tests
# ---------------------------------------------------------------------------


class TestAuthSchemas:
    """Test auth schema models."""

    def test_user_info_schema(self) -> None:
        """Test UserInfo schema."""
        from backend.api.auth.schemas import UserInfo

        info = UserInfo(user="test_user", environment="local", authenticated=True)
        assert info.user == "test_user"
        assert info.environment == "local"
        assert info.authenticated is True

    def test_auth_status_schema_authenticated(self) -> None:
        """Test AuthStatus schema when authenticated."""
        from backend.api.auth.schemas import AuthStatus

        status = AuthStatus(authenticated=True, user="test_user", environment="local")
        assert status.authenticated is True
        assert status.user == "test_user"

    def test_auth_status_schema_not_authenticated(self) -> None:
        """Test AuthStatus schema when not authenticated."""
        from backend.api.auth.schemas import AuthStatus

        status = AuthStatus(authenticated=False)
        assert status.authenticated is False
        assert status.user is None
        assert status.environment is None
