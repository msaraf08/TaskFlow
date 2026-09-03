from pydantic import BaseModel
from typing import Optional


class TeamCreateSchema(BaseModel):
    name: str
    description: Optional[str] = None
    manager_id: Optional[str] = None


class TeamUpdateSchema(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    manager_id: Optional[str] = None
