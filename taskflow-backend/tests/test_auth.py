from datetime import datetime, timedelta, timezone
from jose import jwt
import pytest
from app.config.settings import settings
from app.core.security import hash_password
from app.core.jwt import create_access_token


@pytest.mark.asyncio
async def test_public_registration_bootstrap_and_role_security(client, mock_employees_collection):
    # 1. First user registers -> bootstrapped as admin
    resp1 = await client.post(
        "/auth/register",
        json={
            "name": "  First Admin  ",
            "email": " admin@example.com ",
            "password": "Password123"
        }
    )
    assert resp1.status_code == 201
    data1 = resp1.json()
    assert data1["user"]["role"] == "admin"
    assert data1["user"]["name"] == "First Admin"
    assert data1["user"]["email"] == "admin@example.com"
    assert "password" not in data1["user"]
    assert "password" not in data1

    # Verify first admin employee document
    admin_emp = await mock_employees_collection.find_one({"email": "admin@example.com"})
    assert admin_emp is not None
    assert admin_emp["role"] == "admin"

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

    # Verify second employee document
    emp_doc = await mock_employees_collection.find_one({"email": "employee@example.com"})
    assert emp_doc is not None
    assert emp_doc["name"] == "Regular Employee"
    assert emp_doc["role"] == "employee"

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
async def test_inactive_user_rejected_on_login_and_protected_routes(client, mock_users_collection):
    # Insert inactive user into database
    insert_res = await mock_users_collection.insert_one({
        "name": "Inactive User",
        "email": "inactive@example.com",
        "password": hash_password("Password123"),
        "role": "employee",
        "status": "inactive"
    })
    user_id = str(insert_res.inserted_id)

    # Inactive user cannot login (403 Forbidden)
    login_resp = await client.post(
        "/auth/login",
        json={
            "email": "inactive@example.com",
            "password": "Password123"
        }
    )
    assert login_resp.status_code == 403
    assert "inactive" in login_resp.json()["detail"]

    # Inactive user holding a valid JWT cannot access protected route (403 Forbidden)
    token = create_access_token({"user_id": user_id, "role": "employee"})
    protected_resp = await client.get(
        "/protected",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert protected_resp.status_code == 403
    assert "inactive" in protected_resp.json()["detail"]

    # Inactive user calling GET /auth/me returns 403 Forbidden
    me_resp = await client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert me_resp.status_code == 403
    assert "inactive" in me_resp.json()["detail"]


@pytest.mark.asyncio
async def test_get_current_user_profile(client, mock_users_collection):
    # Create active user
    insert_res = await mock_users_collection.insert_one({
        "name": "Profile User",
        "email": "profile@example.com",
        "password": hash_password("Password123"),
        "role": "employee",
        "status": "active"
    })
    user_id = str(insert_res.inserted_id)
    token = create_access_token({"user_id": user_id, "role": "employee"})

    # 1. Successful GET /auth/me
    resp = await client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == user_id
    assert data["name"] == "Profile User"
    assert data["email"] == "profile@example.com"
    assert data["role"] == "employee"
    assert data["status"] == "active"
    assert "password" not in data

    # 2. Unauthenticated request returns 401
    unauth_resp = await client.get("/auth/me")
    assert unauth_resp.status_code == 401

    # 3. Deleted user with previously issued JWT returns 401
    mock_users_collection.docs.clear()
    deleted_resp = await client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert deleted_resp.status_code == 401
    assert "no longer exists" in deleted_resp.json()["detail"]


@pytest.mark.asyncio
async def test_jwt_token_validation_edge_cases(client):
    # Malformed token
    bad_token_resp = await client.get(
        "/auth/me",
        headers={"Authorization": "Bearer not-a-valid-jwt-token"}
    )
    assert bad_token_resp.status_code == 401

    # Expired token
    expired_payload = {
        "user_id": "507f1f77bcf86cd799439011",
        "role": "employee",
        "exp": datetime.now(timezone.utc) - timedelta(minutes=10)
    }
    expired_token = jwt.encode(
        expired_payload,
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm
    )
    expired_resp = await client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {expired_token}"}
    )
    assert expired_resp.status_code == 401


@pytest.mark.asyncio
async def test_change_password_flow_and_validation(client, mock_users_collection):
    # Insert user
    insert_res = await mock_users_collection.insert_one({
        "name": "Password User",
        "email": "pwduser@example.com",
        "password": hash_password("OldPassword123"),
        "role": "employee",
        "status": "active"
    })
    user_id = str(insert_res.inserted_id)
    token = create_access_token({"user_id": user_id, "role": "employee"})

    # 1. Wrong current password returns 401
    bad_pwd_resp = await client.put(
        "/auth/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "WrongCurrentPassword",
            "new_password": "NewSecretPassword123"
        }
    )
    assert bad_pwd_resp.status_code == 401
    assert "Incorrect current password" in bad_pwd_resp.json()["detail"]

    # 2. Too short new password (< 8 chars) returns 422 Unprocessable Entity
    short_pwd_resp = await client.put(
        "/auth/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "OldPassword123",
            "new_password": "short"
        }
    )
    assert short_pwd_resp.status_code == 422

    # 3. Extra forbidden fields in body return 422
    extra_field_resp = await client.put(
        "/auth/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "OldPassword123",
            "new_password": "NewSecretPassword123",
            "extra_field": "disallowed"
        }
    )
    assert extra_field_resp.status_code == 422

    # 4. Successful password change
    good_resp = await client.put(
        "/auth/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "OldPassword123",
            "new_password": "NewSecretPassword123"
        }
    )
    assert good_resp.status_code == 200
    assert good_resp.json()["message"] == "Password changed successfully"
    assert "password" not in good_resp.json()

    # 5. Old password no longer works for login
    old_login_resp = await client.post(
        "/auth/login",
        json={
            "email": "pwduser@example.com",
            "password": "OldPassword123"
        }
    )
    assert old_login_resp.status_code == 400

    # 6. New password works for login
    new_login_resp = await client.post(
        "/auth/login",
        json={
            "email": "pwduser@example.com",
            "password": "NewSecretPassword123"
        }
    )
    assert new_login_resp.status_code == 200
    assert "access_token" in new_login_resp.json()

    # 7. Existing JWT token still remains valid
    profile_resp = await client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert profile_resp.status_code == 200
    assert profile_resp.json()["email"] == "pwduser@example.com"


@pytest.mark.asyncio
async def test_password_whitespace_exact_preservation(client, mock_users_collection):
    # Passwords with leading/trailing spaces must NOT be trimmed
    exact_password = "  Secret With Spaces 123  "
    await client.post(
        "/auth/register",
        json={
            "name": "Spaces User",
            "email": "spaces@example.com",
            "password": exact_password
        }
    )

    # Login with exact password succeeds
    login_success = await client.post(
        "/auth/login",
        json={
            "email": "spaces@example.com",
            "password": exact_password
        }
    )
    assert login_success.status_code == 200

    # Login with trimmed password fails
    login_fail = await client.post(
        "/auth/login",
        json={
            "email": "spaces@example.com",
            "password": exact_password.strip()
        }
    )
    assert login_fail.status_code == 400


@pytest.mark.asyncio
async def test_role_authorization_admin_manager_employee(client, mock_users_collection):
    # Admin user
    res_admin = await mock_users_collection.insert_one({
        "name": "Admin User",
        "email": "admin_role@example.com",
        "password": hash_password("Password123"),
        "role": "admin",
        "status": "active"
    })
    token_admin = create_access_token({"user_id": str(res_admin.inserted_id), "role": "admin"})

    # Manager user
    res_manager = await mock_users_collection.insert_one({
        "name": "Manager User",
        "email": "manager_role@example.com",
        "password": hash_password("Password123"),
        "role": "manager",
        "status": "active"
    })
    token_manager = create_access_token({"user_id": str(res_manager.inserted_id), "role": "manager"})

    # Employee user
    res_employee = await mock_users_collection.insert_one({
        "name": "Employee User",
        "email": "employee_role@example.com",
        "password": hash_password("Password123"),
        "role": "employee",
        "status": "active"
    })
    token_employee = create_access_token({"user_id": str(res_employee.inserted_id), "role": "employee"})

    # 1. Admin accesses admin-test -> 200 OK
    resp_admin = await client.get("/admin-test", headers={"Authorization": f"Bearer {token_admin}"})
    assert resp_admin.status_code == 200

    # 2. Manager accesses admin-test -> 403 Forbidden
    resp_manager = await client.get("/admin-test", headers={"Authorization": f"Bearer {token_manager}"})
    assert resp_manager.status_code == 403

    # 3. Employee accesses admin-test -> 403 Forbidden
    resp_employee = await client.get("/admin-test", headers={"Authorization": f"Bearer {token_employee}"})
    assert resp_employee.status_code == 403
