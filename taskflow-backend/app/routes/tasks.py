from datetime import date, datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from app.core.dependencies import get_current_user
from app.core.roles import require_roles
from app.database.dependencies import (
    get_task_collection,
    get_project_collection,
    get_team_collection,
    get_employee_collection,
    get_user_collection,
    get_comment_collection,
    get_activity_collection,
)
from app.schemas.task_schema import (
    TaskCreateSchema,
    TaskUpdateSchema,
    TaskResponseSchema
)
from app.services.task_service import (
    create_task,
    get_all_tasks,
    get_tasks_by_filter,
    get_task_by_id,
    update_task,
    delete_task,
    validate_project_and_team,
    build_task_filter_query,
)
from app.services.activity_service import log_activity
from app.services.comment_service import delete_comments_by_task_id
from app.database.redis import cache_get, cache_set, cache_delete

router = APIRouter(prefix="/tasks", tags=["Tasks"])


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    response_model=TaskResponseSchema
)
async def add_task(
    task: TaskCreateSchema,
    task_collection=Depends(get_task_collection),
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    user_collection=Depends(get_user_collection),
    activity_collection=Depends(get_activity_collection),
    current_user=Depends(require_roles("admin", "manager")),
):
    _, team = await validate_project_and_team(
        project_collection,
        team_collection,
        task.project_id
    )

    if current_user.get("role") == "manager":
        emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
        if not emp or emp.get("status") == "inactive" or team.get("manager_id") != str(emp["_id"]):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to create tasks for this project's team"
            )

    created_task = await create_task(
        task_collection,
        project_collection,
        team_collection,
        employee_collection,
        task,
        current_user["user_id"],
        user_collection=user_collection,
    )

    await log_activity(
        activity_collection=activity_collection,
        actor_user_id=current_user["user_id"],
        action="task_created",
        entity_type="task",
        entity_id=created_task["id"],
        task_id=created_task["id"],
        project_id=created_task["project_id"],
        team_id=str(team["_id"]),
        metadata={"title": created_task.get("title")},
    )

    return created_task


@router.get(
    "/",
    response_model=List[TaskResponseSchema]
)
async def list_tasks(
    project_id: Optional[str] = Query(None),
    assigned_to: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    priority: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    due_date: Optional[str] = Query(None),
    overdue: Optional[bool] = Query(None),
    task_collection=Depends(get_task_collection),
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    user_collection=Depends(get_user_collection),
    current_user=Depends(get_current_user),
):
    role = current_user.get("role")

    user_filters = build_task_filter_query(
        status=status,
        priority=priority,
        search=search,
        due_date=due_date,
        overdue=overdue,
    )
    user_filter_clauses = [user_filters] if user_filters else []

    if role == "admin":
        admin_clauses = []
        if project_id:
            admin_clauses.append({"project_id": project_id})
        if assigned_to:
            admin_clauses.append({"assigned_to": assigned_to})
        admin_clauses.extend(user_filter_clauses)

        if not admin_clauses:
            final_query = {}
        elif len(admin_clauses) == 1:
            final_query = admin_clauses[0]
        else:
            final_query = {"$and": admin_clauses}

        return await get_tasks_by_filter(
            task_collection,
            final_query,
            employee_collection=employee_collection,
            user_collection=user_collection,
        )

    emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
    if not emp:
        return []

    emp_id = str(emp["_id"])

    if role == "manager":
        # Find managed teams
        cursor = team_collection.find({"manager_id": emp_id})
        managed_team_ids = []
        async for t in cursor:
            managed_team_ids.append(str(t["_id"]))

        if not managed_team_ids:
            return []

        # Find projects for managed teams
        p_cursor = project_collection.find({"team_id": {"$in": managed_team_ids}})
        managed_project_ids = []
        async for p in p_cursor:
            managed_project_ids.append(str(p["_id"]))

        if not managed_project_ids:
            return []

        if project_id and project_id not in managed_project_ids:
            return []

        manager_clauses = []
        if project_id:
            manager_clauses.append({"project_id": project_id})
        else:
            manager_clauses.append({"project_id": {"$in": managed_project_ids}})

        if assigned_to:
            manager_clauses.append({"assigned_to": assigned_to})

        manager_clauses.extend(user_filter_clauses)
        final_query = {"$and": manager_clauses} if len(manager_clauses) > 1 else manager_clauses[0]

        return await get_tasks_by_filter(
            task_collection,
            final_query,
            employee_collection=employee_collection,
            user_collection=user_collection,
        )

    # Regular employee: assigned tasks OR tasks belonging to member team projects
    cursor = team_collection.find({"member_ids": emp_id})
    member_team_ids = []
    async for t in cursor:
        member_team_ids.append(str(t["_id"]))

    member_project_ids = []
    if member_team_ids:
        p_cursor = project_collection.find({"team_id": {"$in": member_team_ids}})
        async for p in p_cursor:
            member_project_ids.append(str(p["_id"]))

    if member_project_ids:
        rbac_base = {
            "$or": [
                {"assigned_to": emp_id},
                {"project_id": {"$in": member_project_ids}}
            ]
        }
    else:
        rbac_base = {"assigned_to": emp_id}

    if project_id:
        # Check if project is accessible to employee
        if project_id not in member_project_ids:
            rbac_base = {"assigned_to": emp_id, "project_id": project_id}
        else:
            rbac_base = {"project_id": project_id}

    if assigned_to:
        if assigned_to == emp_id:
            if project_id:
                rbac_base = {"assigned_to": emp_id, "project_id": project_id}
            else:
                rbac_base = {"assigned_to": emp_id}
        else:
            # Employee can only view other assignees if within member projects
            if not member_project_ids:
                return []
            if project_id:
                if project_id not in member_project_ids:
                    return []
                rbac_base = {"assigned_to": assigned_to, "project_id": project_id}
            else:
                rbac_base = {
                    "assigned_to": assigned_to,
                    "project_id": {"$in": member_project_ids}
                }

    emp_clauses = [rbac_base] + user_filter_clauses
    final_query = {"$and": emp_clauses} if len(emp_clauses) > 1 else emp_clauses[0]

    return await get_tasks_by_filter(
        task_collection,
        final_query,
        employee_collection=employee_collection,
        user_collection=user_collection,
    )


@router.get(
    "/{task_id}",
    response_model=TaskResponseSchema
)
async def get_task(
    task_id: str,
    task_collection=Depends(get_task_collection),
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    user_collection=Depends(get_user_collection),
    current_user=Depends(get_current_user),
):
    task = await cache_get(f"task:{task_id}")
    if not task:
        task = await get_task_by_id(
            task_collection,
            task_id,
            employee_collection=employee_collection,
            user_collection=user_collection,
        )
        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Task not found"
            )
        await cache_set(f"task:{task_id}", task, ttl=300)

    role = current_user.get("role")
    if role == "admin":
        return task

    _, team = await validate_project_and_team(
        project_collection,
        team_collection,
        task["project_id"]
    )

    emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
    if not emp:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this task"
        )

    emp_id = str(emp["_id"])

    if role == "manager":
        if team.get("manager_id") != emp_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to view this task"
            )
        return task

    # Regular employee: must be assigned or member of the project's team
    if task.get("assigned_to") == emp_id or emp_id in team.get("member_ids", []):
        return task

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="You do not have permission to view this task"
    )


@router.put(
    "/{task_id}",
    response_model=TaskResponseSchema
)
async def edit_task(
    task_id: str,
    task: TaskUpdateSchema,
    task_collection=Depends(get_task_collection),
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    user_collection=Depends(get_user_collection),
    activity_collection=Depends(get_activity_collection),
    current_user=Depends(get_current_user),
):
    existing_task = await get_task_by_id(
        task_collection,
        task_id,
        employee_collection=employee_collection,
        user_collection=user_collection,
    )
    if not existing_task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found"
        )

    current_project, current_team = await validate_project_and_team(
        project_collection,
        team_collection,
        existing_task["project_id"]
    )

    role = current_user.get("role")
    emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
    if not emp:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to perform this action"
        )

    emp_id = str(emp["_id"])

    if role == "employee":
        if existing_task.get("assigned_to") != emp_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Employees may only update tasks assigned to them"
            )
        # Check if employee attempted to submit project_id or assigned_to
        if task.project_id is not None or task.assigned_to is not None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Employees are not permitted to modify project_id or assigned_to"
            )

    elif role == "manager":
        if current_team.get("manager_id") != emp_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to update tasks for this project's team"
            )

        if task.project_id and task.project_id != existing_task["project_id"]:
            _, target_team = await validate_project_and_team(
                project_collection,
                team_collection,
                task.project_id
            )
            if target_team.get("manager_id") != emp_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="You do not have permission to move tasks to target project's team"
                )

    updated_task = await update_task(
        task_collection,
        project_collection,
        team_collection,
        employee_collection,
        task_id,
        task,
        existing_task,
        current_project,
        current_team,
        user_collection=user_collection,
    )

    update_dict = task.model_dump(exclude_unset=True)

    if update_dict:
        final_team_id = str(current_team["_id"])
        if "project_id" in update_dict and update_dict["project_id"] != existing_task["project_id"]:
            _, final_team = await validate_project_and_team(
                project_collection,
                team_collection,
                update_dict["project_id"]
            )
            final_team_id = str(final_team["_id"])

        task_title = updated_task.get("title", existing_task.get("title"))

        def _is_task_field_changed(field_name: str, old_val, new_val) -> bool:
            if field_name == "due_date":
                def to_date_str(val):
                    if val is None:
                        return None
                    if isinstance(val, (datetime, date)):
                        return val.strftime("%Y-%m-%d")
                    return str(val)[:10]
                return to_date_str(old_val) != to_date_str(new_val)
            elif field_name == "description":
                return (old_val or "") != (new_val or "")
            elif field_name in ("project_id", "assigned_to"):
                return str(old_val or "") != str(new_val or "")
            elif field_name in ("title", "priority", "status"):
                return str(old_val or "").strip() != str(new_val or "").strip()
            return old_val != new_val

        changed_fields = [
            k for k, v in update_dict.items()
            if _is_task_field_changed(k, existing_task.get(k), v)
        ]

        if len(changed_fields) == 1:
            field = changed_fields[0]
            if field == "assigned_to":
                await log_activity(
                    activity_collection=activity_collection,
                    actor_user_id=current_user["user_id"],
                    action="task_assigned_changed",
                    entity_type="task",
                    entity_id=task_id,
                    task_id=task_id,
                    project_id=updated_task.get("project_id"),
                    team_id=final_team_id,
                    metadata={
                        "title": task_title,
                        "old_value": existing_task.get("assigned_to"),
                        "new_value": str(update_dict["assigned_to"]),
                    },
                )
            elif field == "status":
                await log_activity(
                    activity_collection=activity_collection,
                    actor_user_id=current_user["user_id"],
                    action="task_status_changed",
                    entity_type="task",
                    entity_id=task_id,
                    task_id=task_id,
                    project_id=updated_task.get("project_id"),
                    team_id=final_team_id,
                    metadata={
                        "title": task_title,
                        "old_value": existing_task.get("status"),
                        "new_value": str(update_dict["status"]),
                    },
                )
            elif field == "priority":
                await log_activity(
                    activity_collection=activity_collection,
                    actor_user_id=current_user["user_id"],
                    action="task_priority_changed",
                    entity_type="task",
                    entity_id=task_id,
                    task_id=task_id,
                    project_id=updated_task.get("project_id"),
                    team_id=final_team_id,
                    metadata={
                        "title": task_title,
                        "old_value": existing_task.get("priority"),
                        "new_value": str(update_dict["priority"]),
                    },
                )
            elif field == "project_id":
                await log_activity(
                    activity_collection=activity_collection,
                    actor_user_id=current_user["user_id"],
                    action="task_project_changed",
                    entity_type="task",
                    entity_id=task_id,
                    task_id=task_id,
                    project_id=updated_task.get("project_id"),
                    team_id=final_team_id,
                    metadata={
                        "title": task_title,
                        "old_value": existing_task.get("project_id"),
                        "new_value": str(update_dict["project_id"]),
                    },
                )
            else:
                await log_activity(
                    activity_collection=activity_collection,
                    actor_user_id=current_user["user_id"],
                    action="task_updated",
                    entity_type="task",
                    entity_id=task_id,
                    task_id=task_id,
                    project_id=updated_task.get("project_id"),
                    team_id=final_team_id,
                    metadata={"title": task_title},
                )
        elif len(changed_fields) > 1:
            await log_activity(
                activity_collection=activity_collection,
                actor_user_id=current_user["user_id"],
                action="task_updated",
                entity_type="task",
                entity_id=task_id,
                task_id=task_id,
                project_id=updated_task.get("project_id"),
                team_id=final_team_id,
                metadata={"title": task_title},
            )

    await cache_delete(f"task:{task_id}")

    return updated_task


@router.delete(
    "/{task_id}",
    status_code=status.HTTP_204_NO_CONTENT
)
async def remove_task(
    task_id: str,
    task_collection=Depends(get_task_collection),
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    comment_collection=Depends(get_comment_collection),
    activity_collection=Depends(get_activity_collection),
    current_user=Depends(require_roles("admin", "manager")),
):
    existing_task = await get_task_by_id(task_collection, task_id)
    if not existing_task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found"
        )

    _, current_team = await validate_project_and_team(
        project_collection,
        team_collection,
        existing_task["project_id"]
    )

    if current_user.get("role") == "manager":
        emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
        if not emp or current_team.get("manager_id") != str(emp["_id"]):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to delete tasks for this project's team"
            )

    task_title = existing_task.get("title")
    task_project_id = existing_task.get("project_id")
    task_team_id = str(current_team["_id"])

    await delete_task(task_collection, task_id)
    await delete_comments_by_task_id(comment_collection, task_id)
    await cache_delete(f"task:{task_id}")

    await log_activity(
        activity_collection=activity_collection,
        actor_user_id=current_user["user_id"],
        action="task_deleted",
        entity_type="task",
        entity_id=task_id,
        task_id=task_id,
        project_id=task_project_id,
        team_id=task_team_id,
        metadata={"title": task_title},
    )

    return Response(status_code=status.HTTP_204_NO_CONTENT)
