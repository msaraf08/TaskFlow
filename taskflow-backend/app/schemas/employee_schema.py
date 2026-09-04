from datetime import date
from typing import Optional
from pydantic import BaseModel, EmailStr, Field


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