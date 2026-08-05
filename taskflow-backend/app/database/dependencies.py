from app.database.mongodb import database


async def get_database():
    return database