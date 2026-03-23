"""Authentication service supporting local and SPCS environments.

This module provides dual-environment authentication:
- Local: Uses Snowflake connection credentials from ~/.snowflake/connections.toml
- SPCS: Uses OAuth token automatically injected at /snowflake/session/token
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from pathlib import Path

logger = logging.getLogger(__name__)


@dataclass
class AuthContext:
    """Authentication context containing user identity and environment info.

    Attributes:
        user: Snowflake username or 'unknown' if authentication failed.
        environment: Deployment environment - 'local' or 'spcs'.
        authenticated: True if user identity was successfully resolved.
    """

    user: str
    environment: str  # "local" | "spcs"
    authenticated: bool


def detect_environment() -> str:
    """Detect if running in SPCS or locally.

    Returns:
        "spcs" if running in Snowpark Container Services,
        "local" otherwise.
    """
    if Path("/snowflake/session/token").exists():
        return "spcs"
    return "local"


def get_spcs_user() -> str | None:
    """Extract user from SPCS environment.

    In SPCS, the OAuth token is pre-validated by the Snowflake platform.
    User identity is available via environment variables.

    Returns:
        Snowflake username or None if not in SPCS.
    """
    token_path = Path("/snowflake/session/token")
    if not token_path.exists():
        return None

    # SPCS injects user info via environment variables
    # The token is already validated by the platform
    user = os.environ.get("SNOWFLAKE_USER")
    if user:
        return user

    # Fallback: try to get from Snowflake host
    host = os.environ.get("SNOWFLAKE_HOST", "")
    if host:
        return f"spcs_user@{host.split('.')[0]}"

    return "spcs_user"


def get_local_user() -> str | None:
    """Get user from active Snowflake connection.

    Uses the configured Snowflake connection from
    ~/.snowflake/connections.toml to get the authenticated user.

    Returns:
        Snowflake username or None if connection fails.
    """
    try:
        from backend.snowflake import get_client

        client = get_client()
        if client is None:
            logger.warning("No Snowflake client available")
            return None

        # Execute simple query to get current user
        rows = client.query("SELECT CURRENT_USER() AS USERNAME")
        return rows[0]["USERNAME"] if rows else None
    except Exception as e:
        logger.warning(f"Failed to get local user: {e}")
        return None


def get_auth_context() -> AuthContext:
    """Get authentication context for current environment.

    Automatically detects whether running locally or in SPCS
    and returns the appropriate user context.

    Returns:
        AuthContext with user info and environment.
    """
    env = detect_environment()

    if env == "spcs":
        user = get_spcs_user()
        logger.debug(f"SPCS authentication: user={user}")
    else:
        user = get_local_user()
        logger.debug(f"Local authentication: user={user}")

    return AuthContext(
        user=user or "unknown",
        environment=env,
        authenticated=user is not None,
    )
