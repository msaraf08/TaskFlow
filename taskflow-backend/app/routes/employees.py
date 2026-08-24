from fastapi import APIRouter, Depends, HTTPException, status

from app.core.roles import require_roles
from app.core.security import hash_password
from app.database.dependencies import (
    get_user_collection,
    get_employee_collection
)
from app.schemas.employee_schema import (
    EmployeeCreateSchema,
    EmployeeUpdateSchema
)
from app.services.employee_service import (
    create_employee,
    get_all_employees,
    get_employee_by_id,
    update_employee,
    deactivate_employee
)


router = APIRouter(
    prefix="/employees",
    tags=["Employees"]
)


@router.post("/")
async def add_employee(
    employee: EmployeeCreateSchema,
    employee_collection=Depends(get_employee_collection),
    user_collection=Depends(get_user_collection),
    current_user=Depends(require_roles("admin"))
):
    existing_user = await user_collection.find_one(
        {"email": employee.email}
    )

    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )

    user_data = {
        "name": employee.name,
        "email": employee.email,
        "password": hash_password("Temp@123"),
        "role": employee.role
    }

    user_result = await user_collection.insert_one(user_data)

    employee_data = await create_employee(
        employee_collection,
        employee,
        str(user_result.inserted_id)
    )

    return employee_data


@router.get("/")
async def list_employees(
    collection=Depends(get_employee_collection),
    current_user=Depends(require_roles("admin", "manager"))
):
    return await get_all_employees(collection)


@router.get("/{employee_id}")
async def get_employee(
    employee_id: str,
    collection=Depends(get_employee_collection),
    current_user=Depends(require_roles("admin", "manager"))
):
    employee = await get_employee_by_id(collection, employee_id)

    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )

    return employee


@router.put("/{employee_id}")
async def edit_employee(
    employee_id: str,
    employee: EmployeeUpdateSchema,
    collection=Depends(get_employee_collection),
    current_user=Depends(require_roles("admin"))
):
    updated_employee = await update_employee(
        collection,
        employee_id,
        employee
    )

    if not updated_employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )

    return updated_employee


@router.patch("/{employee_id}/deactivate")
async def deactivate(
    employee_id: str,
    collection=Depends(get_employee_collection),
    current_user=Depends(require_roles("admin"))
):
    success = await deactivate_employee(
        collection,
        employee_id
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )

    return {
        "message": "Employee deactivated successfully"
    }