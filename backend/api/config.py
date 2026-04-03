"""Application configuration using Pydantic Settings.

This module provides type-safe configuration management with environment
variable support and sensible defaults.
"""

from __future__ import annotations

from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables.

    Attributes:
        app_name: Display name for the API in OpenAPI docs.
        debug: Enable debug mode (exposes /docs endpoint).
        cors_origins: Allowed CORS origins for the React frontend.
    """

    model_config = {"env_prefix": "APP_", "env_file": ".env"}

    app_name: str = "Retail Data Harmonizer"
    debug: bool = False
    cors_origins: list[str] = [
        "http://localhost:5173",
        "http://localhost:3000",
        "http://localhost:8000",
    ]
    dev_proxy: bool = False


@lru_cache
def get_settings() -> Settings:
    """Get cached application settings.

    Returns:
        Singleton Settings instance.
    """
    return Settings()
