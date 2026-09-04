from datetime import datetime, timezone
import json
import logging
from typing import Any, Optional
import redis.asyncio as redis

from app.config.settings import settings

logger = logging.getLogger("taskflow.redis")


class CustomJSONEncoder(json.JSONEncoder):
    def default(self, obj: Any) -> Any:
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super().default(obj)


class RedisManager:
    client: Optional[redis.Redis] = None

    async def connect(self) -> None:
        try:
            if settings.redis_host and settings.redis_port:
                self.client = redis.Redis(
                    host=settings.redis_host,
                    port=settings.redis_port,
                    db=settings.redis_db or 0,
                    decode_responses=True,
                    socket_connect_timeout=1.0,
                    socket_timeout=1.0,
                )
            else:
                self.client = redis.from_url(
                    settings.redis_url,
                    decode_responses=True,
                    socket_connect_timeout=1.0,
                    socket_timeout=1.0,
                    protocol=2,
                )

            await self.client.ping()
            logger.info("Redis connected successfully")
        except Exception as exc:
            logger.warning(
                "Redis connection failed; operating in fail-open mode: %s",
                str(exc),
            )
            self.client = None

    async def disconnect(self) -> None:
        if self.client:
            try:
                await self.client.close()
                logger.info("Redis disconnected")
            except Exception as exc:
                logger.warning("Error closing Redis connection: %s", str(exc))
            finally:
                self.client = None

    async def ping(self) -> bool:
        if not self.client:
            return False
        try:
            return bool(await self.client.ping())
        except Exception as exc:
            logger.warning("Redis ping failed: %s", str(exc))
            return False


redis_manager = RedisManager()


async def cache_get(key: str) -> Optional[dict]:
    if not redis_manager.client:
        return None
    try:
        data = await redis_manager.client.get(key)
        if data:
            return json.loads(data)
        return None
    except Exception as exc:
        logger.warning("Redis cache_get failed for key '%s': %s", key, str(exc))
        return None


async def cache_set(key: str, value: dict, ttl: int = 300) -> None:
    if not redis_manager.client:
        return
    try:
        payload = dict(value)
        payload["_cached_at"] = datetime.now(timezone.utc).isoformat()
        serialized = json.dumps(payload, cls=CustomJSONEncoder)
        await redis_manager.client.set(key, serialized, ex=ttl)
    except Exception as exc:
        logger.warning("Redis cache_set failed for key '%s': %s", key, str(exc))


async def cache_delete(key: str) -> None:
    if not redis_manager.client:
        return
    try:
        await redis_manager.client.delete(key)
    except Exception as exc:
        logger.warning("Redis cache_delete failed for key '%s': %s", key, str(exc))


async def cache_delete_pattern(pattern: str) -> None:
    if not redis_manager.client:
        return
    try:
        keys = []
        async for k in redis_manager.client.scan_iter(match=pattern):
            keys.append(k)
        if keys:
            await redis_manager.client.delete(*keys)
    except Exception as exc:
        logger.warning(
            "Redis cache_delete_pattern failed for pattern '%s': %s",
            pattern,
            str(exc),
        )