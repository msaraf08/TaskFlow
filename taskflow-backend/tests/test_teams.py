import pytest
from app.core.jwt import create_access_token
from app.core.security import hash_password


@pytest.fixture
async def admin_auth(mock_users_collection):
    res = await mock_users_collection.insert_one({
        "name": "Team Admin",
        "email": "teamadmin@example.com",
        "password": hash_password("AdminPass123"),
        "role": "admin",
        "status": "active"
    })
    token = create_access_token({"user_id": str(res.inserted_id), "role": "admin"})
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_team_crud_and_validation(client, admin_auth):
    headers = admin_auth

    # Create team
    create_resp = await client.post(
        "/teams/",
        headers=headers,
        json={
            "name": "Frontend Guild",
            "description": "Team focusing on UI/UX"
        }
    )
    assert create_resp.status_code == 201
    team_data = create_resp.json()
    assert team_data["name"] == "Frontend Guild"
    assert team_data["description"] == "Team focusing on UI/UX"
    assert "id" in team_data
    team_id = team_data["id"]

    # List teams
    list_resp = await client.get("/teams/", headers=headers)
    assert list_resp.status_code == 200
    teams_list = list_resp.json()
    assert len(teams_list) == 1
    assert teams_list[0]["id"] == team_id

    # Get team by valid ID
    get_resp = await client.get(f"/teams/{team_id}", headers=headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["id"] == team_id

    # Invalid ObjectId on GET team
    bad_id_resp = await client.get("/teams/invalid-team-id", headers=headers)
    assert bad_id_resp.status_code == 400
    assert "Invalid ID format" in bad_id_resp.json()["detail"]
