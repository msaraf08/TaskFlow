from datetime import date, datetime, timedelta, timezone
import pytest
from app.core.security import hash_password
from app.core.jwt import create_access_token


async def setup_task_test_data(
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection
):
    # 1. Admin
    admin_user = await mock_users_collection.insert_one({
        "name": "Admin User",
        "email": "admin@taskflow.local",
        "password": hash_password("AdminPass123"),
        "role": "admin",
        "status": "active"
    })
    admin_user_id = str(admin_user.inserted_id)

    admin_emp = await mock_employees_collection.insert_one({
        "user_id": admin_user_id,
        "name": "Admin User",
        "email": "admin@taskflow.local",
        "phone": "1000000000",
        "department": "Exec",
        "role": "admin",
        "status": "active"
    })
    admin_emp_id = str(admin_emp.inserted_id)

    # 2. Manager 1
    m1_user = await mock_users_collection.insert_one({
        "name": "Manager One",
        "email": "m1@taskflow.local",
        "password": hash_password("ManagerPass123"),
        "role": "manager",
        "status": "active"
    })
    m1_user_id = str(m1_user.inserted_id)

    m1_emp = await mock_employees_collection.insert_one({
        "user_id": m1_user_id,
        "name": "Manager One",
        "email": "m1@taskflow.local",
        "phone": "1111111111",
        "department": "Engineering",
        "role": "manager",
        "status": "active"
    })
    m1_emp_id = str(m1_emp.inserted_id)

    # 3. Manager 2
    m2_user = await mock_users_collection.insert_one({
        "name": "Manager Two",
        "email": "m2@taskflow.local",
        "password": hash_password("ManagerPass123"),
        "role": "manager",
        "status": "active"
    })
    m2_user_id = str(m2_user.inserted_id)

    m2_emp = await mock_employees_collection.insert_one({
        "user_id": m2_user_id,
        "name": "Manager Two",
        "email": "m2@taskflow.local",
        "phone": "2222222222",
        "department": "Marketing",
        "role": "manager",
        "status": "active"
    })
    m2_emp_id = str(m2_emp.inserted_id)

    # 4. Employee 1 (Team 1 member)
    e1_user = await mock_users_collection.insert_one({
        "name": "Employee One",
        "email": "e1@taskflow.local",
        "password": hash_password("EmployeePass123"),
        "role": "employee",
        "status": "active"
    })
    e1_user_id = str(e1_user.inserted_id)

    e1_emp = await mock_employees_collection.insert_one({
        "user_id": e1_user_id,
        "name": "Employee One",
        "email": "e1@taskflow.local",
        "phone": "3333333333",
        "department": "Engineering",
        "role": "employee",
        "status": "active"
    })
    e1_emp_id = str(e1_emp.inserted_id)

    # 5. Employee 2 (Team 2 member)
    e2_user = await mock_users_collection.insert_one({
        "name": "Employee Two",
        "email": "e2@taskflow.local",
        "password": hash_password("EmployeePass123"),
        "role": "employee",
        "status": "active"
    })
    e2_user_id = str(e2_user.inserted_id)

    e2_emp = await mock_employees_collection.insert_one({
        "user_id": e2_user_id,
        "name": "Employee Two",
        "email": "e2@taskflow.local",
        "phone": "4444444444",
        "department": "Marketing",
        "role": "employee",
        "status": "active"
    })
    e2_emp_id = str(e2_emp.inserted_id)

    # 6. Inactive Employee
    inact_user = await mock_users_collection.insert_one({
        "name": "Inactive User",
        "email": "inactive@taskflow.local",
        "password": hash_password("InactivePass123"),
        "role": "employee",
        "status": "inactive"
    })
    inact_user_id = str(inact_user.inserted_id)

    inact_emp = await mock_employees_collection.insert_one({
        "user_id": inact_user_id,
        "name": "Inactive Employee",
        "email": "inactive@taskflow.local",
        "phone": "9999999999",
        "department": "Engineering",
        "role": "employee",
        "status": "inactive"
    })
    inact_emp_id = str(inact_emp.inserted_id)

    # 7. Teams
    # Team 1: Managed by Manager 1, Member: Employee 1
    team1 = await mock_teams_collection.insert_one({
        "name": "Backend Team",
        "description": "Backend API Services",
        "manager_id": m1_emp_id,
        "member_ids": [e1_emp_id]
    })
    team1_id = str(team1.inserted_id)

    # Team 2: Managed by Manager 2, Member: Employee 2
    team2 = await mock_teams_collection.insert_one({
        "name": "Marketing Team",
        "description": "Growth & Comms",
        "manager_id": m2_emp_id,
        "member_ids": [e2_emp_id]
    })
    team2_id = str(team2.inserted_id)

    # Team 3: Also Managed by Manager 1, Member: Employee 1
    team3 = await mock_teams_collection.insert_one({
        "name": "DevOps Team",
        "description": "Infra & CI/CD",
        "manager_id": m1_emp_id,
        "member_ids": [e1_emp_id]
    })
    team3_id = str(team3.inserted_id)

    # 8. Projects
    today = date.today()
    next_month = today + timedelta(days=30)

    # Project 1 on Team 1
    p1 = await mock_projects_collection.insert_one({
        "name": "Core API V1",
        "description": "Building main backend",
        "team_id": team1_id,
        "start_date": datetime.combine(today, datetime.min.time()),
        "end_date": datetime.combine(next_month, datetime.min.time()),
        "status": "active",
        "created_by": m1_user_id,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc)
    })
    p1_id = str(p1.inserted_id)

    # Project 2 on Team 2
    p2 = await mock_projects_collection.insert_one({
        "name": "Brand Campaign",
        "description": "Q4 Brand strategy",
        "team_id": team2_id,
        "start_date": datetime.combine(today, datetime.min.time()),
        "end_date": datetime.combine(next_month, datetime.min.time()),
        "status": "planned",
        "created_by": m2_user_id,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc)
    })
    p2_id = str(p2.inserted_id)

    # Project 3 on Team 3 (Manager 1)
    p3 = await mock_projects_collection.insert_one({
        "name": "Cloud Infra Migration",
        "description": "Kubernetes migration",
        "team_id": team3_id,
        "start_date": datetime.combine(today, datetime.min.time()),
        "end_date": datetime.combine(next_month, datetime.min.time()),
        "status": "active",
        "created_by": m1_user_id,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc)
    })
    p3_id = str(p3.inserted_id)

    return {
        "admin_user_id": admin_user_id,
        "admin_emp_id": admin_emp_id,
        "admin_token": create_access_token({"user_id": admin_user_id, "role": "admin"}),

        "m1_user_id": m1_user_id,
        "m1_emp_id": m1_emp_id,
        "m1_token": create_access_token({"user_id": m1_user_id, "role": "manager"}),

        "m2_user_id": m2_user_id,
        "m2_emp_id": m2_emp_id,
        "m2_token": create_access_token({"user_id": m2_user_id, "role": "manager"}),

        "e1_user_id": e1_user_id,
        "e1_emp_id": e1_emp_id,
        "e1_token": create_access_token({"user_id": e1_user_id, "role": "employee"}),

        "e2_user_id": e2_user_id,
        "e2_emp_id": e2_emp_id,
        "e2_token": create_access_token({"user_id": e2_user_id, "role": "employee"}),

        "inact_user_id": inact_user_id,
        "inact_emp_id": inact_emp_id,
        "inact_token": create_access_token({"user_id": inact_user_id, "role": "employee"}),

        "team1_id": team1_id,
        "team2_id": team2_id,
        "team3_id": team3_id,

        "p1_id": p1_id,
        "p2_id": p2_id,
        "p3_id": p3_id,
    }


@pytest.mark.asyncio
async def test_task_crud_lifecycle_and_defaults(
    client,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection
):
    data = await setup_task_test_data(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection
    )
    admin_headers = {"Authorization": f"Bearer {data['admin_token']}"}
    due = (date.today() + timedelta(days=5)).isoformat()

    # 1. Create task with default priority & status (medium / todo)
    create_payload = {
        "title": "  Setup Database Indexes  ",
        "description": "Add index on team_id and status",
        "project_id": data["p1_id"],
        "assigned_to": data["e1_emp_id"],
        "due_date": due
    }
    res = await client.post("/tasks/", json=create_payload, headers=admin_headers)
    assert res.status_code == 201, res.text
    task1 = res.json()
    assert task1["title"] == "Setup Database Indexes"  # Trimmed
    assert task1["priority"] == "medium"  # Default
    assert task1["status"] == "todo"  # Default
    assert task1["project_id"] == data["p1_id"]
    assert task1["assigned_to"] == data["e1_emp_id"]
    assert task1["created_by"] == data["admin_user_id"]
    assert "created_at" in task1
    assert "updated_at" in task1
    t1_id = task1["id"]

    # 2. Create task with explicit priority & status
    res2 = await client.post("/tasks/", json={
        "title": "Deploy to Staging",
        "project_id": data["p1_id"],
        "assigned_to": data["m1_emp_id"],  # Manager can also be assigned!
        "priority": "urgent",
        "status": "in_progress",
        "due_date": due
    }, headers=admin_headers)
    assert res2.status_code == 201
    task2 = res2.json()
    assert task2["priority"] == "urgent"
    assert task2["status"] == "in_progress"
    assert task2["assigned_to"] == data["m1_emp_id"]

    # 3. Retrieve task by ID
    res_get = await client.get(f"/tasks/{t1_id}", headers=admin_headers)
    assert res_get.status_code == 200
    assert res_get.json()["id"] == t1_id

    # 4. Partial update (title, status)
    res_put = await client.put(f"/tasks/{t1_id}", json={
        "title": "Setup All Database Indexes",
        "status": "completed"
    }, headers=admin_headers)
    assert res_put.status_code == 200
    updated = res_put.json()
    assert updated["title"] == "Setup All Database Indexes"
    assert updated["status"] == "completed"
    assert updated["description"] == "Add index on team_id and status"  # Retained
    assert updated["updated_at"] >= task1["updated_at"]

    # 5. Delete task
    res_del = await client.delete(f"/tasks/{t1_id}", headers=admin_headers)
    assert res_del.status_code == 204

    # 6. Verify 404 after deletion
    res_after = await client.get(f"/tasks/{t1_id}", headers=admin_headers)
    assert res_after.status_code == 404


@pytest.mark.asyncio
async def test_task_validation_and_eligibility_rules(
    client,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection
):
    data = await setup_task_test_data(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection
    )
    admin_headers = {"Authorization": f"Bearer {data['admin_token']}"}
    due = (date.today() + timedelta(days=5)).isoformat()

    # Missing / malformed project_id (404 / 400)
    res_no_proj = await client.post("/tasks/", json={
        "title": "Task",
        "project_id": "6a99d4398a5cbc1907f06f99",
        "assigned_to": data["e1_emp_id"],
        "due_date": due
    }, headers=admin_headers)
    assert res_no_proj.status_code == 404

    res_bad_proj = await client.post("/tasks/", json={
        "title": "Task",
        "project_id": "not-valid-id",
        "assigned_to": data["e1_emp_id"],
        "due_date": due
    }, headers=admin_headers)
    assert res_bad_proj.status_code == 400

    # Missing / malformed assigned_to (404 / 400)
    res_no_emp = await client.post("/tasks/", json={
        "title": "Task",
        "project_id": data["p1_id"],
        "assigned_to": "6a99d4398a5cbc1907f06f99",
        "due_date": due
    }, headers=admin_headers)
    assert res_no_emp.status_code == 404

    res_bad_emp = await client.post("/tasks/", json={
        "title": "Task",
        "project_id": data["p1_id"],
        "assigned_to": "not-valid-id",
        "due_date": due
    }, headers=admin_headers)
    assert res_bad_emp.status_code == 400

    # Inactive assigned employee -> 403 Forbidden
    res_inact_emp = await client.post("/tasks/", json={
        "title": "Task",
        "project_id": data["p1_id"],
        "assigned_to": data["inact_emp_id"],
        "due_date": due
    }, headers=admin_headers)
    assert res_inact_emp.status_code == 403

    # Ineligible employee (Employee 2 is not on Team 1 nor manager of Team 1) -> 403 Forbidden
    res_inelig = await client.post("/tasks/", json={
        "title": "Task",
        "project_id": data["p1_id"],
        "assigned_to": data["e2_emp_id"],
        "due_date": due
    }, headers=admin_headers)
    assert res_inelig.status_code == 403

    # Empty / whitespace title -> 422
    res_empty_title = await client.post("/tasks/", json={
        "title": "   ",
        "project_id": data["p1_id"],
        "assigned_to": data["e1_emp_id"],
        "due_date": due
    }, headers=admin_headers)
    assert res_empty_title.status_code == 422

    # Title exceeding 200 chars -> 422
    res_long_title = await client.post("/tasks/", json={
        "title": "A" * 201,
        "project_id": data["p1_id"],
        "assigned_to": data["e1_emp_id"],
        "due_date": due
    }, headers=admin_headers)
    assert res_long_title.status_code == 422

    # Invalid priority enum -> 422
    res_bad_prio = await client.post("/tasks/", json={
        "title": "Task",
        "project_id": data["p1_id"],
        "assigned_to": data["e1_emp_id"],
        "priority": "critical",
        "due_date": due
    }, headers=admin_headers)
    assert res_bad_prio.status_code == 422

    # Invalid status enum -> 422
    res_bad_stat = await client.post("/tasks/", json={
        "title": "Task",
        "project_id": data["p1_id"],
        "assigned_to": data["e1_emp_id"],
        "status": "reviewing",
        "due_date": due
    }, headers=admin_headers)
    assert res_bad_stat.status_code == 422

    # Extra / immutable field in payload -> 422
    res_hack = await client.post("/tasks/", json={
        "title": "Task",
        "project_id": data["p1_id"],
        "assigned_to": data["e1_emp_id"],
        "due_date": due,
        "created_by": "hacker"
    }, headers=admin_headers)
    assert res_hack.status_code == 422


@pytest.mark.asyncio
async def test_task_rbac_and_manager_ownership(
    client,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection
):
    data = await setup_task_test_data(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection
    )
    m1_headers = {"Authorization": f"Bearer {data['m1_token']}"}
    m2_headers = {"Authorization": f"Bearer {data['m2_token']}"}
    e1_headers = {"Authorization": f"Bearer {data['e1_token']}"}
    due = (date.today() + timedelta(days=5)).isoformat()

    # 1. Manager 1 creates task for Project 1 (managed team) -> 201
    res1 = await client.post("/tasks/", json={
        "title": "Team 1 Core Task",
        "project_id": data["p1_id"],
        "assigned_to": data["e1_emp_id"],
        "due_date": due
    }, headers=m1_headers)
    assert res1.status_code == 201
    t1_id = res1.json()["id"]

    # 2. Manager 1 attempts to create task for Project 2 (managed by Manager 2) -> 403
    res2 = await client.post("/tasks/", json={
        "title": "Unauthorized Task",
        "project_id": data["p2_id"],
        "assigned_to": data["e2_emp_id"],
        "due_date": due
    }, headers=m1_headers)
    assert res2.status_code == 403

    # 3. Employee 1 attempts to create task -> 403
    res3 = await client.post("/tasks/", json={
        "title": "Employee Created Task",
        "project_id": data["p1_id"],
        "assigned_to": data["e1_emp_id"],
        "due_date": due
    }, headers=e1_headers)
    assert res3.status_code == 403

    # 4. Manager 2 attempts to get / update / delete Manager 1's task -> 403
    res_m2_get = await client.get(f"/tasks/{t1_id}", headers=m2_headers)
    assert res_m2_get.status_code == 403
    res_m2_put = await client.put(f"/tasks/{t1_id}", json={"title": "Hacked"}, headers=m2_headers)
    assert res_m2_put.status_code == 403
    res_m2_del = await client.delete(f"/tasks/{t1_id}", headers=m2_headers)
    assert res_m2_del.status_code == 403

    # 5. Dual-team authorization on project change:
    # Manager 1 moves task from Project 1 (Team 1) to Project 3 (Team 3) (Manager 1 manages both, Employee 1 eligible on both) -> 200 OK
    res_move_ok = await client.put(f"/tasks/{t1_id}", json={"project_id": data["p3_id"]}, headers=m1_headers)
    assert res_move_ok.status_code == 200
    assert res_move_ok.json()["project_id"] == data["p3_id"]

    # Manager 1 attempts to move task from Project 3 to Project 2 (Team 2 managed by Manager 2) -> 403
    res_move_bad = await client.put(f"/tasks/{t1_id}", json={"project_id": data["p2_id"]}, headers=m1_headers)
    assert res_move_bad.status_code == 403

    # Move task back to Project 1
    await client.put(f"/tasks/{t1_id}", json={"project_id": data["p1_id"]}, headers=m1_headers)

    # Reassignment: Manager 1 reassigns task to themself (manager of Team 1) -> 200 OK
    res_reassign_mgr = await client.put(f"/tasks/{t1_id}", json={"assigned_to": data["m1_emp_id"]}, headers=m1_headers)
    assert res_reassign_mgr.status_code == 200
    assert res_reassign_mgr.json()["assigned_to"] == data["m1_emp_id"]

    # Reassignment to ineligible employee -> 403 Forbidden
    res_reassign_bad = await client.put(f"/tasks/{t1_id}", json={"assigned_to": data["e2_emp_id"]}, headers=m1_headers)
    assert res_reassign_bad.status_code == 403


@pytest.mark.asyncio
async def test_employee_task_scoping_and_update_restrictions(
    client,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection
):
    data = await setup_task_test_data(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection
    )
    admin_headers = {"Authorization": f"Bearer {data['admin_token']}"}
    m1_headers = {"Authorization": f"Bearer {data['m1_token']}"}
    m2_headers = {"Authorization": f"Bearer {data['m2_token']}"}
    e1_headers = {"Authorization": f"Bearer {data['e1_token']}"}
    e2_headers = {"Authorization": f"Bearer {data['e2_token']}"}
    due = (date.today() + timedelta(days=5)).isoformat()

    # Create Task 1 on Project 1 (assigned to Employee 1)
    res1 = await client.post("/tasks/", json={
        "title": "Task 1 (Assigned to E1)",
        "project_id": data["p1_id"],
        "assigned_to": data["e1_emp_id"],
        "due_date": due
    }, headers=m1_headers)
    t1_id = res1.json()["id"]

    # Create Task 2 on Project 1 (assigned to Manager 1)
    res2 = await client.post("/tasks/", json={
        "title": "Task 2 (Assigned to M1)",
        "project_id": data["p1_id"],
        "assigned_to": data["m1_emp_id"],
        "due_date": due
    }, headers=m1_headers)
    t2_id = res2.json()["id"]

    # Create Task 3 on Project 2 (assigned to Employee 2)
    res3 = await client.post("/tasks/", json={
        "title": "Task 3 (Assigned to E2)",
        "project_id": data["p2_id"],
        "assigned_to": data["e2_emp_id"],
        "due_date": due
    }, headers=m2_headers)
    t3_id = res3.json()["id"]

    # 1. Admin sees all 3 tasks
    res_admin_list = await client.get("/tasks/", headers=admin_headers)
    assert res_admin_list.status_code == 200
    assert len(res_admin_list.json()) == 3

    # 2. Manager 1 sees tasks for Project 1 (Task 1 & Task 2)
    res_m1_list = await client.get("/tasks/", headers=m1_headers)
    assert res_m1_list.status_code == 200
    m1_task_ids = [t["id"] for t in res_m1_list.json()]
    assert t1_id in m1_task_ids
    assert t2_id in m1_task_ids
    assert t3_id not in m1_task_ids

    # 3. Employee 1 listing: sees Task 1 (assigned) and Task 2 (member team project task)
    res_e1_list = await client.get("/tasks/", headers=e1_headers)
    assert res_e1_list.status_code == 200
    e1_task_ids = [t["id"] for t in res_e1_list.json()]
    assert t1_id in e1_task_ids
    assert t2_id in e1_task_ids
    assert t3_id not in e1_task_ids

    # 4. Employee 1 views Task 2 (member project task) -> 200 OK
    res_e1_get_t2 = await client.get(f"/tasks/{t2_id}", headers=e1_headers)
    assert res_e1_get_t2.status_code == 200

    # 5. Employee 1 views Task 3 (unauthorized team project) -> 403 Forbidden
    res_e1_get_t3 = await client.get(f"/tasks/{t3_id}", headers=e1_headers)
    assert res_e1_get_t3.status_code == 403

    # 6. Employee 1 updates own assigned Task 1 (title, status, priority) -> 200 OK
    res_e1_update_own = await client.put(f"/tasks/{t1_id}", json={
        "title": "Task 1 Done",
        "status": "completed",
        "priority": "high"
    }, headers=e1_headers)
    assert res_e1_update_own.status_code == 200
    assert res_e1_update_own.json()["status"] == "completed"

    # 7. Employee 1 attempts to update Task 2 (assigned to M1) -> 403 Forbidden
    res_e1_update_t2 = await client.put(f"/tasks/{t2_id}", json={"status": "completed"}, headers=e1_headers)
    assert res_e1_update_t2.status_code == 403

    # 8. Employee 1 attempts to update Task 1 with project_id or assigned_to -> 422 Unprocessable Content (Adjustment 1)
    res_e1_hack_proj = await client.put(f"/tasks/{t1_id}", json={"project_id": data["p3_id"]}, headers=e1_headers)
    assert res_e1_hack_proj.status_code == 422

    res_e1_hack_assign = await client.put(f"/tasks/{t1_id}", json={"assigned_to": data["m1_emp_id"]}, headers=e1_headers)
    assert res_e1_hack_assign.status_code == 422

    # 9. Employee attempts to delete task -> 403 Forbidden
    res_e1_del = await client.delete(f"/tasks/{t1_id}", headers=e1_headers)
    assert res_e1_del.status_code == 403

    # 10. Moving task to project where assignee is NOT eligible -> 422 Unprocessable Content
    # (Task 1 assigned to Employee 1; Project 2 is on Team 2 where Employee 1 is NOT eligible)
    res_admin_move_inelig = await client.put(f"/tasks/{t1_id}", json={"project_id": data["p2_id"]}, headers=admin_headers)
    assert res_admin_move_inelig.status_code == 422
