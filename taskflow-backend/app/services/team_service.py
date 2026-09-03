from bson import ObjectId


async def create_team(collection, team_data):
    team = team_data.model_dump()

    team["member_ids"] = []

    result = await collection.insert_one(team)

    team["_id"] = str(result.inserted_id)

    return team


async def get_all_teams(collection):
    teams = []

    async for team in collection.find():
        team["_id"] = str(team["_id"])
        teams.append(team)

    return teams


async def get_team_by_id(collection, team_id: str):
    team = await collection.find_one({"_id": ObjectId(team_id)})

    if team:
        team["_id"] = str(team["_id"])

    return team
