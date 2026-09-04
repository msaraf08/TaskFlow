from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from app.core.dependencies import get_current_user
from app.core.roles import require_roles
from app.database.dependencies import (
    get_task_collection,
    get_project_collection,
    get_team_collection,
    get_employee_collection
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
    validate_project_and_team
)

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

    return await create_task(
        task_collection,
        project_collection,
        team_collection,
        employee_collection,
        task,
        current_user["user_id"]
    )


@router.get(
    "/",
    response_model=List[TaskResponseSchema]
)
async def list_tasks(
    project_id: Optional[str] = Query(None),
    assigned_to: Optional[str] = Query(None),
    task_collection=Depends(get_task_collection),
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(get_current_user),
):
    role = current_user.get("role")

    if role == "admin":
        return await get_all_tasks(task_collection, project_id=project_id, assigned_to=assigned_to)

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

        filter_query: dict = {"project_id": {"$in": managed_project_ids}}
        if project_id:
            if project_id not in managed_project_ids:
                return []
            filter_query["project_id"] = project_id
        if assigned_to:
            filter_query["assigned_to"] = assigned_to

        return await get_tasks_by_filter(task_collection, filter_query)

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
        filter_query = {
            "$or": [
                {"assigned_to": emp_id},
                {"project_id": {"$in": member_project_ids}}
            ]
        }
    else:
        filter_query = {"assigned_to": emp_id}

    if project_id:
        # Check if project is accessible to employee
        if project_id not in member_project_ids:
            filter_query = {"assigned_to": emp_id, "project_id": project_id}
        else:
            filter_query = {"project_id": project_id}

    if assigned_to:
        if assigned_to == emp_id:
            filter_query = {"assigned_to": emp_id}
            if project_id:
                filter_query["project_id"] = project_id
        else:
            # Employee can only view other assignees if within member projects
            if not member_project_ids:
                return []
            filter_query = {
                "assigned_to": assigned_to,
                "project_id": {"$in": member_project_ids}
            }
            if project_id:
                if project_id not in member_project_ids:
                    return []
                filter_query["project_id"] = project_id

    return await get_tasks_by_filter(task_collection, filter_query)


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
    current_user=Depends(get_current_user),
):
    task = await get_task_by_id(task_collection, task_id)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found"
        )

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
    current_user=Depends(get_current_user),
):
    existing_task = await get_task_by_id(task_collection, task_id)
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

    return await update_task(
        task_collection,
        project_collection,
        team_collection,
        employee_collection,
        task_id,
        task,
        existing_task,
        current_project,
        current_team
    )


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
    current_user=Depends(require_roles("admin", "manager")),
):
    existing_task = await get_task_by_id(task_collection, task_id)
    if not existing_task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found"
        )

    if current_user.get("role") == "manager":
        _, current_team = await validate_project_and_team(
            project_collection,
            team_collection,
            existing_task["project_id"]
        )
        emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
        if not emp or current_team.get("manager_id") != str(emp["_id"]):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to delete tasks for this project's team"
            )

    await delete_task(task_collection, task_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
