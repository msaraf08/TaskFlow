from datetime import date, datetime
from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

ProjectStatus = Literal["planned", "active", "completed", "cancelled"]


class ProjectCreateSchema(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    description: Optional[str] = Field(None, max_length=2000)
    team_id: str = Field(..., min_length=1)
    start_date: date
    end_date: date
    status: ProjectStatus = "planned"

    model_config = ConfigDict(extra="forbid")

    @field_validator("name", mode="before")
    @classmethod
    def strip_and_validate_name(cls, v: str) -> str:
        if isinstance(v, str):
            v_stripped = v.strip()
            if not v_stripped:
                raise ValueError("Project name must not be empty or whitespace only")
            return v_stripped
        return v

    @model_validator(mode="after")
    def validate_date_range(self) -> "ProjectCreateSchema":
        if self.start_date and self.end_date and self.end_date < self.start_date:
            raise ValueError("end_date must not be earlier than start_date")
        return self


class ProjectUpdateSchema(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=120)
    description: Optional[str] = Field(None, max_length=2000)
    team_id: Optional[str] = Field(None, min_length=1)
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    status: Optional[ProjectStatus] = None

    model_config = ConfigDict(extra="forbid")

    @field_validator("name", mode="before")
    @classmethod
    def strip_and_validate_name(cls, v: Optional[str]) -> Optional[str]:
        if isinstance(v, str):
            v_stripped = v.strip()
            if not v_stripped:
                raise ValueError("Project name must not be empty or whitespace only")
            return v_stripped
        return v

    @model_validator(mode="after")
    def validate_date_range(self) -> "ProjectUpdateSchema":
        if self.start_date and self.end_date and self.end_date < self.start_date:
            raise ValueError("end_date must not be earlier than start_date")
        return self


class ProjectResponseSchema(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    team_id: str
    start_date: date
    end_date: date
    status: str
    created_by: str
    created_at: datetime
    updated_at: datetime
