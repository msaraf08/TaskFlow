from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.dependencies import get_current_user
from app.database.dependencies import (
    get_activity_collection,
    get_task_collection,
    get_project_collection,
    get_team_collection,
    get_employee_collection,
)
from app.schemas.activity_schema import (
    ActivityAction,
    ActivityEntityType,
    ActivityResponseSchema,
)
from app.services.activity_service import get_activities_by_filter
from app.utils.object_id import validate_object_id

router = APIRouter(prefix="/activities", tags=["Activities"])


@router.get(
    "/",
    response_model=List[ActivityResponseSchema],
)
async def list_activities(
    task_id: Optional[str] = Query(None),
    project_id: Optional[str] = Query(None),
    team_id: Optional[str] = Query(None),
    actor_user_id: Optional[str] = Query(None),
    action: Optional[str] = Query(None),
    entity_type: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    activity_collection=Depends(get_activity_collection),
    task_collection=Depends(get_task_collection),
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(get_current_user),
):
    # Validate IDs if provided
    if task_id:
        validate_object_id(task_id)
    if project_id:
        validate_object_id(project_id)
    if team_id:
        validate_object_id(team_id)

    # Validate action and entity_type if provided
    if action and action not in [e.value for e in ActivityAction]:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Invalid action filter '{action}'",
        )

    if entity_type and entity_type not in [e.value for e in ActivityEntityType]:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Invalid entity_type filter '{entity_type}'",
        )

    role = current_user.get("role")
    filter_query: dict = {}

    if action:
        filter_query["action"] = action
    if entity_type:
        filter_query["entity_type"] = entity_type
    if actor_user_id:
        filter_query["actor_user_id"] = actor_user_id

    if role == "admin":
        if task_id:
            filter_query["task_id"] = task_id
        if project_id:
            filter_query["project_id"] = project_id
        if team_id:
            filter_query["team_id"] = team_id

        return await get_activities_by_filter(
            activity_collection,
            filter_query,
            skip=skip,
            limit=limit,
        )

    emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
    if not emp or emp.get("status") == "inactive":
        return []

    emp_id = str(emp["_id"])

    if role == "manager":
        # Find all teams managed by this manager
        cursor = team_collection.find({"manager_id": emp_id})
        managed_team_ids = []
        async for t in cursor:
            managed_team_ids.append(str(t["_id"]))

        if not managed_team_ids:
            return []

        if team_id:
            if team_id not in managed_team_ids:
                return []
            filter_query["team_id"] = team_id
        else:
            filter_query["team_id"] = {"$in": managed_team_ids}

        if project_id:
            filter_query["project_id"] = project_id
        if task_id:
            filter_query["task_id"] = task_id

        return await get_activities_by_filter(
            activity_collection,
            filter_query,
            skip=skip,
            limit=limit,
        )

    # Role is employee: visible tasks only
    cursor = team_collection.find({"member_ids": emp_id})
    member_team_ids = []
    async for t in cursor:
        member_team_ids.append(str(t["_id"]))

    member_project_ids = []
    if member_team_ids:
        p_cursor = project_collection.find({"team_id": {"$in": member_team_ids}})
        async for p in p_cursor:
            member_project_ids.append(str(p["_id"]))

    # Find tasks assigned to employee OR in member projects
    if member_project_ids:
        t_filter = {
            "$or": [
                {"assigned_to": emp_id},
                {"project_id": {"$in": member_project_ids}},
            ]
        }
    else:
        t_filter = {"assigned_to": emp_id}

    t_cursor = task_collection.find(t_filter)
    visible_task_ids = []
    async for t in t_cursor:
        visible_task_ids.append(str(t["_id"]))

    if not visible_task_ids:
        return []

    if task_id:
        if task_id not in visible_task_ids:
            return []
        filter_query["task_id"] = task_id
    else:
        filter_query["task_id"] = {"$in": visible_task_ids}

    if project_id:
        filter_query["project_id"] = project_id
    if team_id:
        filter_query["team_id"] = team_id

    return await get_activities_by_filter(
        activity_collection,
        filter_query,
        skip=skip,
        limit=limit,
    )
