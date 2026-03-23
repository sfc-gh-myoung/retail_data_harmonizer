"""Authentication schemas for API responses."""

from pydantic import BaseModel


class UserInfo(BaseModel):
    """User information response."""

    user: str
    environment: str
    authenticated: bool


class AuthStatus(BaseModel):
    """Authentication status response."""

    authenticated: bool
    user: str | None = None
    environment: str | None = None
