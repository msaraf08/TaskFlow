from datetime import date, timedelta
import pytest
from app.core.security import hash_password
from app.core.jwt import create_access_token


async def setup_test_users_and_teams(
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection
):
    # Admin User & Employee
    admin_user = await mock_users_collection.insert_one({
        "name": "Admin User",
        "email": "admin@example.com",
        "password": hash_password("AdminPass123"),
        "role": "admin",
        "status": "active"
    })
    admin_user_id = str(admin_user.inserted_id)

    admin_emp = await mock_employees_collection.insert_one({
        "user_id": admin_user_id,
        "name": "Admin User",
        "email": "admin@example.com",
        "phone": "1234567890",
        "department": "Executive",
        "role": "admin",
        "status": "active"
    })
    admin_emp_id = str(admin_emp.inserted_id)

    # Manager 1 User & Employee
    mgr1_user = await mock_users_collection.insert_one({
        "name": "Manager One",
        "email": "mgr1@example.com",
        "password": hash_password("ManagerPass123"),
        "role": "manager",
        "status": "active"
    })
    mgr1_user_id = str(mgr1_user.inserted_id)

    mgr1_emp = await mock_employees_collection.insert_one({
        "user_id": mgr1_user_id,
        "name": "Manager One",
        "email": "mgr1@example.com",
        "phone": "1111111111",
        "department": "Engineering",
        "role": "manager",
        "status": "active"
    })
    mgr1_emp_id = str(mgr1_emp.inserted_id)

    # Manager 2 User & Employee
    mgr2_user = await mock_users_collection.insert_one({
        "name": "Manager Two",
        "email": "mgr2@example.com",
        "password": hash_password("ManagerPass123"),
        "role": "manager",
        "status": "active"
    })
    mgr2_user_id = str(mgr2_user.inserted_id)

    mgr2_emp = await mock_employees_collection.insert_one({
        "user_id": mgr2_user_id,
        "name": "Manager Two",
        "email": "mgr2@example.com",
        "phone": "2222222222",
        "department": "Design",
        "role": "manager",
        "status": "active"
    })
    mgr2_emp_id = str(mgr2_emp.inserted_id)

    # Employee 1 User & Employee
    emp1_user = await mock_users_collection.insert_one({
        "name": "Employee One",
        "email": "emp1@example.com",
        "password": hash_password("EmployeePass123"),
        "role": "employee",
        "status": "active"
    })
    emp1_user_id = str(emp1_user.inserted_id)

    emp1_emp = await mock_employees_collection.insert_one({
        "user_id": emp1_user_id,
        "name": "Employee One",
        "email": "emp1@example.com",
        "phone": "3333333333",
        "department": "Engineering",
        "role": "employee",
        "status": "active"
    })
    emp1_emp_id = str(emp1_emp.inserted_id)

    # Inactive User
    inactive_user = await mock_users_collection.insert_one({
        "name": "Inactive User",
        "email": "inactive@example.com",
        "password": hash_password("InactivePass123"),
        "role": "employee",
        "status": "inactive"
    })
    inactive_user_id = str(inactive_user.inserted_id)

    # Teams: Team 1 (Manager 1, Employee 1), Team 2 (Manager 2, No members), Team 3 (Manager 1)
    team1 = await mock_teams_collection.insert_one({
        "name": "Backend Team",
        "description": "Backend services",
        "manager_id": mgr1_emp_id,
        "member_ids": [emp1_emp_id]
    })
    team1_id = str(team1.inserted_id)

    team2 = await mock_teams_collection.insert_one({
        "name": "Design Team",
        "description": "UI/UX design",
        "manager_id": mgr2_emp_id,
        "member_ids": []
    })
    team2_id = str(team2.inserted_id)

    team3 = await mock_teams_collection.insert_one({
        "name": "Infra Team",
        "description": "Cloud infra",
        "manager_id": mgr1_emp_id,
        "member_ids": []
    })
    team3_id = str(team3.inserted_id)

    return {
        "admin_user_id": admin_user_id,
        "admin_token": create_access_token({"user_id": admin_user_id, "role": "admin"}),
        "mgr1_user_id": mgr1_user_id,
        "mgr1_emp_id": mgr1_emp_id,
        "mgr1_token": create_access_token({"user_id": mgr1_user_id, "role": "manager"}),
        "mgr2_user_id": mgr2_user_id,
        "mgr2_emp_id": mgr2_emp_id,
        "mgr2_token": create_access_token({"user_id": mgr2_user_id, "role": "manager"}),
        "emp1_user_id": emp1_user_id,
        "emp1_emp_id": emp1_emp_id,
        "emp1_token": create_access_token({"user_id": emp1_user_id, "role": "employee"}),
        "inactive_token": create_access_token({"user_id": inactive_user_id, "role": "employee"}),
        "team1_id": team1_id,
        "team2_id": team2_id,
        "team3_id": team3_id,
    }


@pytest.mark.asyncio
async def test_project_crud_lifecycle_and_defaults(
    client,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection
):
    data = await setup_test_users_and_teams(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection
    )
    headers = {"Authorization": f"Bearer {data['admin_token']}"}

    today = date.today()
    next_week = today + timedelta(days=7)

    # 1. Create project with default status
    create_payload = {
        "name": "  Project Alpha  ",
        "description": "Initial project scope",
        "team_id": data["team1_id"],
        "start_date": today.isoformat(),
        "end_date": next_week.isoformat(),
    }
    res = await client.post("/projects/", json=create_payload, headers=headers)
    assert res.status_code == 201, res.text
    project1 = res.json()
    assert project1["name"] == "Project Alpha"  # Trimmed
    assert project1["description"] == "Initial project scope"
    assert project1["team_id"] == data["team1_id"]
    assert project1["status"] == "planned"  # Default
    assert project1["created_by"] == data["admin_user_id"]
    assert "created_at" in project1
    assert "updated_at" in project1
    p1_id = project1["id"]

    # 2. Create project with explicit status
    create_payload2 = {
        "name": "Project Beta",
        "team_id": data["team1_id"],
        "start_date": today.isoformat(),
        "end_date": next_week.isoformat(),
        "status": "active"
    }
    res2 = await client.post("/projects/", json=create_payload2, headers=headers)
    assert res2.status_code == 201
    assert res2.json()["status"] == "active"

    # 3. Retrieve project by ID
    res_get = await client.get(f"/projects/{p1_id}", headers=headers)
    assert res_get.status_code == 200
    assert res_get.json()["id"] == p1_id

    # 4. Partial update (name, status)
    update_payload = {
        "name": "Project Alpha Updated",
        "status": "completed"
    }
    res_put = await client.put(f"/projects/{p1_id}", json=update_payload, headers=headers)
    assert res_put.status_code == 200
    updated = res_put.json()
    assert updated["name"] == "Project Alpha Updated"
    assert updated["status"] == "completed"
    assert updated["description"] == "Initial project scope"  # Retained
    assert updated["updated_at"] >= project1["updated_at"]

    # 5. Delete project
    res_del = await client.delete(f"/projects/{p1_id}", headers=headers)
    assert res_del.status_code == 204

    # 6. Verify 404 after deletion
    res_get_deleted = await client.get(f"/projects/{p1_id}", headers=headers)
    assert res_get_deleted.status_code == 404


@pytest.mark.asyncio
async def test_project_validation_rules(
    client,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection
):
    data = await setup_test_users_and_teams(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection
    )
    headers = {"Authorization": f"Bearer {data['admin_token']}"}
    today = date.today()
    yesterday = today - timedelta(days=1)

    # Missing team (404)
    res = await client.post("/projects/", json={
        "name": "No Team Project",
        "team_id": "6a99d4398a5cbc1907f06f99",
        "start_date": today.isoformat(),
        "end_date": (today + timedelta(days=1)).isoformat()
    }, headers=headers)
    assert res.status_code == 404

    # Malformed team ObjectId (400)
    res = await client.post("/projects/", json={
        "name": "Bad Team ID Project",
        "team_id": "invalid-id-123",
        "start_date": today.isoformat(),
        "end_date": (today + timedelta(days=1)).isoformat()
    }, headers=headers)
    assert res.status_code == 400

    # Invalid project ObjectId on GET/PUT/DELETE (400)
    res_bad_get = await client.get("/projects/not-an-id", headers=headers)
    assert res_bad_get.status_code == 400
    res_bad_put = await client.put("/projects/not-an-id", json={"name": "New"}, headers=headers)
    assert res_bad_put.status_code == 400
    res_bad_del = await client.delete("/projects/not-an-id", headers=headers)
    assert res_bad_del.status_code == 400

    # Non-existent project (404)
    res_missing = await client.get("/projects/6a99d4398a5cbc1907f06f99", headers=headers)
    assert res_missing.status_code == 404

    # Invalid date range: start_date > end_date (422)
    res_date = await client.post("/projects/", json={
        "name": "Invalid Dates",
        "team_id": data["team1_id"],
        "start_date": today.isoformat(),
        "end_date": yesterday.isoformat()
    }, headers=headers)
    assert res_date.status_code == 422

    # Empty / whitespace-only name (422)
    res_empty_name = await client.post("/projects/", json={
        "name": "   ",
        "team_id": data["team1_id"],
        "start_date": today.isoformat(),
        "end_date": today.isoformat()
    }, headers=headers)
    assert res_empty_name.status_code == 422

    # Invalid status value (422)
    res_bad_status = await client.post("/projects/", json={
        "name": "Bad Status",
        "team_id": data["team1_id"],
        "start_date": today.isoformat(),
        "end_date": today.isoformat(),
        "status": "in_progress"  # Valid are: planned, active, completed, cancelled
    }, headers=headers)
    assert res_bad_status.status_code == 422

    # Disallow client overriding created_by or created_at (422 via extra="forbid")
    res_forbidden_field = await client.post("/projects/", json={
        "name": "Hack Created By",
        "team_id": data["team1_id"],
        "start_date": today.isoformat(),
        "end_date": today.isoformat(),
        "created_by": "custom_user_id"
    }, headers=headers)
    assert res_forbidden_field.status_code == 422


@pytest.mark.asyncio
async def test_project_rbac_and_manager_ownership(
    client,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection
):
    data = await setup_test_users_and_teams(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection
    )
    admin_headers = {"Authorization": f"Bearer {data['admin_token']}"}
    mgr1_headers = {"Authorization": f"Bearer {data['mgr1_token']}"}
    mgr2_headers = {"Authorization": f"Bearer {data['mgr2_token']}"}
    emp1_headers = {"Authorization": f"Bearer {data['emp1_token']}"}
    inactive_headers = {"Authorization": f"Bearer {data['inactive_token']}"}

    today = date.today()
    next_week = today + timedelta(days=7)

    # 1. Manager 1 creates project for Team 1 (their own team) -> 201
    res1 = await client.post("/projects/", json={
        "name": "Team 1 Core Project",
        "team_id": data["team1_id"],
        "start_date": today.isoformat(),
        "end_date": next_week.isoformat(),
    }, headers=mgr1_headers)
    assert res1.status_code == 201
    p1_id = res1.json()["id"]
    assert res1.json()["created_by"] == data["mgr1_user_id"]

    # 2. Manager 1 attempts to create project for Team 2 (managed by Manager 2) -> 403
    res2 = await client.post("/projects/", json={
        "name": "Unauthorized Team 2 Project",
        "team_id": data["team2_id"],
        "start_date": today.isoformat(),
        "end_date": next_week.isoformat(),
    }, headers=mgr1_headers)
    assert res2.status_code == 403

    # 3. Employee attempts to create project -> 403
    res_emp_create = await client.post("/projects/", json={
        "name": "Employee Project",
        "team_id": data["team1_id"],
        "start_date": today.isoformat(),
        "end_date": next_week.isoformat(),
    }, headers=emp1_headers)
    assert res_emp_create.status_code == 403

    # 4. Manager 2 attempts to get/update/delete Manager 1's project -> 403
    res_m2_get = await client.get(f"/projects/{p1_id}", headers=mgr2_headers)
    assert res_m2_get.status_code == 403
    res_m2_put = await client.put(f"/projects/{p1_id}", json={"name": "Hijacked"}, headers=mgr2_headers)
    assert res_m2_put.status_code == 403
    res_m2_del = await client.delete(f"/projects/{p1_id}", headers=mgr2_headers)
    assert res_m2_del.status_code == 403

    # 5. Dual-team authorization on team change:
    # Manager 1 moves project from Team 1 to Team 3 (Manager 1 manages BOTH) -> 200 OK
    res_move_ok = await client.put(f"/projects/{p1_id}", json={"team_id": data["team3_id"]}, headers=mgr1_headers)
    assert res_move_ok.status_code == 200
    assert res_move_ok.json()["team_id"] == data["team3_id"]

    # Manager 1 attempts to move project from Team 3 to Team 2 (Team 2 managed by Manager 2) -> 403
    res_move_forbidden = await client.put(f"/projects/{p1_id}", json={"team_id": data["team2_id"]}, headers=mgr1_headers)
    assert res_move_forbidden.status_code == 403

    # Move back to Team 1
    await client.put(f"/projects/{p1_id}", json={"team_id": data["team1_id"]}, headers=mgr1_headers)

    # 6. Inactive user access blocked -> 403
    res_inactive = await client.get("/projects/", headers=inactive_headers)
    assert res_inactive.status_code == 403


@pytest.mark.asyncio
async def test_project_listing_and_employee_visibility(
    client,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection
):
    data = await setup_test_users_and_teams(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection
    )
    admin_headers = {"Authorization": f"Bearer {data['admin_token']}"}
    mgr1_headers = {"Authorization": f"Bearer {data['mgr1_token']}"}
    mgr2_headers = {"Authorization": f"Bearer {data['mgr2_token']}"}
    emp1_headers = {"Authorization": f"Bearer {data['emp1_token']}"}

    today = date.today()
    next_week = today + timedelta(days=7)

    # Create Project 1 on Team 1 (mgr1 manager, emp1 member)
    res1 = await client.post("/projects/", json={
        "name": "Team 1 Project",
        "team_id": data["team1_id"],
        "start_date": today.isoformat(),
        "end_date": next_week.isoformat(),
    }, headers=admin_headers)
    p1_id = res1.json()["id"]

    # Create Project 2 on Team 2 (mgr2 manager, no members)
    res2 = await client.post("/projects/", json={
        "name": "Team 2 Project",
        "team_id": data["team2_id"],
        "start_date": today.isoformat(),
        "end_date": next_week.isoformat(),
    }, headers=admin_headers)
    p2_id = res2.json()["id"]

    # 1. Admin listing: sees both projects
    res_admin_list = await client.get("/projects/", headers=admin_headers)
    assert res_admin_list.status_code == 200
    assert len(res_admin_list.json()) == 2

    # 2. Manager 1 listing: sees only Team 1 project
    res_m1_list = await client.get("/projects/", headers=mgr1_headers)
    assert res_m1_list.status_code == 200
    assert len(res_m1_list.json()) == 1
    assert res_m1_list.json()[0]["id"] == p1_id

    # 3. Manager 2 listing: sees only Team 2 project
    res_m2_list = await client.get("/projects/", headers=mgr2_headers)
    assert res_m2_list.status_code == 200
    assert len(res_m2_list.json()) == 1
    assert res_m2_list.json()[0]["id"] == p2_id

    # 4. Employee 1 listing: sees only Team 1 project (as member)
    res_emp_list = await client.get("/projects/", headers=emp1_headers)
    assert res_emp_list.status_code == 200
    assert len(res_emp_list.json()) == 1
    assert res_emp_list.json()[0]["id"] == p1_id

    # 5. Employee 1 gets Project 1 (member) -> 200 OK
    res_emp_get1 = await client.get(f"/projects/{p1_id}", headers=emp1_headers)
    assert res_emp_get1.status_code == 200

    # 6. Employee 1 gets Project 2 (not a member) -> 403 Forbidden
    res_emp_get2 = await client.get(f"/projects/{p2_id}", headers=emp1_headers)
    assert res_emp_get2.status_code == 403

    # 7. Employee 1 attempts update or delete -> 403 Forbidden
    res_emp_put = await client.put(f"/projects/{p1_id}", json={"name": "Emp Edit"}, headers=emp1_headers)
    assert res_emp_put.status_code == 403
    res_emp_del = await client.delete(f"/projects/{p1_id}", headers=emp1_headers)
    assert res_emp_del.status_code == 403

    # 8. User with no assigned/member teams receives empty list `[]` (200 OK, not 403)
    unassigned_user = await mock_users_collection.insert_one({
        "name": "Unassigned User",
        "email": "unassigned@example.com",
        "password": hash_password("Pass1234"),
        "role": "employee",
        "status": "active"
    })
    unassigned_token = create_access_token({"user_id": str(unassigned_user.inserted_id), "role": "employee"})
    res_unassigned = await client.get("/projects/", headers={"Authorization": f"Bearer {unassigned_token}"})
    assert res_unassigned.status_code == 200
    assert res_unassigned.json() == []
