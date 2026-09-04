from typing import Optional
from pydantic import BaseModel, EmailStr, Field, ConfigDict, field_validator


class UserCreateSchema(BaseModel):
    name: str = Field(..., min_length=1)
    email: EmailStr
    password: str = Field(..., min_length=8)

    model_config = ConfigDict(extra="forbid")

    @field_validator("name", mode="before")
    @classmethod
    def strip_name(cls, v: str) -> str:
        if isinstance(v, str):
            return v.strip()
        return v


class UserLoginSchema(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1)

    model_config = ConfigDict(extra="forbid")

    @field_validator("email", mode="before")
    @classmethod
    def strip_email(cls, v: str) -> str:
        if isinstance(v, str):
            return v.strip()
        return v


class UserPasswordChangeSchema(BaseModel):
    current_password: str = Field(..., min_length=1)
    new_password: str = Field(..., min_length=8)

    model_config = ConfigDict(extra="forbid")


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


class PasswordChangeResponseSchema(BaseModel):
    message: str = "Password changed successfully"