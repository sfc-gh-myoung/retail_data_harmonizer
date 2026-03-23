"""Backend package - API and core services."""

from backend.snowflake import SnowflakeClient, get_client

__all__ = ["get_client", "SnowflakeClient"]
