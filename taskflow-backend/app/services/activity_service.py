from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from app.schemas.activity_schema import sanitize_metadata


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
    return doc


async def get_activities_by_filter(
    activity_collection,
    filter_query: dict,
    skip: int = 0,
    limit: int = 20,
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
    return activities
