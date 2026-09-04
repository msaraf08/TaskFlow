from typing import List, Optional
from app.utils.object_id import validate_object_id


async def create_team(collection, team_data) -> dict:
    team = team_data.model_dump()
    team["member_ids"] = []

    result = await collection.insert_one(team)
    team["id"] = str(result.inserted_id)
    team["_id"] = str(result.inserted_id)

    return team


async def get_all_teams(collection) -> List[dict]:
    teams = []
    async for team in collection.find():
        team["id"] = str(team["_id"])
        team["_id"] = str(team["_id"])
        teams.append(team)
    return teams


async def get_team_by_id(collection, team_id: str) -> Optional[dict]:
    obj_id = validate_object_id(team_id)
    team = await collection.find_one({"_id": obj_id})

    if team:
        team["id"] = str(team["_id"])
        team["_id"] = str(team["_id"])

    return team
