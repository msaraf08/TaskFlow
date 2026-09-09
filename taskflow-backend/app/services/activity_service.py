from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from app.schemas.activity_schema import sanitize_metadata


from app.utils.object_id import validate_object_id


async def log_activity(
    activity_collection,
    actor_user_id: str,
    action: str,
    entity_type: str,
    entity_id: str,
    task_id: Optional[str] = None,
    project_id: Optional[str] = None,
    team_id: Optional[str] = None,
    metadata: Optional[Dict[str, Any]] = None,
    user_collection=None,
) -> dict:
    doc = {
        "actor_user_id": actor_user_id,
        "action": action,
        "entity_type": entity_type,
        "entity_id": str(entity_id),
        "task_id": str(task_id) if task_id else None,
        "project_id": str(project_id) if project_id else None,
        "team_id": str(team_id) if team_id else None,
        "metadata": sanitize_metadata(metadata),
        "created_at": datetime.now(timezone.utc),
    }
    result = await activity_collection.insert_one(doc)
    doc["id"] = str(result.inserted_id)
    doc["_id"] = str(result.inserted_id)

    if user_collection is not None and actor_user_id:
        try:
            u = await user_collection.find_one(
                {"_id": validate_object_id(actor_user_id)},
                {"_id": 1, "name": 1}
            )
            doc["actor_name"] = u.get("name", "Unknown User") if u else "Unknown User"
        except Exception:
            doc["actor_name"] = "Unknown User"
    else:
        doc["actor_name"] = "Unknown User"

    return doc


async def get_activities_by_filter(
    activity_collection,
    filter_query: dict,
    skip: int = 0,
    limit: int = 20,
    user_collection=None,
) -> List[dict]:
    activities = []
    cursor = (
        activity_collection.find(filter_query)
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    )
    async for act in cursor:
        act["id"] = str(act["_id"])
        act["_id"] = str(act["_id"])
        activities.append(act)

    if user_collection is not None and activities:
        user_ids = {act["actor_user_id"] for act in activities if act.get("actor_user_id")}
        user_obj_ids = []
        for uid in user_ids:
            try:
                user_obj_ids.append(validate_object_id(uid))
            except Exception:
                pass

        name_map = {}
        if user_obj_ids:
            u_cursor = user_collection.find(
                {"_id": {"$in": user_obj_ids}},
                {"_id": 1, "name": 1}
            )
            async for u in u_cursor:
                name_map[str(u["_id"])] = u.get("name", "Unknown User")

        for act in activities:
            actor_uid = act.get("actor_user_id")
            act["actor_name"] = name_map.get(actor_uid, "Unknown User") if actor_uid else "Unknown User"
    else:
        for act in activities:
            if "actor_name" not in act:
                act["actor_name"] = "Unknown User"

    return activities
