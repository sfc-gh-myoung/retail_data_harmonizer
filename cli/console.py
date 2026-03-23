"""Rich console utilities for colored output."""

import os
from datetime import UTC, datetime

from rich.console import Console
from rich.theme import Theme

from cli.config import state

custom_theme = Theme(
    {
        "info": "blue",
        "success": "green",
        "warning": "yellow",
        "error": "red bold",
        "section": "cyan bold",
        "phase": "yellow",
        "timestamp": "dim",
    }
)

console = Console(theme=custom_theme, force_terminal=not os.environ.get("NO_COLOR"))
err_console = Console(theme=custom_theme, stderr=True, force_terminal=not os.environ.get("NO_COLOR"))


def _ts_prefix() -> str:
    """Return timestamp prefix if verbose mode is enabled, otherwise empty string."""
    if state.verbose:
        ts = datetime.now(UTC).strftime("%Y-%m-%d %H:%M:%S")
        return f"[timestamp]{ts}[/timestamp] "
    return ""


def log_info(message: str) -> None:
    """Print an informational message with [INFO] prefix.

    Args:
        message: The message to display.
    """
    console.print(f"{_ts_prefix()}[info]\\[INFO][/info] {message}")


def log_success(message: str) -> None:
    """Print a success message with [PASS] prefix in green.

    Args:
        message: The message to display.
    """
    console.print(f"{_ts_prefix()}[success]\\[PASS][/success] {message}")


def log_warning(message: str) -> None:
    """Print a warning message with [WARNING] prefix in yellow.

    Args:
        message: The message to display.
    """
    console.print(f"{_ts_prefix()}[warning]\\[WARNING][/warning] {message}")


def log_error(message: str) -> None:
    """Print an error message with [FAIL] prefix in red to stderr.

    Args:
        message: The message to display.
    """
    err_console.print(f"{_ts_prefix()}[error]\\[FAIL][/error] {message}")


def log_section(title: str) -> None:
    """Print a major section header with decorative borders.

    Args:
        title: The section title to display.
    """
    console.print()
    console.print("[section]════════════════════════════════════════════════════════════════[/section]")
    console.print(f"[bold]{title}[/bold]")
    console.print("[section]════════════════════════════════════════════════════════════════[/section]")
    console.print()


def log_phase(title: str) -> None:
    """Print a minor phase header with decorative borders.

    Args:
        title: The phase title to display.
    """
    console.print()
    console.print("[phase]──────────────────────────────────────────────────────────────────[/phase]")
    console.print(f"[bold]{title}[/bold]")
    console.print("[phase]──────────────────────────────────────────────────────────────────[/phase]")


def log_connection(connection: str) -> None:
    """Print the active Snowflake connection name.

    Args:
        connection: The connection name to display.
    """
    console.print(f"[info]Snowflake Connection:[/info] {connection}")
    console.print()
