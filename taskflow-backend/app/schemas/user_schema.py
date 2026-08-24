from pydantic import BaseModel, EmailStr


class UserCreateSchema(BaseModel):
    name: str
    email: EmailStr
    password: str
    role: str = "employee"   # admin / manager / employee


class UserLoginSchema(BaseModel):
    email: EmailStr
    password: str