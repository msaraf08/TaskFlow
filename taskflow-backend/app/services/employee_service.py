from datetime import datetime, time, timezone
from typing import List, Optional
from fastapi import HTTPException, status
from app.utils.object_id import validate_object_id


async def create_employee(collection, employee_data, user_id: str) -> dict:
    employee = employee_data.model_dump(exclude={"initial_password"})

    if employee.get("joining_date"):
        employee["joining_date"] = datetime.combine(
            employee["joining_date"],
            time.min
        )

    employee["user_id"] = user_id
    employee["status"] = "active"

    result = await collection.insert_one(employee)
    employee["id"] = str(result.inserted_id)
    employee["_id"] = str(result.inserted_id)

    return employee


async def get_all_employees(collection, user_collection=None) -> List[dict]:
    if user_collection is not None:
        async for user in user_collection.find():
            user_id = str(user["_id"])
            emp = await collection.find_one({"$or": [{"user_id": user_id}, {"email": user.get("email")}]})
            if not emp:
                new_emp = {
                    "user_id": user_id,
                    "name": user.get("name", "User"),
                    "email": user.get("email", ""),
                    "phone": "",
                    "department": "Executive" if user.get("role") == "admin" else "General",
                    "role": user.get("role", "employee"),
                    "joining_date": datetime.combine(datetime.now(timezone.utc).date(), time.min),
                    "status": user.get("status", "active") or "active",
                }
                res = await collection.insert_one(new_emp)
                new_emp["_id"] = res.inserted_id

    employees = []
    async for employee in collection.find():
        employee["id"] = str(employee["_id"])
        employee["_id"] = str(employee["_id"])
        if not employee.get("phone"):
            employee["phone"] = ""
        if not employee.get("department"):
            employee["department"] = "General"
        if isinstance(employee.get("joining_date"), datetime):
            employee["joining_date"] = employee["joining_date"].date()
        employees.append(employee)
    return employees


async def get_employee_by_id(collection, employee_id: str) -> Optional[dict]:
    obj_id = validate_object_id(employee_id)
    employee = await collection.find_one({"_id": obj_id})

    if employee:
        employee["id"] = str(employee["_id"])
        employee["_id"] = str(employee["_id"])
        if isinstance(employee.get("joining_date"), datetime):
            employee["joining_date"] = employee["joining_date"].date()

    return employee


async def update_employee(collection, employee_id: str, employee_data) -> Optional[dict]:
    obj_id = validate_object_id(employee_id)
    update_data = {
        key: value
        for key, value in employee_data.model_dump().items()
        if value is not None
    }

    if not update_data:
        return await get_employee_by_id(collection, employee_id)

    if update_data.get("joining_date"):
        update_data["joining_date"] = datetime.combine(
            update_data["joining_date"],
            time.min
        )

    result = await collection.update_one(
        {"_id": obj_id},
        {"$set": update_data}
    )

    if result.matched_count == 0:
        return None

    return await get_employee_by_id(collection, employee_id)


async def deactivate_employee(collection, employee_id: str) -> Optional[dict]:
    obj_id = validate_object_id(employee_id)
    employee = await collection.find_one({"_id": obj_id})

    if not employee:
        return None

    await collection.update_one(
        {"_id": obj_id},
        {"$set": {"status": "inactive"}}
    )

    employee["id"] = str(employee["_id"])
    employee["status"] = "inactive"
    return employee


async def update_employee_role(
    employee_collection,
    user_collection,
    team_collection,
    employee_id: str,
    new_role: str,
    actor_user_id: str,
) -> tuple[dict, str]:
    obj_id = validate_object_id(employee_id)
    employee = await employee_collection.find_one({"_id": obj_id})
    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )

    user_id_raw = employee.get("user_id")
    if not user_id_raw:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    user_obj_id = validate_object_id(user_id_raw)
    user = await user_collection.find_one({"_id": user_obj_id})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    if str(actor_user_id) == str(user_id_raw):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrators cannot change their own role."
        )

    old_role = employee.get("role", "employee")

    if old_role == new_role:
        employee["id"] = str(employee["_id"])
        employee["_id"] = str(employee["_id"])
        return employee, old_role

    if old_role == "admin" and new_role != "admin":
        admin_count = await user_collection.count_documents({"role": "admin"})
        if admin_count <= 1 and user.get("role") == "admin":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Cannot remove the last administrator."
            )

    if old_role in ("manager", "admin") and new_role not in ("manager", "admin"):
        managed_teams_cursor = team_collection.find({
            "$or": [
                {"manager_id": str(employee["_id"])},
                {"manager_id": employee["_id"]},
            ]
        })
        managed_teams = []
        async for t in managed_teams_cursor:
            managed_teams.append(t)

        if managed_teams:
            count = len(managed_teams)
            name = employee.get("name", "this user")
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Cannot demote {name}. They are currently managing {count} team(s). Reassign those teams first."
            )

    # Two-phase update with rollback
    emp_update_res = await employee_collection.update_one(
        {"_id": obj_id},
        {"$set": {"role": new_role}}
    )
    if emp_update_res.matched_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )

    try:
        user_update_res = await user_collection.update_one(
            {"_id": user_obj_id},
            {"$set": {"role": new_role}}
        )
        if user_update_res.matched_count == 0:
            raise Exception("User not matched during role update")
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(
            f"User role update failed for user {user_id_raw}, rolling back: {e}"
        )
        try:
            rollback_res = await employee_collection.update_one(
                {"_id": obj_id},
                {"$set": {"role": old_role}}
            )
            if rollback_res.matched_count == 0:
                raise Exception("Rollback matched 0 documents")
        except Exception as rb_err:
            logging.getLogger(__name__).critical(
                f"CRITICAL: Rollback failed for employee {employee_id}: {rb_err}"
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Critical error: Role synchronization failed and rollback was unsuccessful."
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update user role; changes have been rolled back."
        )

    updated_employee = await get_employee_by_id(employee_collection, employee_id)
    return updated_employee or employee, old_role