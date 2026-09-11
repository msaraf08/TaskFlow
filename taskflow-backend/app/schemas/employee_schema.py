from datetime import date
from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class EmployeeCreateSchema(BaseModel):
    name: str = Field(..., min_length=1)
    email: EmailStr
    phone: str = Field(..., min_length=1)
    department: str = Field(..., min_length=1)
    role: str = "employee"
    joining_date: date
    initial_password: Optional[str] = Field(None, min_length=6)


class EmployeeUpdateSchema(BaseModel):
    name: Optional[str] = Field(None, min_length=1)
    phone: Optional[str] = Field(None, min_length=1)
    department: Optional[str] = Field(None, min_length=1)
    role: Optional[str] = None
    joining_date: Optional[date] = None


class EmployeeProfileUpdateSchema(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    department: Optional[str] = Field(None, max_length=100)

    model_config = ConfigDict(extra="forbid")

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            stripped = v.strip()
            if not stripped:
                raise ValueError("Name cannot be empty or only whitespace")
            return stripped
        return v

    @field_validator("phone", "department")
    @classmethod
    def strip_optional(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            return v.strip()
        return v


class EmployeeRoleUpdateSchema(BaseModel):
    role: Literal["employee", "manager", "admin"]

    model_config = ConfigDict(extra="forbid")


class EmployeeResponseSchema(BaseModel):
    id: str
    user_id: str
    name: str
    email: EmailStr
    phone: str
    department: str
    role: str
    joining_date: Optional[date] = None
    status: str = "active"


class EmployeeCreateResponseSchema(EmployeeResponseSchema):
    temporary_password: Optional[str] = None