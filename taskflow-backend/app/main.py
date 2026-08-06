from fastapi import FastAPI
from app.config.settings import settings
from app.database.mongodb import db
from app.database.redis import redis_manager

app = FastAPI(
    title=settings.app_name,
    version="1.0.0"
)


@app.on_event("startup")
async def startup_event():
    await db.connect()
    await redis_manager.connect()


@app.on_event("shutdown")
async def shutdown_event():
    await redis_manager.disconnect()
    await db.disconnect()


@app.get("/")
async def root():
    return {
        "message": f"Welcome to {settings.app_name}🚀"
    }


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "environment": settings.app_env
    }