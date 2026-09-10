import logging
from datetime import datetime, time, timezone
from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, status

from app.schemas.user_schema import (
    UserCreateSchema,
    UserLoginSchema,
    UserPasswordChangeSchema,
    UserRegisterResponseSchema,
    TokenResponseSchema,
    UserResponseSchema,
    PasswordChangeResponseSchema
)
from app.database.dependencies import get_user_collection, get_employee_collection
from app.core.security import hash_password, verify_password
from app.core.jwt import create_access_token
from app.core.dependencies import get_current_user
from app.core.rate_limiter import rate_limit

logger = logging.getLogger("taskflow.auth")

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    response_model=UserRegisterResponseSchema,
    dependencies=[Depends(rate_limit("register"))]
)
async def register_user(
    user: UserCreateSchema,
    collection=Depends(get_user_collection),
    employee_collection=Depends(get_employee_collection),
):
    existing = await collection.find_one({"email": user.email})
    if existing:
        logger.warning(f"Registration rejected: Email {user.email} already exists")
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
    user_id = str(result.inserted_id)

    # Automatically create corresponding employee record
    if employee_collection is not None:
        await employee_collection.insert_one({
            "user_id": user_id,
            "name": user.name,
            "email": user.email,
            "phone": "",
            "department": "Executive" if assigned_role == "admin" else "General",
            "role": assigned_role,
            "joining_date": datetime.combine(datetime.now(timezone.utc).date(), time.min),
            "status": "active"
        })

    user_response = UserResponseSchema(
        id=user_id,
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
    response_model=TokenResponseSchema,
    dependencies=[Depends(rate_limit("login"))]
)
async def login_user(
    user: UserLoginSchema,
    collection=Depends(get_user_collection)
):
    db_user = await collection.find_one({"email": user.email})

    if not db_user:
        logger.warning(f"Login failed: Non-existent user {user.email}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid credentials"
        )

    if not verify_password(user.password, db_user["password"]):
        logger.warning(f"Login failed: Incorrect password for user {user.email}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid credentials"
        )

    if db_user.get("status") == "inactive":
        logger.warning(f"Login rejected: Inactive account {user.email}")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
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


@router.get(
    "/me",
    response_model=UserResponseSchema
)
async def get_current_user_profile(
    current_user: dict = Depends(get_current_user)
):
    return UserResponseSchema(
        id=current_user["user_id"],
        name=current_user["name"],
        email=current_user["email"],
        role=current_user["role"],
        status=current_user["status"]
    )


@router.put(
    "/password",
    response_model=PasswordChangeResponseSchema,
    dependencies=[Depends(rate_limit("password"))]
)
async def change_password(
    data: UserPasswordChangeSchema,
    current_user: dict = Depends(get_current_user),
    collection=Depends(get_user_collection)
):
    user_id = ObjectId(current_user["user_id"])
    db_user = await collection.find_one({"_id": user_id})

    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account no longer exists"
        )

    if not verify_password(data.current_password, db_user["password"]):
        logger.warning(f"Password change failed: Incorrect current password for user {current_user['email']}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect current password"
        )

    new_hashed_password = hash_password(data.new_password)

    # Perform atomic update on password field
    await collection.update_one(
        {"_id": user_id},
        {"$set": {"password": new_hashed_password}}
    )

    logger.info(f"Password changed successfully for user {current_user['email']}")

    return {
        "message": "Password changed successfully"
    }