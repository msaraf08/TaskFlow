from bson import ObjectId
import pytest
from app.core.jwt import create_access_token
from app.core.security import hash_password


@pytest.fixture
async def admin_auth(mock_users_collection):
    res = await mock_users_collection.insert_one({
        "name": "Super Admin",
        "email": "superadmin@example.com",
        "password": hash_password("AdminPass123"),
        "role": "admin",
        "status": "active"
    })
    token = create_access_token({"user_id": str(res.inserted_id), "role": "admin"})
    return {"Authorization": f"Bearer {token}"}, str(res.inserted_id)


@pytest.fixture
async def employee_auth(mock_users_collection):
    res = await mock_users_collection.insert_one({
        "name": "Normal Employee",
        "email": "normal@example.com",
        "password": hash_password("EmpPass123"),
        "role": "employee",
        "status": "active"
    })
    token = create_access_token({"user_id": str(res.inserted_id), "role": "employee"})
    return {"Authorization": f"Bearer {token}"}, str(res.inserted_id)


@pytest.mark.asyncio
async def test_create_employee_without_hardcoded_password(client, admin_auth):
    headers, _ = admin_auth
    resp = await client.post(
        "/employees/",
        headers=headers,
        json={
            "name": "John Doe",
            "email": "john.doe@example.com",
            "phone": "1234567890",
            "department": "Engineering",
            "role": "employee",
            "joining_date": "2026-09-01"
        }
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == "John Doe"
    assert data["email"] == "john.doe@example.com"
    assert "temporary_password" in data
    assert data["temporary_password"] != "Temp@123"  # Must not use hardcoded password
    assert len(data["temporary_password"]) >= 8
    assert "password" not in data


@pytest.mark.asyncio
async def test_invalid_objectid_returns_400(client, admin_auth):
    headers, _ = admin_auth

    # Bad ID on GET
    resp_get = await client.get("/employees/invalid-object-id-123", headers=headers)
    assert resp_get.status_code == 400
    assert "Invalid ID format" in resp_get.json()["detail"]

    # Bad ID on PUT
    resp_put = await client.put(
        "/employees/not-a-valid-id",
        headers=headers,
        json={"name": "New Name"}
    )
    assert resp_put.status_code == 400
    assert "Invalid ID format" in resp_put.json()["detail"]

    # Bad ID on PATCH deactivate
    resp_patch = await client.patch(
        "/employees/123-bad-hex/deactivate",
        headers=headers
    )
    assert resp_patch.status_code == 400
    assert "Invalid ID format" in resp_patch.json()["detail"]


@pytest.mark.asyncio
async def test_employee_update_joining_date(client, admin_auth):
    headers, _ = admin_auth

    # Create employee
    create_resp = await client.post(
        "/employees/",
        headers=headers,
        json={
            "name": "Alice Smith",
            "email": "alice@example.com",
            "phone": "555-0100",
            "department": "Design",
            "role": "employee",
            "joining_date": "2026-01-15"
        }
    )
    assert create_resp.status_code == 201
    emp_id = create_resp.json()["id"]

    # Update employee with new joining_date and department
    update_resp = await client.put(
        f"/employees/{emp_id}",
        headers=headers,
        json={
            "department": "Product",
            "joining_date": "2026-06-01"
        }
    )
    assert update_resp.status_code == 200
    updated_data = update_resp.json()
    assert updated_data["department"] == "Product"
    assert updated_data["joining_date"] == "2026-06-01"


@pytest.mark.asyncio
async def test_deactivate_employee_blocks_authentication(client, admin_auth, mock_users_collection):
    headers, _ = admin_auth

    # Create employee
    create_resp = await client.post(
        "/employees/",
        headers=headers,
        json={
            "name": "Bob Stone",
            "email": "bob@example.com",
            "phone": "555-0199",
            "department": "Sales",
            "role": "employee",
            "joining_date": "2026-03-10",
            "initial_password": "BobInitialPassword123"
        }
    )
    assert create_resp.status_code == 201
    emp_id = create_resp.json()["id"]

    # Login as Bob before deactivation -> succeeds
    login_before = await client.post(
        "/auth/login",
        json={"email": "bob@example.com", "password": "BobInitialPassword123"}
    )
    assert login_before.status_code == 200
    bob_token = login_before.json()["access_token"]

    # Deactivate Bob
    deact_resp = await client.patch(f"/employees/{emp_id}/deactivate", headers=headers)
    assert deact_resp.status_code == 200

    # Bob attempts to log in again -> fails (403 Forbidden)
    login_after = await client.post(
        "/auth/login",
        json={"email": "bob@example.com", "password": "BobInitialPassword123"}
    )
    assert login_after.status_code == 403

    # Bob's existing token is rejected on protected endpoint (403 Forbidden)
    prot_resp = await client.get(
        "/protected",
        headers={"Authorization": f"Bearer {bob_token}"}
    )
    assert prot_resp.status_code == 403


@pytest.mark.asyncio
async def test_employee_rbac_permissions(client, employee_auth):
    headers, _ = employee_auth

    # Regular employee cannot create new employee
    resp_create = await client.post(
        "/employees/",
        headers=headers,
        json={
            "name": "Eve Unauthorized",
            "email": "eve@example.com",
            "phone": "111-2222",
            "department": "Security",
            "role": "employee",
            "joining_date": "2026-04-01"
        }
    )
    assert resp_create.status_code == 403

    # Regular employee cannot list employees
    resp_list = await client.get("/employees/", headers=headers)
    assert resp_list.status_code == 403
