from typing import List
from fastapi import APIRouter, Depends, HTTPException, Response, status

from app.core.dependencies import get_current_user
from app.core.roles import require_roles
from app.database.dependencies import (
    get_team_collection,
    get_employee_collection
)
from app.schemas.team_schema import (
    TeamCreateSchema,
    TeamUpdateSchema,
    TeamMemberAssignSchema,
    TeamResponseSchema
)
from app.services.team_service import (
    create_team,
    get_all_teams,
    get_teams_for_employee,
    get_team_by_id,
    update_team,
    delete_team,
    add_team_member,
    remove_team_member
)
from app.database.redis import cache_get, cache_set, cache_delete

router = APIRouter(prefix="/teams", tags=["Teams"])


async def check_team_management_permission(
    team: dict,
    current_user: dict,
    employee_collection
) -> None:
    if current_user.get("role") == "admin":
        return
    if current_user.get("role") == "manager":
        emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
        if emp and team.get("manager_id") == str(emp["_id"]):
            return
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="You do not have permission to manage this team"
    )


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    response_model=TeamResponseSchema
)
async def add_team(
    team: TeamCreateSchema,
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(require_roles("admin", "manager")),
):
    return await create_team(team_collection, employee_collection, team)


@router.get(
    "/",
    response_model=List[TeamResponseSchema]
)
async def list_teams(
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(get_current_user),
):
    if current_user.get("role") in ["admin", "manager"]:
        return await get_all_teams(team_collection)

    # Regular employee: retrieve teams where employee is in member_ids
    emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
    if not emp:
        return []
    return await get_teams_for_employee(team_collection, str(emp["_id"]))


@router.get(
    "/{team_id}",
    response_model=TeamResponseSchema
)
async def get_team(
    team_id: str,
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(get_current_user),
):
    team = await cache_get(f"team:{team_id}")
    if not team:
        team = await get_team_by_id(team_collection, team_id)
        if not team:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Team not found"
            )
        await cache_set(f"team:{team_id}", team, ttl=300)

    if current_user.get("role") in ["admin", "manager"]:
        return team

    # Regular employee: check membership
    emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
    if not emp or str(emp["_id"]) not in team.get("member_ids", []):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this team"
        )

    return team


@router.put(
    "/{team_id}",
    response_model=TeamResponseSchema
)
async def edit_team(
    team_id: str,
    team: TeamUpdateSchema,
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(get_current_user),
):
    if current_user.get("role") not in ["admin", "manager"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to perform this action"
        )

    existing_team = await get_team_by_id(team_collection, team_id)
    if not existing_team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team not found"
        )

    await check_team_management_permission(existing_team, current_user, employee_collection)

    updated = await update_team(team_collection, employee_collection, team_id, team)
    await cache_delete(f"team:{team_id}")
    return updated


@router.delete(
    "/{team_id}",
    status_code=status.HTTP_204_NO_CONTENT
)
async def remove_team(
    team_id: str,
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(get_current_user),
):
    if current_user.get("role") not in ["admin", "manager"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to perform this action"
        )

    existing_team = await get_team_by_id(team_collection, team_id)
    if not existing_team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team not found"
        )

    await check_team_management_permission(existing_team, current_user, employee_collection)

    await delete_team(team_collection, team_id)
    await cache_delete(f"team:{team_id}")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{team_id}/members",
    response_model=TeamResponseSchema
)
async def assign_team_member(
    team_id: str,
    member_data: TeamMemberAssignSchema,
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(get_current_user),
):
    if current_user.get("role") not in ["admin", "manager"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to perform this action"
        )

    existing_team = await get_team_by_id(team_collection, team_id)
    if not existing_team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team not found"
        )

    await check_team_management_permission(existing_team, current_user, employee_collection)

    result = await add_team_member(
        team_collection,
        employee_collection,
        team_id,
        member_data.employee_id
    )
    await cache_delete(f"team:{team_id}")
    return result


@router.delete(
    "/{team_id}/members/{employee_id}",
    status_code=status.HTTP_204_NO_CONTENT
)
async def unassign_team_member(
    team_id: str,
    employee_id: str,
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(get_current_user),
):
    if current_user.get("role") not in ["admin", "manager"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to perform this action"
        )

    existing_team = await get_team_by_id(team_collection, team_id)
    if not existing_team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team not found"
        )

    await check_team_management_permission(existing_team, current_user, employee_collection)

    await remove_team_member(team_collection, team_id, employee_id)
    await cache_delete(f"team:{team_id}")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
