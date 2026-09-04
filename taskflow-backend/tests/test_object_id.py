from bson import ObjectId
from fastapi import HTTPException
import pytest
from app.utils.object_id import validate_object_id


def test_validate_object_id_valid():
    valid_hex = "507f1f77bcf86cd799439011"
    res = validate_object_id(valid_hex)
    assert isinstance(res, ObjectId)
    assert str(res) == valid_hex


def test_validate_object_id_invalid():
    with pytest.raises(HTTPException) as exc_info:
        validate_object_id("not-a-valid-id")
    assert exc_info.value.status_code == 400
    assert exc_info.value.detail == "Invalid ID format"


def test_validate_object_id_empty():
    with pytest.raises(HTTPException) as exc_info:
        validate_object_id("")
    assert exc_info.value.status_code == 400
