from datetime import datetime, timezone
from typing import List, Optional
from app.utils.object_id import validate_object_id
from app.schemas.comment_schema import CommentCreateSchema, CommentUpdateSchema


async def create_comment(
    comment_collection,
    task_id: str,
    user_id: str,
    comment_data: CommentCreateSchema,
) -> dict:
    now = datetime.now(timezone.utc)
    doc = {
        "task_id": task_id,
        "user_id": user_id,
        "content": comment_data.content,
        "created_at": now,
        "updated_at": now,
    }
    result = await comment_collection.insert_one(doc)
    doc["id"] = str(result.inserted_id)
    doc["_id"] = str(result.inserted_id)
    return doc


async def get_comments_by_task(
    comment_collection,
    task_id: str,
    skip: int = 0,
    limit: int = 20,
) -> List[dict]:
    comments = []
    cursor = (
        comment_collection.find({"task_id": task_id})
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    )
    async for c in cursor:
        c["id"] = str(c["_id"])
        c["_id"] = str(c["_id"])
        comments.append(c)
    return comments


async def get_comment_by_id(comment_collection, comment_id: str) -> Optional[dict]:
    obj_id = validate_object_id(comment_id)
    comment = await comment_collection.find_one({"_id": obj_id})
    if comment:
        comment["id"] = str(comment["_id"])
        comment["_id"] = str(comment["_id"])
    return comment


async def update_comment(
    comment_collection,
    comment_id: str,
    comment_data: CommentUpdateSchema,
) -> Optional[dict]:
    obj_id = validate_object_id(comment_id)
    now = datetime.now(timezone.utc)
    await comment_collection.update_one(
        {"_id": obj_id},
        {"$set": {"content": comment_data.content, "updated_at": now}}
    )
    return await get_comment_by_id(comment_collection, comment_id)


async def delete_comment(comment_collection, comment_id: str) -> bool:
    obj_id = validate_object_id(comment_id)
    result = await comment_collection.delete_one({"_id": obj_id})
    return result.deleted_count > 0


async def delete_comments_by_task_id(comment_collection, task_id: str) -> int:
    result = await comment_collection.delete_many({"task_id": task_id})
    if hasattr(result, "deleted_count"):
        return result.deleted_count
    return 0
