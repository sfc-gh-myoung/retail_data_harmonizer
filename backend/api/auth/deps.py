"""FastAPI dependencies for authentication.

Provides dependency injection for authentication in route handlers.
Supports both local (connection-based SSO) and SPCS (OAuth) environments.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, HTTPException, status

from .service import AuthContext, get_auth_context


async def get_current_user() -> AuthContext:
    """Dependency that returns authenticated user context.

    Works in both local (connection-based) and SPCS (OAuth) environments.
    Raises 401 if not authenticated.

    Returns:
        AuthContext with user info and environment.

    Raises:
        HTTPException: 401 if not authenticated.
    """
    ctx = get_auth_context()

    if not ctx.authenticated:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Not authenticated ({ctx.environment} environment)",
        )

    return ctx


async def get_optional_user() -> AuthContext | None:
    """Optional auth - returns None instead of 401 if not authenticated.

    Use this when you want to check auth status without requiring
    authentication.

    Returns:
        AuthContext if authenticated, None otherwise.
    """
    ctx = get_auth_context()
    return ctx if ctx.authenticated else None


# Type aliases for route injection
CurrentUserDep = Annotated[AuthContext, Depends(get_current_user)]
"""Dependency that requires authentication. Raises 401 if not authenticated."""

OptionalUserDep = Annotated[AuthContext | None, Depends(get_optional_user)]
"""Optional dependency that returns None if not authenticated."""
