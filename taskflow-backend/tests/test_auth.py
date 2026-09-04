import pytest
from app.core.security import hash_password
from app.core.jwt import create_access_token


@pytest.mark.asyncio
async def test_public_registration_bootstrap_and_role_security(client):
    # 1. First user registers -> bootstrapped as admin
    resp1 = await client.post(
        "/auth/register",
        json={
            "name": "First Admin",
            "email": "admin@example.com",
            "password": "Password123"
        }
    )
    assert resp1.status_code == 201
    data1 = resp1.json()
    assert data1["user"]["role"] == "admin"
    assert "password" not in data1["user"]
    assert "password" not in data1

    # 2. Second user registers -> forced to employee role
    resp2 = await client.post(
        "/auth/register",
        json={
            "name": "Regular Employee",
            "email": "employee@example.com",
            "password": "Password123"
        }
    )
    assert resp2.status_code == 201
    data2 = resp2.json()
    assert data2["user"]["role"] == "employee"

    # 3. Duplicate email registration fails
    resp3 = await client.post(
        "/auth/register",
        json={
            "name": "Duplicate User",
            "email": "employee@example.com",
            "password": "Password123"
        }
    )
    assert resp3.status_code == 400
    assert "already exists" in resp3.json()["detail"]


@pytest.mark.asyncio
async def test_login_flow_and_token(client):
    # Register user
    await client.post(
        "/auth/register",
        json={
            "name": "Auth User",
            "email": "auth@example.com",
            "password": "SecretPassword123"
        }
    )

    # Valid login
    login_resp = await client.post(
        "/auth/login",
        json={
            "email": "auth@example.com",
            "password": "SecretPassword123"
        }
    )
    assert login_resp.status_code == 200
    token_data = login_resp.json()
    assert "access_token" in token_data
    assert token_data["token_type"] == "bearer"
    assert "password" not in token_data

    # Invalid password
    bad_resp = await client.post(
        "/auth/login",
        json={
            "email": "auth@example.com",
            "password": "WrongPassword"
        }
    )
    assert bad_resp.status_code == 400

    # Non-existent email
    not_found_resp = await client.post(
        "/auth/login",
        json={
            "email": "ghost@example.com",
            "password": "SecretPassword123"
        }
    )
    assert not_found_resp.status_code == 400


@pytest.mark.asyncio
async def test_inactive_user_cannot_authenticate_or_access_protected(client, mock_users_collection):
    # Insert inactive user into database
    insert_res = await mock_users_collection.insert_one({
        "name": "Inactive User",
        "email": "inactive@example.com",
        "password": hash_password("Password123"),
        "role": "employee",
        "status": "inactive"
    })
    user_id = str(insert_res.inserted_id)

    # Inactive user cannot login
    login_resp = await client.post(
        "/auth/login",
        json={
            "email": "inactive@example.com",
            "password": "Password123"
        }
    )
    assert login_resp.status_code == 401
    assert "inactive" in login_resp.json()["detail"]

    # Inactive user holding a valid JWT cannot access protected route
    token = create_access_token({"user_id": user_id, "role": "employee"})
    protected_resp = await client.get(
        "/protected",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert protected_resp.status_code == 401
    assert "inactive" in protected_resp.json()["detail"]
