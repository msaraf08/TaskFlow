from fastapi import APIRouter, Depends

from app.core.dependencies import get_current_user


router = APIRouter(tags=["Health"])


@router.get("/")
async def root():
    return {"message": "Welcome to TaskFlow"}


@router.get("/health")
async def health():
    return {"status": "healthy"}


@router.get("/protected")
async def protected(current_user=Depends(get_current_user)):
    return {
        "message": "You are authenticated",
        "user": current_user
    }


# temparily added for testing purposes
from app.core.roles import require_roles


@router.get("/admin-test")
async def admin_test(
    current_user=Depends(require_roles("admin"))
):
    return {
        "message": "Admin access granted",
        "user": current_user
    }