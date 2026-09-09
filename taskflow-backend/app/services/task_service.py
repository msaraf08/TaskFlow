from datetime import datetime, time, timezone
from typing import Any, Dict, List, Optional, Tuple
from fastapi import HTTPException, status

from app.utils.object_id import validate_object_id
from app.schemas.task_schema import TaskCreateSchema, TaskUpdateSchema


async def validate_project_and_team(
    project_collection,
    team_collection,
    project_id: str
) -> Tuple[dict, dict]:
    project_obj_id = validate_object_id(project_id)
    project = await project_collection.find_one({"_id": project_obj_id})
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Referenced project not found"
        )

    team_id_raw = project.get("team_id")
    team_obj_id = validate_object_id(team_id_raw)
    team = await team_collection.find_one({"_id": team_obj_id})
    if not team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Referenced team not found"
        )

    return project, team


async def validate_assignee_eligibility(
    employee_collection,
    team: dict,
    employee_id: str
) -> dict:
    emp_obj_id = validate_object_id(employee_id)
    employee = await employee_collection.find_one({"_id": emp_obj_id})
    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Assigned employee not found"
        )

    if employee.get("status") == "inactive":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Assigned employee account is inactive"
        )

    emp_id_str = str(employee["_id"])
    team_manager_id = team.get("manager_id")
    team_member_ids = team.get("member_ids", [])

    is_eligible = (emp_id_str == team_manager_id) or (emp_id_str in team_member_ids)
    if not is_eligible:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Employee is not eligible for the project team"
        )

    return employee


async def enrich_task_assignee_name(
    tasks: List[dict],
    employee_collection,
    user_collection=None,
) -> None:
    if not tasks:
        return
    emp_ids = {t["assigned_to"] for t in tasks if t.get("assigned_to")}
    emp_obj_ids = []
    for eid in emp_ids:
        try:
            emp_obj_ids.append(validate_object_id(eid))
        except Exception:
            pass

    emp_name_map = {}
    missing_user_ids = {}
    if emp_obj_ids and employee_collection is not None:
        cursor = employee_collection.find(
            {"_id": {"$in": emp_obj_ids}},
            {"_id": 1, "name": 1, "user_id": 1}
        )
        async for emp in cursor:
            e_id_str = str(emp["_id"])
            if emp.get("name"):
                emp_name_map[e_id_str] = emp["name"]
            elif emp.get("user_id") and user_collection is not None:
                missing_user_ids[e_id_str] = emp["user_id"]

    if missing_user_ids and user_collection is not None:
        user_obj_ids = []
        for uid in missing_user_ids.values():
            try:
                user_obj_ids.append(validate_object_id(uid))
            except Exception:
                pass
        if user_obj_ids:
            u_map = {}
            u_cursor = user_collection.find(
                {"_id": {"$in": user_obj_ids}},
                {"_id": 1, "name": 1}
            )
            async for u in u_cursor:
                u_map[str(u["_id"])] = u.get("name", "Unknown User")
            for eid, uid in missing_user_ids.items():
                emp_name_map[eid] = u_map.get(str(uid), "Unknown User")

    for t in tasks:
        assignee_id = t.get("assigned_to")
        if not assignee_id:
            t["assignee_name"] = None
        else:
            t["assignee_name"] = emp_name_map.get(assignee_id, "Unknown User")


async def create_task(
    task_collection,
    project_collection,
    team_collection,
    employee_collection,
    task_data: TaskCreateSchema,
    user_id: str,
    user_collection=None,
) -> dict:
    _, team = await validate_project_and_team(
        project_collection,
        team_collection,
        task_data.project_id
    )

    await validate_assignee_eligibility(
        employee_collection,
        team,
        task_data.assigned_to
    )

    doc = task_data.model_dump()
    now = datetime.now(timezone.utc)

    if doc.get("due_date"):
        doc["due_date"] = datetime.combine(doc["due_date"], time.min)

    doc["created_by"] = user_id
    doc["created_at"] = now
    doc["updated_at"] = now

    result = await task_collection.insert_one(doc)
    doc["id"] = str(result.inserted_id)
    doc["_id"] = str(result.inserted_id)

    await enrich_task_assignee_name([doc], employee_collection, user_collection)
    return doc


async def get_all_tasks(
    task_collection,
    project_id: Optional[str] = None,
    assigned_to: Optional[str] = None,
    employee_collection=None,
    user_collection=None,
) -> List[dict]:
    query: Dict[str, Any] = {}
    if project_id:
        query["project_id"] = project_id
    if assigned_to:
        query["assigned_to"] = assigned_to

    tasks = []
    cursor = task_collection.find(query).sort("created_at", -1)
    async for task in cursor:
        task["id"] = str(task["_id"])
        task["_id"] = str(task["_id"])
        tasks.append(task)

    if employee_collection is not None:
        await enrich_task_assignee_name(tasks, employee_collection, user_collection)
    else:
        for t in tasks:
            t["assignee_name"] = None if not t.get("assigned_to") else "Unknown User"

    return tasks


async def get_tasks_by_filter(
    task_collection,
    filter_query: dict,
    employee_collection=None,
    user_collection=None,
) -> List[dict]:
    tasks = []
    cursor = task_collection.find(filter_query).sort("created_at", -1)
    async for task in cursor:
        task["id"] = str(task["_id"])
        task["_id"] = str(task["_id"])
        tasks.append(task)

    if employee_collection is not None:
        await enrich_task_assignee_name(tasks, employee_collection, user_collection)
    else:
        for t in tasks:
            t["assignee_name"] = None if not t.get("assigned_to") else "Unknown User"

    return tasks


async def get_task_by_id(
    task_collection,
    task_id: str,
    employee_collection=None,
    user_collection=None,
) -> Optional[dict]:
    obj_id = validate_object_id(task_id)
    task = await task_collection.find_one({"_id": obj_id})
    if task:
        task["id"] = str(task["_id"])
        task["_id"] = str(task["_id"])
        if employee_collection is not None:
            await enrich_task_assignee_name([task], employee_collection, user_collection)
        else:
            task["assignee_name"] = None if not task.get("assigned_to") else "Unknown User"
    return task


async def update_task(
    task_collection,
    project_collection,
    team_collection,
    employee_collection,
    task_id: str,
    task_data: TaskUpdateSchema,
    existing_task: dict,
    current_project: dict,
    current_team: dict,
    user_collection=None,
) -> dict:
    obj_id = validate_object_id(task_id)
    update_dict = {
        key: value
        for key, value in task_data.model_dump().items()
        if value is not None
    }

    if not update_dict:
        if employee_collection is not None:
            await enrich_task_assignee_name([existing_task], employee_collection, user_collection)
        return existing_task

    # Determine target project and team
    if "project_id" in update_dict and update_dict["project_id"] != existing_task["project_id"]:
        _, target_team = await validate_project_and_team(
            project_collection,
            team_collection,
            update_dict["project_id"]
        )
    else:
        target_team = current_team

    # Check assignee eligibility
    if "assigned_to" in update_dict:
        await validate_assignee_eligibility(
            employee_collection,
            target_team,
            update_dict["assigned_to"]
        )
    elif "project_id" in update_dict and update_dict["project_id"] != existing_task["project_id"]:
        # Re-validate current assignee against new target team
        current_assignee_id = existing_task["assigned_to"]
        emp_obj_id = validate_object_id(current_assignee_id)
        emp = await employee_collection.find_one({"_id": emp_obj_id})
        emp_id_str = str(emp["_id"]) if emp else current_assignee_id

        team_manager_id = target_team.get("manager_id")
        team_member_ids = target_team.get("member_ids", [])
        is_eligible = (emp_id_str == team_manager_id) or (emp_id_str in team_member_ids)

        if not is_eligible or (emp and emp.get("status") == "inactive"):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Current assigned employee is not eligible for the new project's team"
            )

    if update_dict.get("due_date"):
        update_dict["due_date"] = datetime.combine(update_dict["due_date"], time.min)

    update_dict["updated_at"] = datetime.now(timezone.utc)

    await task_collection.update_one(
        {"_id": obj_id},
        {"$set": update_dict}
    )

    updated = await get_task_by_id(
        task_collection,
        task_id,
        employee_collection=employee_collection,
        user_collection=user_collection,
    )
    return updated or existing_task


async def delete_task(task_collection, task_id: str) -> bool:
    obj_id = validate_object_id(task_id)
    result = await task_collection.delete_one({"_id": obj_id})
    return result.deleted_count > 0
