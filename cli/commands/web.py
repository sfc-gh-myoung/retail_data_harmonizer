"""Web application commands.

Manages the FastAPI web server and React frontend build toolchain.

Commands:
    serve: Start the FastAPI web application (uvicorn).
    react-install: Install React frontend npm dependencies.
    react-dev: Start React development server (port 5173).
    react-build: Build React frontend for production.
    react-lint: Run ESLint on React frontend.
    react-preview: Preview React production build (port 4173).

Side Effects:
    serve: Starts a long-running uvicorn process. Configures global Snowflake client.
    react-*: Runs npm commands in the frontend/react directory as subprocesses.
"""

import shutil
import subprocess
from pathlib import Path
from typing import Annotated

import typer

from cli.config import Config, state
from cli.console import log_error, log_info, log_success

app = typer.Typer(help="Web application commands", no_args_is_help=True)

# React frontend directory
REACT_DIR = Path(__file__).parent.parent.parent / "frontend" / "react"


def _check_npm() -> bool:
    """Check if npm is available."""
    if not shutil.which("npm"):
        log_error("npm not found. Install Node.js: https://nodejs.org/")
        return False
    return True


def _run_npm(args: list[str], description: str) -> bool:
    """Run an npm command in the React directory."""
    if not _check_npm():
        return False

    if not REACT_DIR.exists():
        log_error(f"React directory not found: {REACT_DIR}")
        return False

    log_info(f"{description}...")
    result = subprocess.run(["npm", *args], cwd=REACT_DIR, check=False)
    return result.returncode == 0


@app.command()
def serve(
    host: Annotated[str, typer.Option(help="Bind host")] = "0.0.0.0",
    port: Annotated[int, typer.Option(help="Bind port")] = 8000,
    reload: Annotated[bool, typer.Option(help="Enable auto-reload for development")] = False,
) -> None:
    """Start the FastAPI web application.

    Configures the Snowflake client and launches uvicorn to serve the
    full-stack application (API + static frontend). Runs until interrupted.

    Side Effects:
        - Configures global Snowflake client with active CLI connection
        - Binds to host:port and serves HTTP requests
    """
    from backend.api import snowflake_client as sf

    sf.configure(connection=state.connection, database=Config.DATABASE)

    log_info(f"Serving at http://{host}:{port}")

    import uvicorn

    log_config = {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "default": {
                "()": "uvicorn.logging.DefaultFormatter",
                "format": "%(asctime)s %(levelprefix)s %(message)s",
                "datefmt": "%Y-%m-%d %H:%M:%S",
                "use_colors": True,
            },
            "access": {
                "()": "uvicorn.logging.AccessFormatter",
                "format": '%(asctime)s %(levelprefix)s %(client_addr)s - "%(request_line)s" %(status_code)s',
                "datefmt": "%Y-%m-%d %H:%M:%S",
                "use_colors": True,
            },
            "app": {
                "format": "%(asctime)s %(levelname)-8s %(message)s",
                "datefmt": "%Y-%m-%d %H:%M:%S",
            },
        },
        "handlers": {
            "default": {
                "formatter": "default",
                "class": "logging.StreamHandler",
                "stream": "ext://sys.stderr",
            },
            "access": {
                "formatter": "access",
                "class": "logging.StreamHandler",
                "stream": "ext://sys.stdout",
            },
            "app": {
                "formatter": "app",
                "class": "logging.StreamHandler",
                "stream": "ext://sys.stdout",
            },
        },
        "loggers": {
            "uvicorn": {"handlers": ["default"], "level": "INFO", "propagate": False},
            "uvicorn.error": {"level": "INFO"},
            "uvicorn.access": {"handlers": ["access"], "level": "INFO", "propagate": False},
            "retail_harmonizer.api": {"handlers": ["app"], "level": "INFO", "propagate": False},
        },
    }

    uvicorn.run("backend.api:app", host=host, port=port, reload=reload, log_config=log_config)


@app.command(name="react-install")
def react_install() -> None:
    """Install React frontend dependencies."""
    if _run_npm(["install"], "Installing React dependencies"):
        log_success("React dependencies installed")
    else:
        log_error("React install failed")
        raise typer.Exit(1)


@app.command(name="react-dev")
def react_dev() -> None:
    """Start React development server on port 5173."""
    if _run_npm(["run", "dev"], "Starting React dev server"):
        log_success("React dev server stopped")
    else:
        raise typer.Exit(1)


@app.command(name="react-build")
def react_build() -> None:
    """Build React frontend for production."""
    if _run_npm(["run", "build"], "Building React frontend"):
        log_success("React build complete")
    else:
        log_error("React build failed")
        raise typer.Exit(1)


@app.command(name="react-lint")
def react_lint() -> None:
    """Run ESLint on React frontend."""
    if _run_npm(["run", "lint"], "Running ESLint"):
        log_success("Lint passed")
    else:
        log_error("Lint failed")
        raise typer.Exit(1)


@app.command(name="react-preview")
def react_preview() -> None:
    """Preview React production build on port 4173."""
    if _run_npm(["run", "preview"], "Starting preview server"):
        log_success("Preview server stopped")
    else:
        raise typer.Exit(1)
