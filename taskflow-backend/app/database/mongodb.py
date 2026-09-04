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

    async def init_indexes(self):
        if self.database is not None:
            await self.database["users"].create_index("email", unique=True)
            await self.database["employees"].create_index("email", unique=True)
            await self.database["employees"].create_index("user_id")
            await self.database["teams"].create_index("manager_id")
            print("✅ MongoDB Indexes Initialized")

    async def disconnect(self):
        if self.client:
            self.client.close()
            print("❌ MongoDB Disconnected")


db = Database()