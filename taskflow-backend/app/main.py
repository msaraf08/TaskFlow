from fastapi import FastAPI
from app.config.settings import settings
from app.database.mongodb import db

app = FastAPI(
    title=settings.app_name,
    version="1.0.0"
)


@app.on_event("startup")
async def startup_event():
    await db.connect()


@app.on_event("shutdown")
async def shutdown_event():
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