"""Tests for backend error handling and Snowflake error classification.

Validates ErrorEnvelope model, AppError exception, Snowflake error pattern
classification against committed fixtures, and sanitization of sensitive data.
"""

from __future__ import annotations

from backend.api.errors import (
    AppError,
    ErrorEnvelope,
    _sanitize_technical_details,
    classify_snowflake_error,
)

# ---------------------------------------------------------------------------
# ErrorEnvelope Model Tests
# ---------------------------------------------------------------------------


def test_error_envelope_required_fields():
    """ErrorEnvelope requires all mandatory fields."""
    envelope = ErrorEnvelope(
        error_id="err-123",
        request_id="req-456",
        category="network_policy",
        severity="error",
        title="Can't Connect",
        message="Network policy blocked your IP",
        source="snowflake",
    )

    assert envelope.error_id == "err-123"
    assert envelope.request_id == "req-456"
    assert envelope.category == "network_policy"
    assert envelope.severity == "error"
    assert envelope.title == "Can't Connect"
    assert envelope.message == "Network policy blocked your IP"
    assert envelope.actions == []
    assert envelope.retryable is False
    assert envelope.technical_details is None
    assert envelope.source == "snowflake"


def test_error_envelope_optional_fields():
    """ErrorEnvelope includes optional fields when provided."""
    envelope = ErrorEnvelope(
        error_id="err-123",
        request_id="req-456",
        category="transient",
        severity="warning",
        title="Temporary Issue",
        message="Connection was reset",
        actions=["Retry the operation", "Wait a moment"],
        retryable=True,
        technical_details="Connection reset by peer",
        source="snowflake",
    )

    assert envelope.actions == ["Retry the operation", "Wait a moment"]
    assert envelope.retryable is True
    assert envelope.technical_details == "Connection reset by peer"


# ---------------------------------------------------------------------------
# AppError Exception Tests
# ---------------------------------------------------------------------------


def test_app_error_exception():
    """AppError wraps HTTP status and error envelope."""
    envelope = ErrorEnvelope(
        error_id="err-123",
        request_id="req-456",
        category="validation",
        severity="error",
        title="Validation Error",
        message="Invalid request data",
        source="api",
    )

    exc = AppError(status_code=422, envelope=envelope)

    assert exc.status_code == 422
    assert exc.envelope == envelope
    assert str(exc) == "Invalid request data"


# ---------------------------------------------------------------------------
# Sanitization Tests
# ---------------------------------------------------------------------------


def test_sanitize_redacts_passwords():
    """Sanitization removes password values."""
    message = "Connection failed: password=secret123 token=abc-def"
    sanitized = _sanitize_technical_details(message)

    assert "secret123" not in sanitized
    assert "abc-def" not in sanitized
    assert "<REDACTED>" in sanitized


def test_sanitize_redacts_connection_strings():
    """Sanitization removes credentials from connection strings."""
    message = "Error: pwd='my_password', key: 'secret_key_value'"
    sanitized = _sanitize_technical_details(message)

    assert "my_password" not in sanitized
    assert "secret_key_value" not in sanitized


def test_sanitize_redacts_account_names():
    """Sanitization replaces account names in URLs."""
    message = "Failed to connect to myaccount.snowflakecomputing.com:443"
    sanitized = _sanitize_technical_details(message)

    assert "myaccount" not in sanitized
    assert "<ACCOUNT>.snowflakecomputing.com" in sanitized


def test_sanitize_redacts_ip_addresses():
    """Sanitization replaces IP addresses with placeholder."""
    message = "Incoming request from IP 203.0.113.45 not allowed"
    sanitized = _sanitize_technical_details(message)

    assert "203.0.113.45" not in sanitized
    assert "<IP>" in sanitized


# ---------------------------------------------------------------------------
# Snowflake Error Classification Tests (Network Policy)
# ---------------------------------------------------------------------------


def test_classify_network_policy_pattern_1():
    """Network policy error: 'not allowed to access snowflake' pattern."""
    exc = Exception(
        "250001 (08001): Failed to connect to DB. Incoming request with IP is not allowed to access Snowflake."
    )

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "network_policy"
    assert envelope.severity == "error"
    assert envelope.title == "Can't Connect to Snowflake"
    assert "VPN" in envelope.message
    assert envelope.retryable is False
    assert envelope.source == "snowflake"
    assert any("VPN" in action for action in envelope.actions)


def test_classify_network_policy_pattern_2():
    """Network policy error: code 250001."""
    exc = Exception("250001 (08001): Failed to connect to DB: account.snowflakecomputing.com:443")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "network_policy"
    assert envelope.severity == "error"


def test_classify_network_policy_pattern_3():
    """Network policy error: 'network policy' explicit mention."""
    exc = Exception("Network policy 'RESTRICTIVE_POLICY' blocked incoming request from IP")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "network_policy"


def test_classify_network_policy_pattern_4():
    """Network policy error: 'IP not allowed' pattern."""
    exc = Exception("Connection failed: IP address not allowed by network policy")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "network_policy"


# ---------------------------------------------------------------------------
# Snowflake Error Classification Tests (Authentication)
# ---------------------------------------------------------------------------


def test_classify_auth_expired_code_390114():
    """Auth expired error: code 390114."""
    exc = Exception("390114: Authentication token has expired. The user must authenticate again.")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "auth_expired"
    assert envelope.severity == "warning"
    assert envelope.retryable is True
    assert "expired" in envelope.message.lower()


def test_classify_auth_expired_code_390318():
    """Auth expired error: code 390318."""
    exc = Exception("ProgrammingError: 390318 (08001): Session token has expired.")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "auth_expired"


def test_classify_auth_expired_message():
    """Auth expired error: 'authentication expired' message."""
    exc = Exception("Authentication expired. Your session is no longer valid.")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "auth_expired"


def test_classify_pat_invalid():
    """PAT invalid error."""
    exc = Exception("PAT_INVALID: Programmatic access token is invalid or has been revoked.")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "pat_invalid"
    assert envelope.severity == "error"
    assert "token" in envelope.message.lower()


# ---------------------------------------------------------------------------
# Snowflake Error Classification Tests (Permission)
# ---------------------------------------------------------------------------


def test_classify_permission_insufficient_privileges():
    """Permission error: 'insufficient privileges' pattern."""
    exc = Exception("002003 (42501): SQL access control error: Insufficient privileges to operate on table")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "permission"
    assert envelope.severity == "warning"
    assert envelope.retryable is False
    assert "privilege" in envelope.message.lower()


def test_classify_permission_not_authorized():
    """Permission error: 'not authorized' pattern."""
    exc = Exception("User 'DEMO_USER' is not authorized to perform operation SELECT")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "permission"


def test_classify_permission_access_denied():
    """Permission error: 'access denied' pattern."""
    exc = Exception("Access denied for ROLE 'READER_ROLE' on DATABASE 'RESTRICTED_DB'")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "permission"


# ---------------------------------------------------------------------------
# Snowflake Error Classification Tests (Connection/Transient)
# ---------------------------------------------------------------------------


def test_classify_transient_connection_reset():
    """Transient error: 'connection reset' pattern."""
    exc = Exception("Connection reset by peer during query execution")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "transient"
    assert envelope.severity == "warning"
    assert envelope.retryable is True


def test_classify_transient_temporarily_unavailable():
    """Transient error: 'temporarily unavailable' pattern."""
    exc = Exception("Temporarily unavailable: Connection to Snowflake service is experiencing transient issues")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "transient"


def test_classify_connection_08001():
    """Connection error: code 08001 (generic, not network policy)."""
    # This should match 'connection' NOT 'network_policy' since
    # network policy patterns have higher precedence and are checked first
    exc = Exception("08001: Unable to connect to Snowflake")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    # If message contains "not allowed to access snowflake", it's network_policy
    # Otherwise, it's generic connection
    assert envelope.category == "connection"
    assert envelope.severity == "error"


def test_classify_connection_failed():
    """Connection error: 'connection failed' pattern."""
    exc = Exception("Connection failed: unable to establish connection")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "connection"


# ---------------------------------------------------------------------------
# Snowflake Error Classification Tests (SQL)
# ---------------------------------------------------------------------------


def test_classify_sql_compilation_error():
    """SQL compilation error: code 002003."""
    exc = Exception("002003 (42000): SQL compilation error: syntax error line 1 at position 15")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "sql_compilation"
    assert envelope.severity == "error"
    assert envelope.retryable is False


def test_classify_sql_runtime_division_by_zero():
    """SQL runtime error: division by zero."""
    exc = Exception("100051 (22012): SQL execution error: Division by zero encountered")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "sql_runtime"
    assert envelope.severity == "error"


def test_classify_object_not_found():
    """Object not found error."""
    exc = Exception("002003 (42S02): SQL compilation error: Object 'DATABASE.SCHEMA.TABLE' does not exist")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "object_not_found"
    assert envelope.severity == "warning"


def test_classify_feature_not_configured():
    """Feature not configured error (precedence before object_not_found)."""
    exc = Exception("002003: Model registry not configured for database 'ANALYTICS'")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "feature_not_configured"
    assert envelope.severity == "warning"


# ---------------------------------------------------------------------------
# Classification Precedence Tests
# ---------------------------------------------------------------------------


def test_network_policy_takes_precedence_over_connection():
    """Network policy errors detected BEFORE generic connection errors."""
    # This message matches both network_policy and connection patterns
    # Network policy should win (higher precedence)
    exc = Exception("08001: Unable to connect. Incoming request not allowed to access Snowflake.")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "network_policy"


def test_feature_not_configured_takes_precedence_over_object_not_found():
    """Feature configuration errors detected BEFORE object not found."""
    # Use a message that contains both "not configured" and "does not exist"
    # "not configured" pattern should match first (precedence 70 vs 75)
    exc = Exception("Feature not configured. Schema does not exist. Run setup commands.")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    # Should match feature_not_configured (precedence 70) before object_not_found (75)
    assert envelope.category == "feature_not_configured"


# ---------------------------------------------------------------------------
# Unknown Error Classification
# ---------------------------------------------------------------------------


def test_classify_unknown_error():
    """Unrecognized errors fallback to 'unknown' category."""
    exc = Exception("Some completely unrecognized error message format")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.category == "unknown"
    assert envelope.severity == "error"
    assert envelope.source == "snowflake"
    assert envelope.error_id  # UUID generated
    assert envelope.request_id == "req-123"


# ---------------------------------------------------------------------------
# Correlation ID Tests
# ---------------------------------------------------------------------------


def test_classify_preserves_request_id():
    """Classifier preserves request ID for correlation."""
    exc = Exception("Some error")

    envelope = classify_snowflake_error(exc, request_id="req-abc-123")

    assert envelope.request_id == "req-abc-123"


def test_classify_generates_error_id():
    """Classifier generates unique error ID."""
    exc = Exception("Some error")

    envelope1 = classify_snowflake_error(exc, request_id="req-123")
    envelope2 = classify_snowflake_error(exc, request_id="req-123")

    # Each classification generates a new error ID
    assert envelope1.error_id != envelope2.error_id
    assert len(envelope1.error_id) > 0


# ---------------------------------------------------------------------------
# Sanitization Integration Tests
# ---------------------------------------------------------------------------


def test_classify_sanitizes_technical_details():
    """Classified errors have sanitized technical details."""
    exc = Exception("250001: Failed to connect to myaccount.snowflakecomputing.com. Password: secret123")

    envelope = classify_snowflake_error(exc, request_id="req-123")

    assert envelope.technical_details is not None
    assert "secret123" not in envelope.technical_details
    assert "myaccount" not in envelope.technical_details
    assert "<ACCOUNT>" in envelope.technical_details
