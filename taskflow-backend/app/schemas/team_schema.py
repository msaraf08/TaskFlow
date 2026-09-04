from typing import List, Optional
from pydantic import BaseModel, Field


class TeamCreateSchema(BaseModel):
    name: str = Field(..., min_length=1)
    description: Optional[str] = None
    manager_id: Optional[str] = None


class TeamUpdateSchema(BaseModel):
    name: Optional[str] = Field(None, min_length=1)
    description: Optional[str] = None
    manager_id: Optional[str] = None


class TeamResponseSchema(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    manager_id: Optional[str] = None
    member_ids: List[str] = []
