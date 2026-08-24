from datetime import date

from pydantic import BaseModel, EmailStr
from typing import Optional


class EmployeeCreateSchema(BaseModel):
    name: str
    email: EmailStr
    phone: str
    department: str
    role: str = "employee"
    joining_date: date


class EmployeeUpdateSchema(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    department: Optional[str] = None
    role: Optional[str] = None
    joining_date: Optional[date] = None