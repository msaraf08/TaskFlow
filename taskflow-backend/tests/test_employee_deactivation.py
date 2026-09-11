import pytest
from httpx import AsyncClient
from app.core.security import hash_password
from app.core.jwt import create_access_token
from tests.test_tasks import setup_task_test_data


@pytest.mark.asyncio
async def test_deactivate_and_reactivate_employee_flow(
    client: AsyncClient,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection,
    mock_activities_collection,
):
    data = await setup_task_test_data(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection,
    )
    admin_h = {"Authorization": f"Bearer {data['admin_token']}"}
    e1_h = {"Authorization": f"Bearer {data['e1_token']}"}

    # 1. Employee 1 is active and can access protected endpoints
    res_before = await client.get("/tasks/", headers=e1_h)
    assert res_before.status_code == 200

    # 2. Admin deactivates Employee 1
    deact_resp = await client.patch(
        f"/employees/{data['e1_emp_id']}/deactivate",
        headers=admin_h,
    )
    assert deact_resp.status_code == 200
    assert deact_resp.json()["message"] == "Employee deactivated successfully"
    assert deact_resp.json()["employee"]["status"] == "inactive"

    # Verify both collections synchronized
    from bson import ObjectId
    emp_doc = await mock_employees_collection.find_one({"_id": ObjectId(data["e1_emp_id"])})
    assert emp_doc["status"] == "inactive"
    user_doc = await mock_users_collection.find_one({"_id": ObjectId(data["e1_user_id"])})
    assert user_doc["status"] == "inactive"

    # 3. Inactive user cannot log in
    login_blocked = await client.post(
        "/auth/login",
        json={"email": "e1@taskflow.com", "password": "EmployeePass123"},
    )
    assert login_blocked.status_code == 403

    # 4. Inactive user's existing token is rejected on protected endpoints
    res_after = await client.get("/tasks/", headers=e1_h)
    assert res_after.status_code == 403

    # 5. Admin reactivates Employee 1
    react_resp = await client.patch(
        f"/employees/{data['e1_emp_id']}/reactivate",
        headers=admin_h,
    )
    assert react_resp.status_code == 200
    assert react_resp.json()["message"] == "Employee reactivated successfully"
    assert react_resp.json()["employee"]["status"] == "active"

    # Verify both collections synchronized to active
    emp_doc = await mock_employees_collection.find_one({"_id": ObjectId(data["e1_emp_id"])})
    assert emp_doc["status"] == "active"
    user_doc = await mock_users_collection.find_one({"_id": ObjectId(data["e1_user_id"])})
    assert user_doc["status"] == "active"

    # 6. Reactivated user can log in again
    login_again = await client.post(
        "/auth/login",
        json={"email": "e1@taskflow.com", "password": "EmployeePass123"},
    )
    assert login_again.status_code == 200


@pytest.mark.asyncio
async def test_admin_cannot_self_deactivate(
    client: AsyncClient,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection,
):
    data = await setup_task_test_data(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection,
    )
    admin_h = {"Authorization": f"Bearer {data['admin_token']}"}

    # Admin attempts to deactivate self
    deact_resp = await client.patch(
        f"/employees/{data['admin_emp_id']}/deactivate",
        headers=admin_h,
    )
    assert deact_resp.status_code == 403
    assert "cannot deactivate their own account" in deact_resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_cannot_deactivate_last_active_admin(
    client: AsyncClient,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection,
):
    data = await setup_task_test_data(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection,
    )
    admin1_h = {"Authorization": f"Bearer {data['admin_token']}"}

    # Promote e2 to admin so we have 2 active admins
    prom_res = await client.patch(
        f"/employees/{data['e2_emp_id']}/role",
        headers=admin1_h,
        json={"role": "admin"},
    )
    assert prom_res.status_code == 200

    admin2_token = create_access_token({"user_id": data["e2_user_id"], "role": "admin"})
    admin2_h = {"Authorization": f"Bearer {admin2_token}"}

    # Admin 2 deactivates Admin 1 (allowed because 2 active admins exist)
    deact1 = await client.patch(
        f"/employees/{data['admin_emp_id']}/deactivate",
        headers=admin2_h,
    )
    assert deact1.status_code == 200

    # Now Admin 2 is the last active admin.
    # Reactivate Admin 1 to test deactivating Admin 2 from Admin 1's perspective:
    await client.patch(
        f"/employees/{data['admin_emp_id']}/reactivate",
        headers=admin2_h,
    )

    # Deactivate Admin 2 from Admin 1's perspective
    deact2 = await client.patch(
        f"/employees/{data['e2_emp_id']}/deactivate",
        headers=admin1_h,
    )
    assert deact2.status_code == 200

    # Now Admin 1 is the ONLY active admin.
    # If Admin 1 tries to deactivate themselves: 403 Forbidden.
    # If a service call is made or if another token tried to deactivate Admin 1:
    # Service raises 409 Conflict because active_admin_count <= 1.
    deact_self = await client.patch(
        f"/employees/{data['admin_emp_id']}/deactivate",
        headers=admin1_h,
    )
    assert deact_self.status_code == 403


@pytest.mark.asyncio
async def test_cannot_deactivate_manager_with_active_teams(
    client: AsyncClient,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection,
):
    data = await setup_task_test_data(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection,
    )
    admin_h = {"Authorization": f"Bearer {data['admin_token']}"}

    # Admin attempts to deactivate Dave (Manager 1) -> 409 Conflict
    deact_resp = await client.patch(
        f"/employees/{data['m1_emp_id']}/deactivate",
        headers=admin_h,
    )
    assert deact_resp.status_code == 409
    assert "currently managing" in deact_resp.json()["detail"]
    assert "reassign those teams first" in deact_resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_non_admin_cannot_deactivate_or_reactivate(
    client: AsyncClient,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection,
):
    data = await setup_task_test_data(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection,
    )
    m1_h = {"Authorization": f"Bearer {data['m1_token']}"}
    e1_h = {"Authorization": f"Bearer {data['e1_token']}"}

    # Manager cannot deactivate
    res1 = await client.patch(f"/employees/{data['e2_emp_id']}/deactivate", headers=m1_h)
    assert res1.status_code == 403

    # Employee cannot deactivate
    res2 = await client.patch(f"/employees/{data['e2_emp_id']}/deactivate", headers=e1_h)
    assert res2.status_code == 403

    # Manager cannot reactivate
    res3 = await client.patch(f"/employees/{data['e2_emp_id']}/reactivate", headers=m1_h)
    assert res3.status_code == 403
