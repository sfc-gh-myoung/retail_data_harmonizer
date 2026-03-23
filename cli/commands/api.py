"""API server commands.

Provides the JSON API server for the React frontend. The server exposes
match search, review, settings, testing, and pipeline management endpoints.

Commands:
    serve: Start the JSON API server (uvicorn).

Side Effects:
    serve: Starts a long-running uvicorn process binding to the specified host/port.
    Configures the Snowflake client with the active CLI connection.
"""

from typing import Annotated

import typer

from cli.config import Config, state
from cli.console import log_info

app = typer.Typer(help="API server commands", no_args_is_help=True)


@app.command()
def serve(
    host: Annotated[str, typer.Option(help="Bind host")] = "0.0.0.0",
    port: Annotated[int, typer.Option(help="Bind port")] = 8000,
    reload: Annotated[bool, typer.Option(help="Enable auto-reload")] = False,
) -> None:
    """Start the JSON API server.

    Configures the Snowflake client and launches uvicorn to serve the
    FastAPI application. The server runs until interrupted (Ctrl+C).

    Side Effects:
        - Configures global Snowflake client with active CLI connection
        - Binds to host:port and serves HTTP requests
        - Logs to stderr (uvicorn) and stdout (app, access)
    """
    from backend.api.snowflake_client import configure

    configure(connection=state.connection, database=Config.DATABASE)

    log_info(f"Starting API server at http://{host}:{port}")

    import uvicorn

    # Configure logging with timestamps and consistent formatting
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
