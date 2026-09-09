from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config.settings import settings
from app.database.mongodb import db
from app.database.redis import redis_manager
from app.routes.health import router as health_router
from app.routes.auth import router as auth_router
from app.routes.employees import router as employee_router
from app.routes.teams import router as team_router
from app.routes.projects import router as project_router
from app.routes.tasks import router as task_router
from app.routes.comments import router as comment_router
from app.routes.activities import router as activity_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.connect()
    await db.init_indexes()
    await redis_manager.connect()
    yield
    await redis_manager.disconnect()
    await db.disconnect()


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=settings.cors_origin_regex,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["Content-Type", "Authorization", "Accept", "Origin", "X-Requested-With"],
)

app.include_router(health_router)
app.include_router(auth_router)
app.include_router(employee_router)
app.include_router(team_router)
app.include_router(project_router)
app.include_router(task_router)
app.include_router(comment_router)
app.include_router(activity_router)
