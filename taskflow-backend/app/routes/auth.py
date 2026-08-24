from fastapi import APIRouter, Depends, HTTPException
from app.schemas.user_schema import UserCreateSchema, UserLoginSchema
from app.database.dependencies import get_user_collection
from app.core.security import hash_password, verify_password
from app.core.jwt import create_access_token

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/register")
async def register_user(user: UserCreateSchema, collection=Depends(get_user_collection)):
    existing = await collection.find_one({"email": user.email})

    if existing:
        raise HTTPException(status_code=400, detail="User already exists")

    user_dict = user.dict()
    user_dict["password"] = hash_password(user.password)

    await collection.insert_one(user_dict)

    return {"message": "User registered successfully"}


@router.post("/login")
async def login_user(user: UserLoginSchema, collection=Depends(get_user_collection)):
    db_user = await collection.find_one({"email": user.email})

    if not db_user:
        raise HTTPException(status_code=400, detail="Invalid credentials")

    if not verify_password(user.password, db_user["password"]):
        raise HTTPException(status_code=400, detail="Invalid credentials")

    token = create_access_token({
        "user_id": str(db_user["_id"]),
        "role": db_user["role"]
    })

    return {
        "access_token": token,
        "token_type": "bearer"
    }