import redis.asyncio as redis

from app.config.settings import settings


class RedisManager:
    client = None

    async def connect(self):
        self.client = redis.from_url(
            settings.redis_url,
            decode_responses=True,
            protocol=2 # Fix for Redis 7 compatibility with redis-py 5.x
        )

        await self.client.ping()

        print("✅ Redis Connected")

    async def disconnect(self):
        if self.client:
            await self.client.close()
            print("❌ Redis Disconnected")


redis_manager = RedisManager()