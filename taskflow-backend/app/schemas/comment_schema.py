from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


class CommentCreateSchema(BaseModel):
    model_config = ConfigDict(extra="forbid")

    content: str = Field(..., min_length=1, max_length=2000)

    @field_validator("content")
    @classmethod
    def validate_content(cls, v: str) -> str:
        trimmed = v.strip()
        if not trimmed:
            raise ValueError("Comment content cannot be empty or whitespace only")
        if len(trimmed) > 2000:
            raise ValueError("Comment content cannot exceed 2000 characters")
        return trimmed


class CommentUpdateSchema(BaseModel):
    model_config = ConfigDict(extra="forbid")

    content: str = Field(..., min_length=1, max_length=2000)

    @field_validator("content")
    @classmethod
    def validate_content(cls, v: str) -> str:
        trimmed = v.strip()
        if not trimmed:
            raise ValueError("Comment content cannot be empty or whitespace only")
        if len(trimmed) > 2000:
            raise ValueError("Comment content cannot exceed 2000 characters")
        return trimmed


class CommentResponseSchema(BaseModel):
    id: str
    task_id: str
    user_id: str
    author_name: Optional[str] = None
    content: str
    created_at: datetime
    updated_at: datetime
