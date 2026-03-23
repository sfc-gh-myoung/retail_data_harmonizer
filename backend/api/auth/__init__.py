"""Authentication router for the Retail Data Harmonizer API.

Provides endpoints for checking authentication status and user info.
Supports dual-environment authentication (local SSO and SPCS OAuth).
"""

from __future__ import annotations

from fastapi import APIRouter

from .deps import CurrentUserDep, OptionalUserDep
from .schemas import AuthStatus, UserInfo

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/me", response_model=UserInfo)
async def get_current_user_info(ctx: CurrentUserDep) -> UserInfo:
    """Get current authenticated user info.

    Requires authentication. Returns 401 if not authenticated.

    Returns:
        UserInfo with user, environment, and authenticated status.
    """
    return UserInfo(
        user=ctx.user,
        environment=ctx.environment,
        authenticated=ctx.authenticated,
    )


@router.get("/status", response_model=AuthStatus)
async def get_auth_status(ctx: OptionalUserDep) -> AuthStatus:
    """Check authentication status without requiring authentication.

    Returns authentication status regardless of whether the user
    is authenticated. Useful for frontend to check auth state.

    Returns:
        AuthStatus with authenticated flag and optional user info.
    """
    if ctx and ctx.authenticated:
        return AuthStatus(
            authenticated=True,
            user=ctx.user,
            environment=ctx.environment,
        )
    return AuthStatus(authenticated=False)
