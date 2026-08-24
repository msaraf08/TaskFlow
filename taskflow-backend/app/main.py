from fastapi import FastAPI

from app.config.settings import settings
from app.database.mongodb import db
from app.database.redis import redis_manager
from app.routes.health import router as health_router
from app.routes.auth import router as auth_router
from app.routes.employees import router as employee_router


app = FastAPI(
    title=settings.app_name,
    version="1.0.0"
)
app.include_router(health_router)
app.include_router(auth_router)
app.include_router(employee_router)


@app.on_event("startup")
async def startup_event():
    await db.connect()
    await redis_manager.connect()


@app.on_event("shutdown")
async def shutdown_event():
    await redis_manager.disconnect()
    await db.disconnect()


