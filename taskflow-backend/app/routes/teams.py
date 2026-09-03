from fastapi import APIRouter, Depends, HTTPException, status

from app.core.roles import require_roles
from app.database.dependencies import get_team_collection
from app.schemas.team_schema import TeamCreateSchema
from app.services.team_service import create_team, get_all_teams, get_team_by_id

router = APIRouter(prefix="/teams", tags=["Teams"])


@router.post("/")
async def add_team(
    team: TeamCreateSchema,
    collection=Depends(get_team_collection),
    current_user=Depends(require_roles("admin", "manager")),
):
    return await create_team(collection, team)


@router.get("/")
async def list_teams(
    collection=Depends(get_team_collection),
    current_user=Depends(require_roles("admin", "manager")),
):
    return await get_all_teams(collection)


@router.get("/{team_id}")
async def get_team(
    team_id: str,
    collection=Depends(get_team_collection),
    current_user=Depends(require_roles("admin", "manager")),
):
    team = await get_team_by_id(collection, team_id)

    if not team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Team not found"
        )

    return team
