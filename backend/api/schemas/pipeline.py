"""Pipeline API response schemas for the React frontend.

Defines Pydantic models for type-safe API responses with automatic
OpenAPI documentation generation. Covers funnel metrics, phase progress,
and task DAG state.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class FunnelResponse(BaseModel):
    """Pipeline funnel metrics showing item flow through processing stages.

    Tracks item counts at each stage from raw ingestion through ensemble
    scoring, enabling visualization of pipeline throughput.
    """

    raw_items: int = Field(..., description="Total raw items ingested")
    categorized_items: int = Field(..., description="Items that have been categorized")
    blocked_items: int = Field(..., description="Items blocked from processing")
    unique_descriptions: int = Field(..., description="Unique item descriptions")
    pipeline_items: int = Field(..., description="Items currently in pipeline")
    ensemble_done: int = Field(0, description="Items with ensemble scoring complete")


class PhaseProgress(BaseModel):
    """Progress information for a single pipeline phase.

    Used for rendering progress bars in the UI with color-coded states.
    """

    name: str = Field(..., description="Phase display name")
    done: int = Field(..., description="Items completed in this phase")
    total: int = Field(..., description="Total items to process in this phase")
    pct: float = Field(..., ge=0, le=100, description="Completion percentage")
    state: str = Field(..., description="Phase state: WAITING, PROCESSING, COMPLETE, ERROR")
    color: str = Field(..., description="UI color for progress bar")


class PhasesResponse(BaseModel):
    """Pipeline phases progress with overall state for the phases dashboard."""

    phases: list[PhaseProgress] = Field(..., description="Progress for each pipeline phase")
    pipeline_state: str | None = Field(None, description="Overall pipeline state")
    active_phase: str | None = Field(None, description="Currently active phase name(s)")
    ensemble_waiting_for: str | None = Field(None, description="Phase ensemble is waiting for")
    batch_id: str | None = Field(None, description="Current batch identifier")


class TaskState(BaseModel):
    """State of a Snowflake Task in the pipeline DAG.

    Represents one task in the task hierarchy with its scheduling
    and execution state for the task management UI.
    """

    name: str = Field(..., description="Task name")
    state: str = Field(..., description="Task state: started, suspended, etc.")
    schedule: str | None = Field(None, description="Task schedule expression (None for child tasks)")
    role: str = Field(..., description="Task role: root, child")
    level: int = Field(..., description="DAG hierarchy level")
    dag: str = Field(..., description="DAG name this task belongs to")


class TasksResponse(BaseModel):
    """Pipeline DAG tasks and their states for task management view."""

    tasks: list[TaskState] = Field(..., description="All pipeline tasks")
    all_tasks_suspended: bool = Field(False, description="Whether all tasks are suspended")
    pending_count: int = Field(0, description="Number of pending executions")
    is_running: bool = Field(False, description="Whether pipeline is currently running")


class ActionResponse(BaseModel):
    """Response for pipeline action endpoints (run, stop, toggle)."""

    success: bool = Field(..., description="Whether action succeeded")
    message: str = Field(..., description="Status message")
    job_id: str | None = Field(None, description="Job ID if applicable")


class ToggleTaskRequest(BaseModel):
    """Request body for toggling a task."""

    task_name: str = Field(..., description="Name of task to toggle")
    action: str = Field(..., description="Action: resume or suspend")
