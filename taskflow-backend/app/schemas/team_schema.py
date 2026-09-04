from typing import List, Optional
from pydantic import BaseModel, Field, ConfigDict, field_validator


class TeamCreateSchema(BaseModel):
    name: str = Field(..., min_length=1)
    description: Optional[str] = None
    manager_id: Optional[str] = None

    model_config = ConfigDict(extra="forbid")

    @field_validator("name", mode="before")
    @classmethod
    def strip_name(cls, v: str) -> str:
        if isinstance(v, str):
            return v.strip()
        return v


class TeamUpdateSchema(BaseModel):
    name: Optional[str] = Field(None, min_length=1)
    description: Optional[str] = None
    manager_id: Optional[str] = None

    model_config = ConfigDict(extra="forbid")

    @field_validator("name", mode="before")
    @classmethod
    def strip_name(cls, v: Optional[str]) -> Optional[str]:
        if isinstance(v, str):
            return v.strip()
        return v


class TeamMemberAssignSchema(BaseModel):
    employee_id: str = Field(..., min_length=1)

    model_config = ConfigDict(extra="forbid")


class TeamResponseSchema(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    manager_id: Optional[str] = None
    member_ids: List[str] = []
