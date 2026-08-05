from app.database.mongodb import db


async def get_database():
    return db.database