"""Error handling and classification for API responses.

Provides structured error envelopes, Snowflake-specific error classification,
and sanitization to prevent credential exposure.
"""

from __future__ import annotations

import logging
import re
import uuid
from typing import Literal

from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Error Envelope Models
# ---------------------------------------------------------------------------


class ErrorEnvelope(BaseModel):
    """Structured error response sent to clients.

    Provides consistent error format with classification, guidance, and
    correlation IDs for debugging.
    """

    error_id: str = Field(description="Unique identifier for this specific error occurrence")
    request_id: str = Field(description="Request correlation ID from middleware")
    category: str = Field(description="Error category for client-side classification and routing")
    severity: Literal["info", "warning", "error", "critical"] = Field(
        description="Severity level for UI rendering hints"
    )
    title: str = Field(description="Human-readable error title")
    message: str = Field(description="Detailed user-facing error message")
    actions: list[str] = Field(
        default_factory=list,
        description="Actionable remediation steps for the user",
    )
    retryable: bool = Field(default=False, description="Whether the operation can be safely retried")
    technical_details: str | None = Field(
        default=None,
        description="Sanitized technical details for debugging (no credentials)",
    )
    source: Literal["snowflake", "api", "validation", "unknown"] = Field(description="Error origin system")


class AppError(Exception):
    """Application-level exception with structured error envelope.

    Raised by application logic when an error should be returned to the client
    with a specific HTTP status and detailed error information.
    """

    def __init__(self, status_code: int, envelope: ErrorEnvelope):
        """Initialize AppError with HTTP status and error envelope.

        Args:
            status_code: HTTP status code for the response
            envelope: Structured error details
        """
        self.status_code = status_code
        self.envelope = envelope
        super().__init__(envelope.message)


# ---------------------------------------------------------------------------
# Snowflake Error Classification
# ---------------------------------------------------------------------------

# Pattern catalog ported from prompt_forge_v2/src/errors/snowflake/snowflakePatternCatalog.ts
# Patterns are checked in precedence order (network_policy highest, unknown lowest)
_SNOWFLAKE_ERROR_PATTERNS: list[tuple[str, re.Pattern[str], str]] = [
    # Network policy (precedence 10) - HIGHEST PRIORITY
    (
        "network_policy",
        re.compile(
            r"not allowed to access snowflake|network policy|ip.*not.*allow(?:ed|list)|incoming request.*not allowed",
            re.IGNORECASE,
        ),
        "Network policy violation detected",
    ),
    (
        "network_policy",
        re.compile(r"250001"),
        "Network policy error code 250001",
    ),
    # Authentication expired (precedence 20)
    (
        "auth_expired",
        re.compile(r"390114|390318|390144"),
        "Authentication token expired code",
    ),
    (
        "auth_expired",
        re.compile(r"authentication.*expired|token.*expired|session.*expired", re.IGNORECASE),
        "Authentication expiration message",
    ),
    # Authentication policy (precedence 25)
    (
        "auth_policy",
        re.compile(r"390202"),
        "Authentication policy code 390202",
    ),
    (
        "auth_policy",
        re.compile(
            r"authentication.*policy|auth.*method.*not.*allowed|policy.*reject",
            re.IGNORECASE,
        ),
        "Authentication policy rejection",
    ),
    # PAT invalid (precedence 30)
    (
        "pat_invalid",
        re.compile(
            r"PAT_INVALID|programmatic access token.*invalid|token.*mismatch",
            re.IGNORECASE,
        ),
        "Invalid programmatic access token",
    ),
    # Federated auth (precedence 35)
    (
        "federated_auth",
        re.compile(r"39013[6-9]|39014[0-9]|39015[0-9]|39016[0-9]|39017[0-9]|39018[0-9]|39019[0-1]"),
        "Federated authentication error code (390136-390191 range)",
    ),
    (
        "federated_auth",
        re.compile(
            r"SAML.*invalid|federated.*auth.*fail|identity provider|SSO.*fail",
            re.IGNORECASE,
        ),
        "Federated authentication failure message",
    ),
    # Permission (precedence 40)
    (
        "permission",
        re.compile(
            r"insufficient privileges|not authorized|permission denied|access denied|not.*grant",
            re.IGNORECASE,
        ),
        "Permission/authorization failure",
    ),
    # API timeout (precedence 45)
    (
        "api_timeout",
        re.compile(r"timed?\s?out|timeout|408", re.IGNORECASE),
        "Timeout indicator or HTTP 408",
    ),
    # API execution failure (precedence 50)
    (
        "api_execution_failure",
        re.compile(r"422|execution.*fail", re.IGNORECASE),
        "HTTP 422 or execution failure",
    ),
    # Transient (precedence 55)
    (
        "transient",
        re.compile(
            r"connection reset|temporarily unavailable|transient|try again|retry",
            re.IGNORECASE,
        ),
        "Transient connectivity issue",
    ),
    # Connection (precedence 60)
    (
        "connection",
        re.compile(
            r"08001|unable to (?:establish )?connect|connection.*fail|cannot connect",
            re.IGNORECASE,
        ),
        "Generic connection failure",
    ),
    # Feature not configured (precedence 70) - BEFORE sql_compilation
    (
        "feature_not_configured",
        re.compile(
            r"not configured|setup required|registry.*not.*setup|schema.*missing.*setup",
            re.IGNORECASE,
        ),
        "Feature configuration missing",
    ),
    # SQL compilation - object not found (precedence 75) - More specific than general compilation
    (
        "object_not_found",
        re.compile(r"does not exist|not found", re.IGNORECASE),
        "Missing Snowflake object",
    ),
    # SQL compilation - general (precedence 80)
    (
        "sql_compilation",
        re.compile(r"002003|SQL compilation error|syntax error", re.IGNORECASE),
        "SQL compilation failure",
    ),
    # SQL runtime (precedence 85)
    (
        "sql_runtime",
        re.compile(
            r"SQL execution error|division by zero|runtime error|query.*fail",
            re.IGNORECASE,
        ),
        "SQL execution failure",
    ),
    # Unknown fallback (precedence 999) - handled explicitly in classifier
]


def _sanitize_technical_details(message: str) -> str:
    """Remove sensitive information from error messages.

    Args:
        message: Raw error message that may contain credentials

    Returns:
        Sanitized message with credentials redacted
    """
    # Redact connection strings
    message = re.sub(
        r"(?:password|pwd|token|secret|key)[\s]*[=:][\s]*['\"]?[^'\"\s]+['\"]?",
        r"<REDACTED>",
        message,
        flags=re.IGNORECASE,
    )

    # Redact potential account names in URLs (keep region for debugging)
    message = re.sub(
        r"([a-z0-9_-]+)\.snowflakecomputing\.com",
        r"<ACCOUNT>.snowflakecomputing.com",
        message,
        flags=re.IGNORECASE,
    )

    # Redact IP addresses (keep placeholder for VPN guidance)
    message = re.sub(r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b", "<IP>", message)

    return message


def classify_snowflake_error(exc: BaseException, *, request_id: str) -> ErrorEnvelope:
    """Classify Snowflake exceptions into structured error envelopes.

    Implements message-first classification with precedence order from
    prompt_forge_v2/src/errors/snowflake/snowflakePatternCatalog.ts.

    Network policy errors are detected BEFORE generic connection/auth errors
    to prevent misdiagnosis.

    Args:
        exc: Exception raised by Snowflake connector, CLI, or Snowpark
        request_id: Request correlation ID from middleware

    Returns:
        Structured error envelope with category, guidance, and sanitized details
    """
    error_id = str(uuid.uuid4())
    exc_message = str(exc)
    exc_type = type(exc).__name__

    # Check patterns in precedence order
    matched_category: str | None = None
    matched_evidence: str | None = None

    for category, pattern, evidence in _SNOWFLAKE_ERROR_PATTERNS:
        if pattern.search(exc_message):
            matched_category = category
            matched_evidence = evidence
            break

    # Default to unknown if no pattern matched
    if matched_category is None:
        matched_category = "unknown"
        matched_evidence = "No recognized pattern"

    # Build category-specific guidance
    title, message, actions, severity, retryable = _build_error_guidance(matched_category, exc_type)

    # Sanitize technical details
    technical_details = _sanitize_technical_details(f"{exc_type}: {exc_message}\nEvidence: {matched_evidence}")

    return ErrorEnvelope(
        error_id=error_id,
        request_id=request_id,
        category=matched_category,
        severity=severity,
        title=title,
        message=message,
        actions=actions,
        retryable=retryable,
        technical_details=technical_details,
        source="snowflake",
    )


def _build_error_guidance(
    category: str, exc_type: str
) -> tuple[str, str, list[str], Literal["info", "warning", "error", "critical"], bool]:
    """Build user-facing error guidance based on category.

    Args:
        category: Classified error category
        exc_type: Exception type name for context

    Returns:
        Tuple of (title, message, actions, severity, retryable)
    """
    # Category-specific guidance catalog
    # Source: prompt_forge_v2/src/errors/snowflake/snowflakeGuidanceCatalog.ts
    guidance: dict[str, tuple[str, str, list[str], Literal["info", "warning", "error", "critical"], bool]] = {
        "network_policy": (
            "Can't Connect to Snowflake",
            "Your IP address is not allowed by Snowflake's network policy. "
            "This usually means you need to connect via VPN or add your IP to the allowlist.",
            [
                "Connect to your organization's VPN",
                "Contact your Snowflake administrator to add your IP to the allowlist",
                "Verify you're using the correct network connection",
            ],
            "error",
            False,
        ),
        "auth_expired": (
            "Session Expired",
            "Your Snowflake session has expired. Please re-authenticate to continue.",
            [
                "Refresh the page to re-authenticate",
                "Check your Snowflake credentials",
                "If using a token, generate a new one",
            ],
            "warning",
            True,
        ),
        "auth_policy": (
            "Authentication Method Not Allowed",
            "The authentication method used is not permitted by your organization's policy.",
            [
                "Contact your Snowflake administrator",
                "Use an allowed authentication method (SSO, MFA, etc.)",
            ],
            "error",
            False,
        ),
        "pat_invalid": (
            "Invalid Access Token",
            "The programmatic access token (PAT) is invalid or has been revoked.",
            [
                "Generate a new PAT from the Snowflake UI",
                "Update your connection configuration with the new token",
                "Verify the token hasn't expired",
            ],
            "error",
            False,
        ),
        "federated_auth": (
            "Federated Authentication Failed",
            "Single sign-on (SSO) authentication failed. This may be a temporary issue with your identity provider.",
            [
                "Try authenticating again",
                "Verify your SSO credentials with your identity provider",
                "Contact your IT support if the issue persists",
            ],
            "error",
            True,
        ),
        "permission": (
            "Permission Denied",
            "You don't have the required privileges to perform this operation.",
            [
                "Contact your Snowflake administrator to request access",
                "Verify you're using the correct role",
                "Check if the object exists and is accessible to your role",
            ],
            "warning",
            False,
        ),
        "api_timeout": (
            "Request Timed Out",
            "The Snowflake operation took too long and timed out. This may be due to "
            "a complex query or warehouse startup delay.",
            [
                "Try the operation again",
                "Consider using a larger warehouse for complex queries",
                "Break large operations into smaller chunks",
            ],
            "warning",
            True,
        ),
        "api_execution_failure": (
            "Execution Failed",
            "The Snowflake operation failed during execution.",
            [
                "Review the query for errors",
                "Check the technical details for specific error codes",
                "Try simplifying the operation",
            ],
            "error",
            True,
        ),
        "transient": (
            "Temporary Connection Issue",
            "A temporary connectivity issue occurred. This is usually transient and resolves automatically.",
            [
                "Retry the operation",
                "Wait a few moments before trying again",
                "Check Snowflake status page if issue persists",
            ],
            "warning",
            True,
        ),
        "connection": (
            "Connection Failed",
            "Unable to establish a connection to Snowflake.",
            [
                "Verify your network connection",
                "Check Snowflake account name and region",
                "Review technical details for specific connection errors",
            ],
            "error",
            False,
        ),
        "sql_compilation": (
            "SQL Syntax Error",
            "The SQL query has a syntax error and couldn't be compiled.",
            [
                "Review the SQL syntax",
                "Check for typos in table/column names",
                "Verify the query structure is correct",
            ],
            "error",
            False,
        ),
        "sql_runtime": (
            "SQL Execution Error",
            "The SQL query failed during execution.",
            [
                "Review the query logic",
                "Check for division by zero or null handling issues",
                "Verify data types and constraints",
            ],
            "error",
            False,
        ),
        "feature_not_configured": (
            "Feature Not Configured",
            "The requested Snowflake feature is not configured for this database or account.",
            [
                "Contact your Snowflake administrator",
                "Run required setup commands",
                "Review feature documentation for configuration steps",
            ],
            "warning",
            False,
        ),
        "object_not_found": (
            "Object Not Found",
            "The requested Snowflake object (table, view, function, etc.) doesn't exist or isn't accessible.",
            [
                "Verify the object name and schema",
                "Check if you have privileges to access the object",
                "Confirm the object exists in the correct database",
            ],
            "warning",
            False,
        ),
    }

    # Return guidance or fallback for unknown categories
    return guidance.get(
        category,
        (
            "Snowflake Error",
            f"An unexpected Snowflake error occurred: {exc_type}",
            [
                "Review the technical details",
                "Try the operation again",
                "Contact support if the issue persists",
            ],
            "error",
            False,
        ),
    )
