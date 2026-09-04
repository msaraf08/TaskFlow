from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from app.core.dependencies import get_current_user
from app.core.roles import require_roles
from app.database.dependencies import (
    get_project_collection,
    get_team_collection,
    get_employee_collection
)
from app.schemas.project_schema import (
    ProjectCreateSchema,
    ProjectUpdateSchema,
    ProjectResponseSchema
)
from app.services.project_service import (
    create_project,
    get_all_projects,
    get_projects_by_team_ids,
    get_project_by_id,
    update_project,
    delete_project,
    validate_team_exists
)

router = APIRouter(prefix="/projects", tags=["Projects"])


async def check_team_management_permission(
    team_id: str,
    current_user: dict,
    team_collection,
    employee_collection
) -> dict:
    team = await validate_team_exists(team_collection, team_id)

    if current_user.get("role") == "admin":
        return team

    if current_user.get("role") == "manager":
        emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
        if emp and emp.get("status") == "active" and team.get("manager_id") == str(emp["_id"]):
            return team

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="You do not have permission to manage projects for this team"
    )


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    response_model=ProjectResponseSchema
)
async def add_project(
    project: ProjectCreateSchema,
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(require_roles("admin", "manager")),
):
    await check_team_management_permission(
        project.team_id,
        current_user,
        team_collection,
        employee_collection
    )

    return await create_project(
        project_collection,
        team_collection,
        project,
        current_user["user_id"]
    )


@router.get(
    "/",
    response_model=List[ProjectResponseSchema]
)
async def list_projects(
    team_id: Optional[str] = Query(None),
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(get_current_user),
):
    role = current_user.get("role")

    if role == "admin":
        return await get_all_projects(project_collection, team_id=team_id)

    emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
    if not emp:
        return []

    emp_id = str(emp["_id"])

    if role == "manager":
        cursor = team_collection.find({"manager_id": emp_id})
        managed_team_ids = []
        async for t in cursor:
            managed_team_ids.append(str(t["_id"]))

        if not managed_team_ids:
            return []

        if team_id:
            if team_id not in managed_team_ids:
                return []
            return await get_all_projects(project_collection, team_id=team_id)

        return await get_projects_by_team_ids(project_collection, managed_team_ids)

    # Regular employee: projects belonging to teams where in team.member_ids
    cursor = team_collection.find({"member_ids": emp_id})
    member_team_ids = []
    async for t in cursor:
        member_team_ids.append(str(t["_id"]))

    if not member_team_ids:
        return []

    if team_id:
        if team_id not in member_team_ids:
            return []
        return await get_all_projects(project_collection, team_id=team_id)

    return await get_projects_by_team_ids(project_collection, member_team_ids)


@router.get(
    "/{project_id}",
    response_model=ProjectResponseSchema
)
async def get_project(
    project_id: str,
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(get_current_user),
):
    project = await get_project_by_id(project_collection, project_id)
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found"
        )

    role = current_user.get("role")
    if role == "admin":
        return project

    team = await team_collection.find_one({"_id": project.get("team_id")})
    # If not found by string id, try with validate_object_id if needed
    if not team:
        try:
            from app.utils.object_id import validate_object_id
            team = await team_collection.find_one({"_id": validate_object_id(project.get("team_id"))})
        except Exception:
            team = None

    if not team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Referenced team not found"
        )

    emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
    if not emp:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this project"
        )

    emp_id = str(emp["_id"])

    if role == "manager":
        if team.get("manager_id") != emp_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to view this project"
            )
        return project

    # Regular employee
    if emp_id not in team.get("member_ids", []):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this project"
        )

    return project


@router.put(
    "/{project_id}",
    response_model=ProjectResponseSchema
)
async def edit_project(
    project_id: str,
    project: ProjectUpdateSchema,
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(get_current_user),
):
    if current_user.get("role") not in ["admin", "manager"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to perform this action"
        )

    existing_project = await get_project_by_id(project_collection, project_id)
    if not existing_project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found"
        )

    # Verify authorization for current project's team
    await check_team_management_permission(
        existing_project["team_id"],
        current_user,
        team_collection,
        employee_collection
    )

    # If team_id is changed, verify authorization for new target team as well
    if project.team_id and project.team_id != existing_project["team_id"]:
        await check_team_management_permission(
            project.team_id,
            current_user,
            team_collection,
            employee_collection
        )

    return await update_project(
        project_collection,
        team_collection,
        project_id,
        project,
        existing_project
    )


@router.delete(
    "/{project_id}",
    status_code=status.HTTP_204_NO_CONTENT
)
async def remove_project(
    project_id: str,
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(get_current_user),
):
    if current_user.get("role") not in ["admin", "manager"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to perform this action"
        )

    existing_project = await get_project_by_id(project_collection, project_id)
    if not existing_project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found"
        )

    await check_team_management_permission(
        existing_project["team_id"],
        current_user,
        team_collection,
        employee_collection
    )

    await delete_project(project_collection, project_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
