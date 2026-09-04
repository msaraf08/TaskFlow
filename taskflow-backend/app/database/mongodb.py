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
            await self.database["projects"].create_index("team_id")
            await self.database["projects"].create_index("created_by")
            await self.database["projects"].create_index("status")
            await self.database["tasks"].create_index("project_id")
            await self.database["tasks"].create_index("assigned_to")
            await self.database["tasks"].create_index("status")
            await self.database["tasks"].create_index("priority")
            await self.database["tasks"].create_index("due_date")
            await self.database["tasks"].create_index("created_by")
            await self.database["comments"].create_index("task_id")
            await self.database["comments"].create_index("user_id")
            await self.database["comments"].create_index("created_at")
            await self.database["activities"].create_index("actor_user_id")
            await self.database["activities"].create_index([("entity_type", 1), ("entity_id", 1)])
            await self.database["activities"].create_index("task_id")
            await self.database["activities"].create_index("project_id")
            await self.database["activities"].create_index("team_id")
            await self.database["activities"].create_index("created_at")
            print("✅ MongoDB Indexes Initialized")

    async def disconnect(self):
        if self.client:
            self.client.close()
            print("❌ MongoDB Disconnected")


db = Database()