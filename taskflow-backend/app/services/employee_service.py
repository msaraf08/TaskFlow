from datetime import datetime, time
from bson import ObjectId


async def create_employee(collection, employee_data, user_id):
    employee = employee_data.model_dump()

    if employee.get("joining_date"):
        employee["joining_date"] = datetime.combine(
            employee["joining_date"],
            time.min
        )

    employee["user_id"] = user_id
    employee["status"] = "active"

    result = await collection.insert_one(employee)

    employee["_id"] = str(result.inserted_id)

    return employee


async def get_all_employees(collection):
    employees = []

    async for employee in collection.find():
        employee["_id"] = str(employee["_id"])
        employees.append(employee)

    return employees


async def get_employee_by_id(collection, employee_id: str):
    employee = await collection.find_one(
        {"_id": ObjectId(employee_id)}
    )

    if employee:
        employee["_id"] = str(employee["_id"])

    return employee


async def update_employee(collection, employee_id: str, employee_data):
    update_data = {
        key: value
        for key, value in employee_data.model_dump().items()
        if value is not None
    }

    if not update_data:
        return None

    result = await collection.update_one(
        {"_id": ObjectId(employee_id)},
        {"$set": update_data}
    )

    if result.matched_count == 0:
        return None

    return await get_employee_by_id(collection, employee_id)


async def deactivate_employee(collection, employee_id: str):
    result = await collection.update_one(
        {"_id": ObjectId(employee_id)},
        {"$set": {"status": "inactive"}}
    )

    return result.modified_count > 0