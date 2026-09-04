from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.user_schema import (
    UserCreateSchema,
    UserLoginSchema,
    UserRegisterResponseSchema,
    TokenResponseSchema,
    UserResponseSchema
)
from app.database.dependencies import get_user_collection
from app.core.security import hash_password, verify_password
from app.core.jwt import create_access_token

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    response_model=UserRegisterResponseSchema
)
async def register_user(
    user: UserCreateSchema,
    collection=Depends(get_user_collection)
):
    existing = await collection.find_one({"email": user.email})
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User already exists"
        )

    # Initial Admin Bootstrap: First registered user becomes admin, subsequent users become employee
    user_count = await collection.count_documents({})
    assigned_role = "admin" if user_count == 0 else "employee"

    user_dict = {
        "name": user.name,
        "email": user.email,
        "password": hash_password(user.password),
        "role": assigned_role,
        "status": "active"
    }

    result = await collection.insert_one(user_dict)

    user_response = UserResponseSchema(
        id=str(result.inserted_id),
        name=user.name,
        email=user.email,
        role=assigned_role,
        status="active"
    )

    return {
        "message": "User registered successfully",
        "user": user_response
    }


@router.post(
    "/login",
    response_model=TokenResponseSchema
)
async def login_user(
    user: UserLoginSchema,
    collection=Depends(get_user_collection)
):
    db_user = await collection.find_one({"email": user.email})

    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid credentials"
        )

    if not verify_password(user.password, db_user["password"]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid credentials"
        )

    if db_user.get("status") == "inactive":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account is inactive"
        )

    token = create_access_token({
        "user_id": str(db_user["_id"]),
        "role": db_user.get("role", "employee")
    })

    return {
        "access_token": token,
        "token_type": "bearer"
    }