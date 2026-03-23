"""Configuration constants and global state for the CLI."""

from pathlib import Path


class Config:
    """Configuration constants for the Retail Data Harmonizer demo.

    This class holds immutable configuration values used throughout the CLI.
    All attributes are class-level constants.

    Attributes:
        VERSION: Current version of the CLI tool.
        DATABASE: Default Snowflake database name.
        WAREHOUSE: Default Snowflake warehouse name.
        ROLE: Default Snowflake role name.
        SQL_DIR: Path to SQL scripts directory.
        SCHEMA_RAW: Fully qualified raw data schema.
        SCHEMA_HARMONIZED: Fully qualified harmonized data schema.
        SCHEMA_ANALYTICS: Fully qualified analytics schema.
    """

    VERSION = "1.1.0"
    DATABASE = "HARMONIZER_DEMO"
    WAREHOUSE = "HARMONIZER_DEMO_WH"
    ROLE = "HARMONIZER_DEMO_ROLE"
    SQL_DIR = Path("sql")

    # Schemas
    SCHEMA_RAW = f"{DATABASE}.RAW"
    SCHEMA_HARMONIZED = f"{DATABASE}.HARMONIZED"
    SCHEMA_ANALYTICS = f"{DATABASE}.ANALYTICS"


class State:
    """Global state shared across CLI commands.

    This class maintains mutable state that can be modified by CLI options
    and is accessed throughout command execution.

    Attributes:
        connection: Snowflake connection name from ~/.snowflake/connections.toml.
        verbose: Whether to show verbose output including timestamps.
        force: Whether to skip confirmation prompts.
    """

    def __init__(self) -> None:
        """Initialize state with default values."""
        self.connection: str = "default"
        self.verbose: bool = False
        self.force: bool = False


state = State()
