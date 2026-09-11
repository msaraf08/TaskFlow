import pytest
from bson import ObjectId


@pytest.mark.asyncio
async def test_admin_can_update_employee_name_and_sync_user(
    client, mock_users_collection, mock_employees_collection
):
    # Setup Admin user and token
    admin_user_id = str(ObjectId())
    admin_emp_id = str(ObjectId())
    await mock_users_collection.insert_one({
        "_id": ObjectId(admin_user_id),
        "name": "Admin User",
        "email": "admin@example.com",
        "role": "admin",
        "status": "active"
    })
    await mock_employees_collection.insert_one({
        "_id": ObjectId(admin_emp_id),
        "user_id": admin_user_id,
        "name": "Admin User",
        "email": "admin@example.com",
        "role": "admin",
        "department": "Exec",
        "phone": "1111111111",
        "status": "active"
    })

    # Setup target employee
    target_user_id = str(ObjectId())
    target_emp_id = str(ObjectId())
    await mock_users_collection.insert_one({
        "_id": ObjectId(target_user_id),
        "name": "Old Name",
        "email": "employee@example.com",
        "role": "employee",
        "status": "active"
    })
    await mock_employees_collection.insert_one({
        "_id": ObjectId(target_emp_id),
        "user_id": target_user_id,
        "name": "Old Name",
        "email": "employee@example.com",
        "role": "employee",
        "department": "General",
        "phone": "2222222222",
        "status": "active"
    })

    from app.core.jwt import create_access_token
    token = create_access_token({"user_id": admin_user_id, "role": "admin"})

    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.patch(
        f"/employees/{target_emp_id}",
        headers=headers,
        json={"name": "New Name"}
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["name"] == "New Name"
    assert data["phone"] == "2222222222"  # Preserved
    assert data["department"] == "General"  # Preserved

    # Verify employees collection updated
    emp_doc = await mock_employees_collection.find_one({"_id": ObjectId(target_emp_id)})
    assert emp_doc["name"] == "New Name"

    # Verify users collection synchronized
    user_doc = await mock_users_collection.find_one({"_id": ObjectId(target_user_id)})
    assert user_doc["name"] == "New Name"


@pytest.mark.asyncio
async def test_admin_can_update_phone_and_department(
    client, mock_users_collection, mock_employees_collection
):
    admin_user_id = str(ObjectId())
    await mock_users_collection.insert_one({
        "_id": ObjectId(admin_user_id),
        "name": "Admin User",
        "email": "admin@example.com",
        "role": "admin",
        "status": "active"
    })

    target_user_id = str(ObjectId())
    target_emp_id = str(ObjectId())
    await mock_employees_collection.insert_one({
        "_id": ObjectId(target_emp_id),
        "user_id": target_user_id,
        "name": "Swayam",
        "email": "swayam@example.com",
        "role": "employee",
        "department": "General",
        "phone": "",
        "status": "active"
    })
    await mock_users_collection.insert_one({
        "_id": ObjectId(target_user_id),
        "name": "Swayam",
        "email": "swayam@example.com",
        "role": "employee",
        "status": "active"
    })

    from app.core.jwt import create_access_token
    token = create_access_token({"user_id": admin_user_id, "role": "admin"})
    headers = {"Authorization": f"Bearer {token}"}

    # Add phone and change department
    resp = await client.patch(
        f"/employees/{target_emp_id}",
        headers=headers,
        json={
            "phone": "  +1-555-0199  ",
            "department": "  Engineering  "
        }
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["phone"] == "+1-555-0199"
    assert data["department"] == "Engineering"
    assert data["name"] == "Swayam"


@pytest.mark.asyncio
async def test_admin_can_clear_optional_phone_and_department(
    client, mock_users_collection, mock_employees_collection
):
    admin_user_id = str(ObjectId())
    await mock_users_collection.insert_one({
        "_id": ObjectId(admin_user_id),
        "name": "Admin",
        "email": "admin@example.com",
        "role": "admin",
        "status": "active"
    })

    target_user_id = str(ObjectId())
    target_emp_id = str(ObjectId())
    await mock_employees_collection.insert_one({
        "_id": ObjectId(target_emp_id),
        "user_id": target_user_id,
        "name": "Tanish",
        "email": "tanish@example.com",
        "role": "employee",
        "department": "Development",
        "phone": "+1987654321",
        "status": "active"
    })
    await mock_users_collection.insert_one({
        "_id": ObjectId(target_user_id),
        "name": "Tanish",
        "email": "tanish@example.com",
        "role": "employee",
        "status": "active"
    })

    from app.core.jwt import create_access_token
    token = create_access_token({"user_id": admin_user_id, "role": "admin"})
    headers = {"Authorization": f"Bearer {token}"}

    # Clear phone with empty string
    resp = await client.patch(
        f"/employees/{target_emp_id}",
        headers=headers,
        json={"phone": ""}
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["phone"] == ""
    assert data["department"] == "Development"

    # Clear department with null
    resp2 = await client.patch(
        f"/employees/{target_emp_id}",
        headers=headers,
        json={"department": None}
    )
    assert resp2.status_code == 200
    data2 = resp2.json()
    assert data2["department"] == ""


@pytest.mark.asyncio
async def test_rbac_and_field_security_for_profile_updates(
    client, mock_users_collection, mock_employees_collection
):
    admin_user_id = str(ObjectId())
    mgr_user_id = str(ObjectId())
    emp_user_id = str(ObjectId())
    target_emp_id = str(ObjectId())

    await mock_users_collection.insert_one({
        "_id": ObjectId(admin_user_id),
        "name": "Admin",
        "email": "admin@example.com",
        "role": "admin",
        "status": "active"
    })
    await mock_users_collection.insert_one({
        "_id": ObjectId(mgr_user_id),
        "name": "Manager",
        "email": "mgr@example.com",
        "role": "manager",
        "status": "active"
    })
    await mock_users_collection.insert_one({
        "_id": ObjectId(emp_user_id),
        "name": "Employee",
        "email": "emp@example.com",
        "role": "employee",
        "status": "active"
    })
    await mock_employees_collection.insert_one({
        "_id": ObjectId(target_emp_id),
        "user_id": emp_user_id,
        "name": "Target Employee",
        "email": "target@example.com",
        "role": "employee",
        "department": "Engineering",
        "phone": "123",
        "status": "active"
    })

    from app.core.jwt import create_access_token
    admin_token = create_access_token({"user_id": admin_user_id, "role": "admin"})
    mgr_token = create_access_token({"user_id": mgr_user_id, "role": "manager"})
    emp_token = create_access_token({"user_id": emp_user_id, "role": "employee"})

    # 1. Employee cannot update profile via this endpoint -> 403
    resp_emp = await client.patch(
        f"/employees/{target_emp_id}",
        headers={"Authorization": f"Bearer {emp_token}"},
        json={"name": "Hacked Name"}
    )
    assert resp_emp.status_code == 403

    # 2. Manager cannot update profile via this endpoint -> 403
    resp_mgr = await client.patch(
        f"/employees/{target_emp_id}",
        headers={"Authorization": f"Bearer {mgr_token}"},
        json={"name": "Hacked Name"}
    )
    assert resp_mgr.status_code == 403

    # 3. Disallowed fields rejected (422): email, role, status, user_id, joining_date, unknown
    for forbidden_field, val in [
        ("email", "newemail@test.com"),
        ("role", "admin"),
        ("status", "inactive"),
        ("user_id", str(ObjectId())),
        ("joining_date", "2026-01-01"),
        ("unknown_custom_field", "value"),
    ]:
        resp_bad = await client.patch(
            f"/employees/{target_emp_id}",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={forbidden_field: val}
        )
        assert resp_bad.status_code == 422, f"Expected 422 for field {forbidden_field}, got {resp_bad.status_code}"

    # 4. Empty name or whitespace name rejected -> 422
    resp_empty_name = await client.patch(
        f"/employees/{target_emp_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"name": "   "}
    )
    assert resp_empty_name.status_code == 422

    # 5. Malformed employee ID -> 400
    resp_malformed = await client.patch(
        "/employees/invalid-id-123",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"name": "Valid Name"}
    )
    assert resp_malformed.status_code == 400

    # 6. Missing employee -> 404
    missing_id = str(ObjectId())
    resp_missing = await client.patch(
        f"/employees/{missing_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"name": "Valid Name"}
    )
    assert resp_missing.status_code == 404
