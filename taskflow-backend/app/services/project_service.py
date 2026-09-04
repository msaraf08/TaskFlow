from datetime import date, datetime, time, timezone
from typing import Any, Dict, List, Optional
from fastapi import HTTPException, status

from app.utils.object_id import validate_object_id
from app.schemas.project_schema import ProjectCreateSchema, ProjectUpdateSchema


async def validate_team_exists(team_collection, team_id: str) -> dict:
    obj_id = validate_object_id(team_id)
    team = await team_collection.find_one({"_id": obj_id})
    if not team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Referenced team not found"
        )
    return team


def _to_date(val: Any) -> Optional[date]:
    if val is None:
        return None
    if isinstance(val, datetime):
        return val.date()
    if isinstance(val, date):
        return val
    return None


async def create_project(
    project_collection,
    team_collection,
    project_data: ProjectCreateSchema,
    user_id: str
) -> dict:
    await validate_team_exists(team_collection, project_data.team_id)

    doc = project_data.model_dump()
    now = datetime.now(timezone.utc)

    if doc.get("start_date"):
        doc["start_date"] = datetime.combine(doc["start_date"], time.min)
    if doc.get("end_date"):
        doc["end_date"] = datetime.combine(doc["end_date"], time.min)

    doc["created_by"] = user_id
    doc["created_at"] = now
    doc["updated_at"] = now

    result = await project_collection.insert_one(doc)
    doc["id"] = str(result.inserted_id)
    doc["_id"] = str(result.inserted_id)
    return doc


async def get_all_projects(project_collection, team_id: Optional[str] = None) -> List[dict]:
    query: Dict[str, Any] = {}
    if team_id:
        query["team_id"] = team_id

    projects = []
    cursor = project_collection.find(query).sort("created_at", -1)
    async for project in cursor:
        project["id"] = str(project["_id"])
        project["_id"] = str(project["_id"])
        projects.append(project)
    return projects


async def get_projects_by_team_ids(project_collection, team_ids: List[str]) -> List[dict]:
    if not team_ids:
        return []

    query = {"team_id": {"$in": team_ids}}
    projects = []
    cursor = project_collection.find(query).sort("created_at", -1)
    async for project in cursor:
        project["id"] = str(project["_id"])
        project["_id"] = str(project["_id"])
        projects.append(project)
    return projects


async def get_project_by_id(project_collection, project_id: str) -> Optional[dict]:
    obj_id = validate_object_id(project_id)
    project = await project_collection.find_one({"_id": obj_id})
    if project:
        project["id"] = str(project["_id"])
        project["_id"] = str(project["_id"])
    return project


async def update_project(
    project_collection,
    team_collection,
    project_id: str,
    project_data: ProjectUpdateSchema,
    existing_project: dict
) -> dict:
    obj_id = validate_object_id(project_id)
    update_data = {
        key: value
        for key, value in project_data.model_dump().items()
        if value is not None
    }

    if not update_data:
        return existing_project

    if "team_id" in update_data:
        await validate_team_exists(team_collection, update_data["team_id"])

    # Validate merged date range
    merged_start = update_data.get("start_date") or _to_date(existing_project.get("start_date"))
    merged_end = update_data.get("end_date") or _to_date(existing_project.get("end_date"))

    if merged_start and merged_end and merged_end < merged_start:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="end_date must not be earlier than start_date"
        )

    if update_data.get("start_date"):
        update_data["start_date"] = datetime.combine(update_data["start_date"], time.min)
    if update_data.get("end_date"):
        update_data["end_date"] = datetime.combine(update_data["end_date"], time.min)

    update_data["updated_at"] = datetime.now(timezone.utc)

    await project_collection.update_one(
        {"_id": obj_id},
        {"$set": update_data}
    )

    updated = await get_project_by_id(project_collection, project_id)
    return updated or existing_project


async def delete_project(project_collection, project_id: str) -> bool:
    obj_id = validate_object_id(project_id)
    result = await project_collection.delete_one({"_id": obj_id})
    return result.deleted_count > 0
