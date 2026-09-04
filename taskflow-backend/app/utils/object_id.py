from bson import ObjectId
from bson.errors import InvalidId
from fastapi import HTTPException, status


def validate_object_id(id_str: str) -> ObjectId:
    if not id_str or not ObjectId.is_valid(id_str):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid ID format"
        )
    try:
        return ObjectId(id_str)
    except (InvalidId, TypeError):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid ID format"
        )
