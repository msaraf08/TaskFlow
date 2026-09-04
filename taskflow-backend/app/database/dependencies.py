from app.database.mongodb import db


async def get_database():
    return db.database


async def get_user_collection():
    return db.database["users"]


async def get_employee_collection():
    return db.database["employees"]


async def get_team_collection():
    return db.database["teams"]


async def get_project_collection():
    return db.database["projects"]
