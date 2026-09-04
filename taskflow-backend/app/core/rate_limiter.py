import logging
from typing import Callable
from fastapi import HTTPException, Request, status

from app.database.redis import redis_manager

logger = logging.getLogger("taskflow.ratelimit")


def rate_limit(
    endpoint_name: str,
    max_requests: int = 5,
    window_seconds: int = 60
) -> Callable:
    async def dependency(request: Request) -> None:
        if not redis_manager.client:
            return

        client_ip = "unknown"
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            client_ip = forwarded_for.split(",")[0].strip()
        elif request.client and request.client.host:
            client_ip = request.client.host

        key = f"ratelimit:{endpoint_name}:{client_ip}"

        try:
            current_count = await redis_manager.client.incr(key)
            if current_count == 1:
                await redis_manager.client.expire(key, window_seconds)

            if current_count > max_requests:
                ttl = await redis_manager.client.ttl(key)
                retry_after = str(max(ttl, 1)) if (ttl is not None and ttl > 0) else str(window_seconds)
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Too many requests",
                    headers={"Retry-After": retry_after}
                )
        except HTTPException:
            raise
        except Exception as exc:
            logger.warning(
                "Rate limiter failed for key '%s'; operating in fail-open mode: %s",
                key,
                str(exc)
            )
            return

    return dependency
