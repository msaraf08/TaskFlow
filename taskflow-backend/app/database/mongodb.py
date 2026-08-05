from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from app.config.settings import settings


class Database:
    client: AsyncIOMotorClient | None = None
    database: AsyncIOMotorDatabase | None = None

    async def connect(self):
        self.client = AsyncIOMotorClient(settings.mongodb_url)
        self.database = self.client[settings.mongodb_database]
        await self.client.admin.command("ping")
        print("✅ MongoDB Connected")

    async def disconnect(self):
        if self.client:
            self.client.close()
            print("❌ MongoDB Disconnected")


db = Database()