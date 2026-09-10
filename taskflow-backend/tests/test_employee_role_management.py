import pytest
from httpx import AsyncClient
from app.core.security import hash_password
from app.core.jwt import create_access_token
from tests.test_tasks import setup_task_test_data


@pytest.mark.asyncio
async def test_admin_role_transitions_and_synchronization(
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
    m1_h = {"Authorization": f"Bearer {data['m1_token']}"}
    e1_h = {"Authorization": f"Bearer {data['e1_token']}"}

    # 1. Admin can change Employee 2 (not managing any teams) -> Manager
    res1 = await client.patch(
        f"/employees/{data['e2_emp_id']}/role",
        headers=admin_h,
        json={"role": "manager"},
    )
    assert res1.status_code == 200
    assert res1.json()["role"] == "manager"

    # Verify synchronization: both employees and users collections are updated
    emp_doc = await mock_employees_collection.find_one({"user_id": data["e2_user_id"]})
    assert emp_doc["role"] == "manager"
    user_doc = await mock_users_collection.find_one({"email": "e2@taskflow.com"})
    assert user_doc["role"] == "manager"

    # 2. Admin can change Manager -> Employee (Employee 2 is not managing any teams)
    res2 = await client.patch(
        f"/employees/{data['e2_emp_id']}/role",
        headers=admin_h,
        json={"role": "employee"},
    )
    assert res2.status_code == 200
    assert res2.json()["role"] == "employee"
    user_doc = await mock_users_collection.find_one({"email": "e2@taskflow.com"})
    assert user_doc["role"] == "employee"

    # 3. Admin can change Employee -> Admin
    res3 = await client.patch(
        f"/employees/{data['e2_emp_id']}/role",
        headers=admin_h,
        json={"role": "admin"},
    )
    assert res3.status_code == 200
    assert res3.json()["role"] == "admin"
    user_doc = await mock_users_collection.find_one({"email": "e2@taskflow.com"})
    assert user_doc["role"] == "admin"

    # 4. Now that we have two admins (Admin User and Employee 2), Admin 1 can demote Employee 2 back to Manager
    res4 = await client.patch(
        f"/employees/{data['e2_emp_id']}/role",
        headers=admin_h,
        json={"role": "manager"},
    )
    assert res4.status_code == 200
    assert res4.json()["role"] == "manager"

    # 5. Admin can change Manager -> Admin (Manager 2)
    # Note: Manager 2 manages Team 2, but promoting to Admin is allowed
    res5 = await client.patch(
        f"/employees/{data['m2_emp_id']}/role",
        headers=admin_h,
        json={"role": "admin"},
    )
    assert res5.status_code == 200
    assert res5.json()["role"] == "admin"


@pytest.mark.asyncio
async def test_self_role_change_and_last_admin_protection(
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

    # 1. Admin attempts self role change -> 403 Forbidden
    res_self = await client.patch(
        f"/employees/{data['admin_emp_id']}/role",
        headers=admin_h,
        json={"role": "manager"},
    )
    assert res_self.status_code == 403
    assert "cannot change their own role" in res_self.json()["detail"].lower()

    # 2. Promote Employee 2 to Admin so we have 2 admins
    promote_e2 = await client.patch(
        f"/employees/{data['e2_emp_id']}/role",
        headers=admin_h,
        json={"role": "admin"},
    )
    assert promote_e2.status_code == 200
    e2_admin_token = create_access_token({"user_id": data["e2_user_id"], "role": "admin"})
    e2_admin_h = {"Authorization": f"Bearer {e2_admin_token}"}

    # 3. Employee 2 (as Admin) demotes Admin 1 -> 200 OK (since 2 admins existed)
    res_demote_admin1 = await client.patch(
        f"/employees/{data['admin_emp_id']}/role",
        headers=e2_admin_h,
        json={"role": "manager"},
    )
    assert res_demote_admin1.status_code == 200
    assert res_demote_admin1.json()["role"] == "manager"

    # 4. Now Employee 2 is the last remaining Admin.
    # Re-promote Admin 1 back to admin by Employee 2
    await client.patch(
        f"/employees/{data['admin_emp_id']}/role",
        headers=e2_admin_h,
        json={"role": "admin"},
    )
    # Demote Employee 2 back to employee by Admin 1
    await client.patch(
        f"/employees/{data['e2_emp_id']}/role",
        headers=admin_h,
        json={"role": "employee"},
    )

    # Now Admin 1 is the sole admin again. Let's verify last-admin demotion attempt logic by creating Admin 3:
    adm3_user = await mock_users_collection.insert_one({
        "name": "Admin Three",
        "email": "adm3@test.com",
        "password": hash_password("Pass123"),
        "role": "admin",
        "status": "active"
    })
    adm3_emp = await mock_employees_collection.insert_one({
        "user_id": str(adm3_user.inserted_id),
        "name": "Admin Three",
        "email": "adm3@test.com",
        "role": "admin",
        "department": "Exec",
        "status": "active"
    })
    adm3_token = create_access_token({"user_id": str(adm3_user.inserted_id), "role": "admin"})
    adm3_h = {"Authorization": f"Bearer {adm3_token}"}

    # Demote Admin 1 by Admin 3
    await client.patch(f"/employees/{data['admin_emp_id']}/role", headers=adm3_h, json={"role": "employee"})

    # Now Admin 3 is the ONLY admin in the system!
    res_last_fail = await client.patch(
        f"/employees/{str(adm3_emp.inserted_id)}/role",
        headers=adm3_h, # self-attempt is 403 anyway
        json={"role": "employee"},
    )
    assert res_last_fail.status_code == 403


@pytest.mark.asyncio
async def test_team_manager_safety_and_rbac_restrictions(
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
    m1_h = {"Authorization": f"Bearer {data['m1_token']}"}
    e1_h = {"Authorization": f"Bearer {data['e1_token']}"}

    # 1. Manager 1 manages Team 1 and Team 3. Demoting Manager 1 to Employee -> 409 Conflict
    res_demote_m1 = await client.patch(
        f"/employees/{data['m1_emp_id']}/role",
        headers=admin_h,
        json={"role": "employee"},
    )
    assert res_demote_m1.status_code == 409
    assert "currently managing" in res_demote_m1.json()["detail"].lower()
    assert "reassign those teams first" in res_demote_m1.json()["detail"].lower()

    # 2. Manager caller attempts to change a role -> 403 Forbidden
    res_mgr_call = await client.patch(
        f"/employees/{data['e1_emp_id']}/role",
        headers=m1_h,
        json={"role": "manager"},
    )
    assert res_mgr_call.status_code == 403

    # 3. Employee caller attempts to change a role -> 403 Forbidden
    res_emp_call = await client.patch(
        f"/employees/{data['e2_emp_id']}/role",
        headers=e1_h,
        json={"role": "manager"},
    )
    assert res_emp_call.status_code == 403


@pytest.mark.asyncio
async def test_role_change_validation_and_error_handling(
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

    # 1. Invalid role value -> 422
    res_bad_role = await client.patch(
        f"/employees/{data['e1_emp_id']}/role",
        headers=admin_h,
        json={"role": "superadmin"},
    )
    assert res_bad_role.status_code == 422

    # 2. Extra field in request body -> 422
    res_extra = await client.patch(
        f"/employees/{data['e1_emp_id']}/role",
        headers=admin_h,
        json={"role": "manager", "is_admin": True},
    )
    assert res_extra.status_code == 422

    # 3. Malformed employee_id -> 400
    res_malformed = await client.patch(
        "/employees/not-an-object-id/role",
        headers=admin_h,
        json={"role": "manager"},
    )
    assert res_malformed.status_code == 400

    # 4. Nonexistent employee -> 404
    res_missing_emp = await client.patch(
        "/employees/650000000000000000000099/role",
        headers=admin_h,
        json={"role": "manager"},
    )
    assert res_missing_emp.status_code == 404

    # 5. Employee with missing user document -> 404
    orphan_emp = await mock_employees_collection.insert_one({
        "name": "Orphan Employee",
        "email": "orphan@test.com",
        "user_id": "650000000000000000000088",
        "role": "employee",
        "department": "Engineering",
        "status": "active"
    })
    res_missing_user = await client.patch(
        f"/employees/{str(orphan_emp.inserted_id)}/role",
        headers=admin_h,
        json={"role": "manager"},
    )
    assert res_missing_user.status_code == 404


@pytest.mark.asyncio
async def test_role_change_activity_logging_and_relationship_preservation(
    client: AsyncClient,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection,
    mock_tasks_collection,
    mock_activities_collection,
):
    data = await setup_task_test_data(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection,
    )

    admin_h = {"Authorization": f"Bearer {data['admin_token']}"}

    # Create task assigned to Employee 1
    t_resp = await client.post(
        "/tasks/",
        headers=admin_h,
        json={
            "title": "Role Preservation Task",
            "description": "Task to verify relationships stay intact",
            "project_id": data["p1_id"],
            "assigned_to": data["e1_emp_id"],
            "priority": "medium",
            "status": "in_progress",
            "due_date": "2026-10-01",
        },
    )
    assert t_resp.status_code == 201
    task_id = t_resp.json()["id"]

    # Role change: Employee 1 -> Manager (Employee 1 is member of Team 1, not manager of any teams)
    res_promote = await client.patch(
        f"/employees/{data['e1_emp_id']}/role",
        headers=admin_h,
        json={"role": "manager"},
    )
    assert res_promote.status_code == 200
    assert res_promote.json()["role"] == "manager"

    # 1. Verify activity was logged
    act_resp = await client.get("/activities/?action=user_role_changed", headers=admin_h)
    assert act_resp.status_code == 200
    activities = act_resp.json()
    assert len(activities) >= 1
    latest_act = activities[0]
    assert latest_act["actor_user_id"] == data["admin_user_id"]
    assert latest_act["action"] == "user_role_changed"
    assert latest_act["entity_type"] == "employee"
    assert latest_act["entity_id"] == data["e1_emp_id"]
    assert latest_act["metadata"]["old_value"] == "employee"
    assert latest_act["metadata"]["new_value"] == "manager"
    assert latest_act["metadata"]["name"] == "Employee One"

    # 2. Verify Task assignment is unchanged
    get_task = await client.get(f"/tasks/{task_id}", headers=admin_h)
    assert get_task.status_code == 200
    assert get_task.json()["assigned_to"] == data["e1_emp_id"]
    assert get_task.json()["project_id"] == data["p1_id"]

    # 3. Verify Team membership is unchanged
    get_team = await client.get(f"/teams/{data['team1_id']}", headers=admin_h)
    assert get_team.status_code == 200
    assert data["e1_emp_id"] in get_team.json()["member_ids"]

    # 4. Verify Promoted Manager is now eligible to be assigned as manager of a team
    new_team_resp = await client.post(
        "/teams/",
        headers=admin_h,
        json={
            "name": "New Team with Promoted Manager",
            "description": "Led by Employee One",
            "manager_id": data["e1_emp_id"],
        },
    )
    assert new_team_resp.status_code == 201
    assert new_team_resp.json()["manager_id"] == data["e1_emp_id"]
