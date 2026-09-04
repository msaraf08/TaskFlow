from pydantic import BaseModel, EmailStr, Field
from typing import Optional


class UserCreateSchema(BaseModel):
    name: str = Field(..., min_length=1)
    email: EmailStr
    password: str = Field(..., min_length=6)


class UserLoginSchema(BaseModel):
    email: EmailStr
    password: str


class UserResponseSchema(BaseModel):
    id: str
    name: str
    email: EmailStr
    role: str
    status: str = "active"


class UserRegisterResponseSchema(BaseModel):
    message: str
    user: Optional[UserResponseSchema] = None


class TokenResponseSchema(BaseModel):
    access_token: str
    token_type: str = "bearer"