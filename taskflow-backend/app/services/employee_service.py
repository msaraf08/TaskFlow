from datetime import datetime, time
from typing import List, Optional
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


async def get_all_employees(collection) -> List[dict]:
    employees = []
    async for employee in collection.find():
        employee["id"] = str(employee["_id"])
        employee["_id"] = str(employee["_id"])
        employees.append(employee)
    return employees


async def get_employee_by_id(collection, employee_id: str) -> Optional[dict]:
    obj_id = validate_object_id(employee_id)
    employee = await collection.find_one({"_id": obj_id})

    if employee:
        employee["id"] = str(employee["_id"])
        employee["_id"] = str(employee["_id"])

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