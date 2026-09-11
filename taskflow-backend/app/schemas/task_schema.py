from datetime import date, datetime
from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator

TaskPriority = Literal["low", "medium", "high", "urgent"]
TaskStatus = Literal["todo", "in_progress", "completed", "cancelled"]


class TaskCreateSchema(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=5000)
    project_id: str = Field(..., min_length=1)
    assigned_to: str = Field(..., min_length=1)
    priority: TaskPriority = "medium"
    status: TaskStatus = "todo"
    due_date: Optional[date] = None

    model_config = ConfigDict(extra="forbid")

    @field_validator("title", mode="before")
    @classmethod
    def strip_and_validate_title(cls, v: str) -> str:
        if isinstance(v, str):
            v_stripped = v.strip()
            if not v_stripped:
                raise ValueError("Task title must not be empty or whitespace only")
            return v_stripped
        return v


class TaskUpdateSchema(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=5000)
    project_id: Optional[str] = Field(None, min_length=1)
    assigned_to: Optional[str] = Field(None, min_length=1)
    priority: Optional[TaskPriority] = None
    status: Optional[TaskStatus] = None
    due_date: Optional[date] = None

    model_config = ConfigDict(extra="forbid")

    @field_validator("title", mode="before")
    @classmethod
    def strip_and_validate_title(cls, v: Optional[str]) -> Optional[str]:
        if isinstance(v, str):
            v_stripped = v.strip()
            if not v_stripped:
                raise ValueError("Task title must not be empty or whitespace only")
            return v_stripped
        return v


class TaskResponseSchema(BaseModel):
    id: str
    title: str
    description: Optional[str] = None
    project_id: str
    assigned_to: str
    assignee_name: Optional[str] = None
    priority: str
    status: str
    due_date: Optional[date] = None
    created_by: str
    created_at: datetime
    updated_at: datetime
