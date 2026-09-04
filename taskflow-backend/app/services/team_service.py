from typing import List, Optional
from fastapi import HTTPException, status
from app.utils.object_id import validate_object_id
from app.schemas.team_schema import TeamCreateSchema, TeamUpdateSchema


async def validate_manager(employee_collection, manager_id: str) -> dict:
    obj_id = validate_object_id(manager_id)
    manager = await employee_collection.find_one({"_id": obj_id})

    if not manager:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Assigned manager not found"
        )

    if manager.get("status") == "inactive":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Assigned manager account is inactive"
        )

    if manager.get("role") not in ["manager", "admin"]:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Assigned manager must have manager or admin role"
        )

    return manager


async def create_team(team_collection, employee_collection, team_data: TeamCreateSchema) -> dict:
    if team_data.manager_id:
        await validate_manager(employee_collection, team_data.manager_id)

    team = team_data.model_dump()
    team["member_ids"] = []

    result = await team_collection.insert_one(team)
    team["id"] = str(result.inserted_id)
    team["_id"] = str(result.inserted_id)

    return team


async def get_all_teams(team_collection) -> List[dict]:
    teams = []
    async for team in team_collection.find():
        team["id"] = str(team["_id"])
        team["_id"] = str(team["_id"])
        teams.append(team)
    return teams


async def get_teams_for_employee(team_collection, employee_id: str) -> List[dict]:
    teams = []
    async for team in team_collection.find({"member_ids": employee_id}):
        team["id"] = str(team["_id"])
        team["_id"] = str(team["_id"])
        teams.append(team)
    return teams


async def get_team_by_id(team_collection, team_id: str) -> Optional[dict]:
    obj_id = validate_object_id(team_id)
    team = await team_collection.find_one({"_id": obj_id})

    if team:
        team["id"] = str(team["_id"])
        team["_id"] = str(team["_id"])

    return team


async def update_team(
    team_collection,
    employee_collection,
    team_id: str,
    team_data: TeamUpdateSchema
) -> Optional[dict]:
    obj_id = validate_object_id(team_id)
    team = await team_collection.find_one({"_id": obj_id})

    if not team:
        return None

    update_data = {
        key: value
        for key, value in team_data.model_dump(exclude_unset=True).items()
        if value is not None and key != "member_ids"
    }

    if "manager_id" in update_data and update_data["manager_id"] is not None:
        await validate_manager(employee_collection, update_data["manager_id"])

    if update_data:
        await team_collection.update_one(
            {"_id": obj_id},
            {"$set": update_data}
        )

    return await get_team_by_id(team_collection, team_id)


async def delete_team(team_collection, team_id: str) -> bool:
    obj_id = validate_object_id(team_id)
    result = await team_collection.delete_one({"_id": obj_id})
    return result.deleted_count > 0


async def add_team_member(
    team_collection,
    employee_collection,
    team_id: str,
    employee_id: str
) -> dict:
    team_obj_id = validate_object_id(team_id)
    emp_obj_id = validate_object_id(employee_id)

    team = await team_collection.find_one({"_id": team_obj_id})
    if not team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team not found"
        )

    employee = await employee_collection.find_one({"_id": emp_obj_id})
    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )

    if employee.get("status") == "inactive":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Employee account is inactive"
        )

    if str(employee["_id"]) == team.get("manager_id"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Manager cannot be added to team member_ids"
        )

    if str(employee["_id"]) in team.get("member_ids", []):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Employee is already a member of this team"
        )

    await team_collection.update_one(
        {"_id": team_obj_id},
        {"$addToSet": {"member_ids": str(employee["_id"])}}
    )

    return await get_team_by_id(team_collection, team_id)


async def remove_team_member(
    team_collection,
    team_id: str,
    employee_id: str
) -> bool:
    team_obj_id = validate_object_id(team_id)
    emp_obj_id = validate_object_id(employee_id)

    team = await team_collection.find_one({"_id": team_obj_id})
    if not team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team not found"
        )

    if str(emp_obj_id) not in team.get("member_ids", []):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee is not a member of this team"
        )

    await team_collection.update_one(
        {"_id": team_obj_id},
        {"$pull": {"member_ids": str(emp_obj_id)}}
    )

    return True
