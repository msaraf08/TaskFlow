from datetime import datetime
from bson import ObjectId
import pytest
from app.core.jwt import create_access_token
from app.core.security import hash_password


@pytest.fixture
async def setup_users_and_employees(mock_users_collection, mock_employees_collection):
    # 1. Admin
    admin_user = await mock_users_collection.insert_one({
        "name": "Admin User",
        "email": "admin@taskflow.local",
        "password": hash_password("AdminPass123"),
        "role": "admin",
        "status": "active"
    })
    admin_token = create_access_token({"user_id": str(admin_user.inserted_id), "role": "admin"})

    # 2. Manager 1
    m1_user = await mock_users_collection.insert_one({
        "name": "Manager One",
        "email": "m1@taskflow.local",
        "password": hash_password("ManagerPass123"),
        "role": "manager",
        "status": "active"
    })
    m1_emp = await mock_employees_collection.insert_one({
        "user_id": str(m1_user.inserted_id),
        "name": "Manager One",
        "email": "m1@taskflow.local",
        "phone": "555-1111",
        "department": "Engineering",
        "role": "manager",
        "joining_date": datetime(2026, 1, 1),
        "status": "active"
    })
    m1_token = create_access_token({"user_id": str(m1_user.inserted_id), "role": "manager"})

    # 3. Manager 2
    m2_user = await mock_users_collection.insert_one({
        "name": "Manager Two",
        "email": "m2@taskflow.local",
        "password": hash_password("ManagerPass123"),
        "role": "manager",
        "status": "active"
    })
    m2_emp = await mock_employees_collection.insert_one({
        "user_id": str(m2_user.inserted_id),
        "name": "Manager Two",
        "email": "m2@taskflow.local",
        "phone": "555-2222",
        "department": "Product",
        "role": "manager",
        "joining_date": datetime(2026, 1, 1),
        "status": "active"
    })
    m2_token = create_access_token({"user_id": str(m2_user.inserted_id), "role": "manager"})

    # 4. Inactive Manager
    m_inact_user = await mock_users_collection.insert_one({
        "name": "Inactive Manager",
        "email": "minact@taskflow.local",
        "password": hash_password("ManagerPass123"),
        "role": "manager",
        "status": "inactive"
    })
    m_inact_emp = await mock_employees_collection.insert_one({
        "user_id": str(m_inact_user.inserted_id),
        "name": "Inactive Manager",
        "email": "minact@taskflow.local",
        "phone": "555-0000",
        "department": "Engineering",
        "role": "manager",
        "joining_date": datetime(2026, 1, 1),
        "status": "inactive"
    })

    # 5. Regular Active Employee 1
    e1_user = await mock_users_collection.insert_one({
        "name": "Employee One",
        "email": "e1@taskflow.local",
        "password": hash_password("EmpPass123"),
        "role": "employee",
        "status": "active"
    })
    e1_emp = await mock_employees_collection.insert_one({
        "user_id": str(e1_user.inserted_id),
        "name": "Employee One",
        "email": "e1@taskflow.local",
        "phone": "555-3331",
        "department": "Engineering",
        "role": "employee",
        "joining_date": datetime(2026, 2, 1),
        "status": "active"
    })
    e1_token = create_access_token({"user_id": str(e1_user.inserted_id), "role": "employee"})

    # 6. Regular Active Employee 2
    e2_user = await mock_users_collection.insert_one({
        "name": "Employee Two",
        "email": "e2@taskflow.local",
        "password": hash_password("EmpPass123"),
        "role": "employee",
        "status": "active"
    })
    e2_emp = await mock_employees_collection.insert_one({
        "user_id": str(e2_user.inserted_id),
        "name": "Employee Two",
        "email": "e2@taskflow.local",
        "phone": "555-3332",
        "department": "Engineering",
        "role": "employee",
        "joining_date": datetime(2026, 2, 1),
        "status": "active"
    })
    e2_token = create_access_token({"user_id": str(e2_user.inserted_id), "role": "employee"})

    # 7. Inactive Employee
    e_inact_user = await mock_users_collection.insert_one({
        "name": "Inactive Employee",
        "email": "einact@taskflow.local",
        "password": hash_password("EmpPass123"),
        "role": "employee",
        "status": "inactive"
    })
    e_inact_emp = await mock_employees_collection.insert_one({
        "user_id": str(e_inact_user.inserted_id),
        "name": "Inactive Employee",
        "email": "einact@taskflow.local",
        "phone": "555-0001",
        "department": "Engineering",
        "role": "employee",
        "joining_date": datetime(2026, 2, 1),
        "status": "inactive"
    })

    return {
        "admin": {"token": f"Bearer {admin_token}", "user_id": str(admin_user.inserted_id)},
        "m1": {"token": f"Bearer {m1_token}", "emp_id": str(m1_emp.inserted_id)},
        "m2": {"token": f"Bearer {m2_token}", "emp_id": str(m2_emp.inserted_id)},
        "m_inactive": {"emp_id": str(m_inact_emp.inserted_id)},
        "e1": {"token": f"Bearer {e1_token}", "emp_id": str(e1_emp.inserted_id)},
        "e2": {"token": f"Bearer {e2_token}", "emp_id": str(e2_emp.inserted_id)},
        "e_inactive": {"emp_id": str(e_inact_emp.inserted_id)}
    }


@pytest.mark.asyncio
async def test_team_crud_lifecycle(client, setup_users_and_employees):
    data = setup_users_and_employees
    admin_headers = {"Authorization": data["admin"]["token"]}

    # 1. Create team with manager
    resp_create = await client.post(
        "/teams/",
        headers=admin_headers,
        json={
            "name": "Core Platform",
            "description": "Platform infrastructure and core APIs",
            "manager_id": data["m1"]["emp_id"]
        }
    )
    assert resp_create.status_code == 201
    team = resp_create.json()
    team_id = team["id"]
    assert team["name"] == "Core Platform"
    assert team["description"] == "Platform infrastructure and core APIs"
    assert team["manager_id"] == data["m1"]["emp_id"]
    assert team["member_ids"] == []

    # 2. Get team
    resp_get = await client.get(f"/teams/{team_id}", headers=admin_headers)
    assert resp_get.status_code == 200
    assert resp_get.json()["id"] == team_id

    # 3. Partial update: change only name (description and manager_id preserved)
    resp_update = await client.put(
        f"/teams/{team_id}",
        headers=admin_headers,
        json={"name": "Core Platform Engineering"}
    )
    assert resp_update.status_code == 200
    updated_team = resp_update.json()
    assert updated_team["name"] == "Core Platform Engineering"
    assert updated_team["description"] == "Platform infrastructure and core APIs"
    assert updated_team["manager_id"] == data["m1"]["emp_id"]

    # 4. Partial update: change manager_id to Manager 2
    resp_update_mgr = await client.put(
        f"/teams/{team_id}",
        headers=admin_headers,
        json={"manager_id": data["m2"]["emp_id"]}
    )
    assert resp_update_mgr.status_code == 200
    assert resp_update_mgr.json()["manager_id"] == data["m2"]["emp_id"]

    # 5. Delete team
    resp_del = await client.delete(f"/teams/{team_id}", headers=admin_headers)
    assert resp_del.status_code == 204

    # 6. Verify team is gone
    resp_get_deleted = await client.get(f"/teams/{team_id}", headers=admin_headers)
    assert resp_get_deleted.status_code == 404


@pytest.mark.asyncio
async def test_team_manager_validation(client, setup_users_and_employees):
    data = setup_users_and_employees
    admin_headers = {"Authorization": data["admin"]["token"]}

    # Nonexistent manager ID -> 404
    non_existent_id = str(ObjectId())
    resp_nonexistent = await client.post(
        "/teams/",
        headers=admin_headers,
        json={"name": "Alpha Team", "manager_id": non_existent_id}
    )
    assert resp_nonexistent.status_code == 404

    # Inactive manager -> 403
    resp_inactive = await client.post(
        "/teams/",
        headers=admin_headers,
        json={"name": "Alpha Team", "manager_id": data["m_inactive"]["emp_id"]}
    )
    assert resp_inactive.status_code == 403

    # Employee role as manager -> 422
    resp_invalid_role = await client.post(
        "/teams/",
        headers=admin_headers,
        json={"name": "Alpha Team", "manager_id": data["e1"]["emp_id"]}
    )
    assert resp_invalid_role.status_code == 422


@pytest.mark.asyncio
async def test_team_member_assignment_and_removal(client, setup_users_and_employees):
    data = setup_users_and_employees
    admin_headers = {"Authorization": data["admin"]["token"]}

    # Create team
    resp_create = await client.post(
        "/teams/",
        headers=admin_headers,
        json={"name": "DevOps Team", "manager_id": data["m1"]["emp_id"]}
    )
    team_id = resp_create.json()["id"]

    # 1. Assign valid employee (e1)
    resp_assign = await client.post(
        f"/teams/{team_id}/members",
        headers=admin_headers,
        json={"employee_id": data["e1"]["emp_id"]}
    )
    assert resp_assign.status_code == 200
    assert data["e1"]["emp_id"] in resp_assign.json()["member_ids"]

    # 2. Duplicate assignment -> 409 Conflict
    resp_dup = await client.post(
        f"/teams/{team_id}/members",
        headers=admin_headers,
        json={"employee_id": data["e1"]["emp_id"]}
    )
    assert resp_dup.status_code == 409

    # 3. Assign inactive employee -> 403 Forbidden
    resp_inact = await client.post(
        f"/teams/{team_id}/members",
        headers=admin_headers,
        json={"employee_id": data["e_inactive"]["emp_id"]}
    )
    assert resp_inact.status_code == 403

    # 4. Assign nonexistent employee -> 404 Not Found
    resp_nonexistent = await client.post(
        f"/teams/{team_id}/members",
        headers=admin_headers,
        json={"employee_id": str(ObjectId())}
    )
    assert resp_nonexistent.status_code == 404

    # 5. Attempt to add team manager as member -> 400 Bad Request
    resp_mgr_member = await client.post(
        f"/teams/{team_id}/members",
        headers=admin_headers,
        json={"employee_id": data["m1"]["emp_id"]}
    )
    assert resp_mgr_member.status_code == 400

    # 6. Assign second employee (e2)
    await client.post(
        f"/teams/{team_id}/members",
        headers=admin_headers,
        json={"employee_id": data["e2"]["emp_id"]}
    )

    # 7. Remove e1 from team -> 204 No Content
    resp_remove = await client.delete(
        f"/teams/{team_id}/members/{data['e1']['emp_id']}",
        headers=admin_headers
    )
    assert resp_remove.status_code == 204

    # 8. Remove non-member (e1 already removed) -> 404 Not Found
    resp_remove_nonmember = await client.delete(
        f"/teams/{team_id}/members/{data['e1']['emp_id']}",
        headers=admin_headers
    )
    assert resp_remove_nonmember.status_code == 404

    # 9. Verify team member_ids only contains e2
    resp_final = await client.get(f"/teams/{team_id}", headers=admin_headers)
    assert resp_final.status_code == 200
    assert resp_final.json()["member_ids"] == [data["e2"]["emp_id"]]


@pytest.mark.asyncio
async def test_team_rbac_and_ownership(client, setup_users_and_employees):
    data = setup_users_and_employees
    admin_headers = {"Authorization": data["admin"]["token"]}
    m1_headers = {"Authorization": data["m1"]["token"]}
    m2_headers = {"Authorization": data["m2"]["token"]}
    e1_headers = {"Authorization": data["e1"]["token"]}

    # Manager 1 creates team 1
    resp_t1 = await client.post(
        "/teams/",
        headers=m1_headers,
        json={"name": "M1 Team", "manager_id": data["m1"]["emp_id"]}
    )
    assert resp_t1.status_code == 201
    t1_id = resp_t1.json()["id"]

    # Manager 2 creates team 2
    resp_t2 = await client.post(
        "/teams/",
        headers=m2_headers,
        json={"name": "M2 Team", "manager_id": data["m2"]["emp_id"]}
    )
    assert resp_t2.status_code == 201
    t2_id = resp_t2.json()["id"]

    # 1. Manager 1 can update own team (T1)
    resp_m1_edit_own = await client.put(
        f"/teams/{t1_id}",
        headers=m1_headers,
        json={"name": "M1 Team Updated"}
    )
    assert resp_m1_edit_own.status_code == 200

    # 2. Manager 1 CANNOT update Manager 2's team (T2) -> 403 Forbidden
    resp_m1_edit_other = await client.put(
        f"/teams/{t2_id}",
        headers=m1_headers,
        json={"name": "Malicious Rename"}
    )
    assert resp_m1_edit_other.status_code == 403

    # 3. Manager 1 can assign member to own team
    resp_m1_assign_own = await client.post(
        f"/teams/{t1_id}/members",
        headers=m1_headers,
        json={"employee_id": data["e1"]["emp_id"]}
    )
    assert resp_m1_assign_own.status_code == 200

    # 4. Manager 1 CANNOT assign member to Manager 2's team -> 403 Forbidden
    resp_m1_assign_other = await client.post(
        f"/teams/{t2_id}/members",
        headers=m1_headers,
        json={"employee_id": data["e1"]["emp_id"]}
    )
    assert resp_m1_assign_other.status_code == 403

    # 5. Manager 1 CANNOT delete Manager 2's team -> 403 Forbidden
    resp_m1_del_other = await client.delete(f"/teams/{t2_id}", headers=m1_headers)
    assert resp_m1_del_other.status_code == 403

    # 6. Employee 1 CANNOT create team -> 403 Forbidden
    resp_e1_create = await client.post(
        "/teams/",
        headers=e1_headers,
        json={"name": "Unauthorized Team"}
    )
    assert resp_e1_create.status_code == 403

    # 7. Employee 1 can view T1 (where they are a member)
    resp_e1_view_t1 = await client.get(f"/teams/{t1_id}", headers=e1_headers)
    assert resp_e1_view_t1.status_code == 200

    # 8. Employee 1 CANNOT view T2 (where they are NOT a member) -> 403 Forbidden
    resp_e1_view_t2 = await client.get(f"/teams/{t2_id}", headers=e1_headers)
    assert resp_e1_view_t2.status_code == 403

    # 9. Employee 1 listing teams only sees T1, not T2
    resp_e1_list = await client.get("/teams/", headers=e1_headers)
    assert resp_e1_list.status_code == 200
    e1_teams = resp_e1_list.json()
    assert len(e1_teams) == 1
    assert e1_teams[0]["id"] == t1_id

    # 10. Manager 1 can delete own team (T1) -> 204 No Content
    resp_m1_del_own = await client.delete(f"/teams/{t1_id}", headers=m1_headers)
    assert resp_m1_del_own.status_code == 204


@pytest.mark.asyncio
async def test_team_malformed_objectids(client, setup_users_and_employees):
    data = setup_users_and_employees
    admin_headers = {"Authorization": data["admin"]["token"]}

    # Bad team ID on GET
    assert (await client.get("/teams/bad-id", headers=admin_headers)).status_code == 400

    # Bad team ID on PUT
    assert (await client.put("/teams/bad-id", headers=admin_headers, json={"name": "N"})).status_code == 400

    # Bad team ID on DELETE
    assert (await client.delete("/teams/bad-id", headers=admin_headers)).status_code == 400

    # Bad team ID on POST member
    assert (await client.post("/teams/bad-id/members", headers=admin_headers, json={"employee_id": data["e1"]["emp_id"]})).status_code == 400

    # Create real team to test bad employee ID
    create_resp = await client.post("/teams/", headers=admin_headers, json={"name": "Validation Team"})
    valid_team_id = create_resp.json()["id"]

    # Bad employee ID on POST member
    assert (await client.post(f"/teams/{valid_team_id}/members", headers=admin_headers, json={"employee_id": "bad-emp-id"})).status_code == 400

    # Bad employee ID on DELETE member
    assert (await client.delete(f"/teams/{valid_team_id}/members/bad-emp-id", headers=admin_headers)).status_code == 400
