from typing import List
from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, status

from app.core.roles import require_roles
from app.core.security import hash_password, generate_temporary_password
from app.database.dependencies import (
    get_user_collection,
    get_employee_collection,
    get_team_collection,
    get_activity_collection,
)
from app.schemas.employee_schema import (
    EmployeeCreateSchema,
    EmployeeUpdateSchema,
    EmployeeProfileUpdateSchema,
    EmployeeRoleUpdateSchema,
    EmployeeResponseSchema,
    EmployeeCreateResponseSchema,
)
from app.services.employee_service import (
    create_employee,
    get_all_employees,
    get_employee_by_id,
    update_employee,
    update_employee_profile,
    deactivate_employee,
    reactivate_employee,
    update_employee_role,
)
from app.services.activity_service import log_activity

router = APIRouter(
    prefix="/employees",
    tags=["Employees"]
)


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    response_model=EmployeeCreateResponseSchema
)
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
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    temp_password = employee.initial_password or generate_temporary_password()

    user_data = {
        "name": employee.name,
        "email": employee.email,
        "password": hash_password(temp_password),
        "role": employee.role,
        "status": "active"
    }

    user_result = await user_collection.insert_one(user_data)

    employee_data = await create_employee(
        employee_collection,
        employee,
        str(user_result.inserted_id)
    )

    employee_data["temporary_password"] = temp_password
    return employee_data


@router.get(
    "",
    response_model=List[EmployeeResponseSchema],
    include_in_schema=False
)
@router.get(
    "/",
    response_model=List[EmployeeResponseSchema]
)
async def list_employees(
    collection=Depends(get_employee_collection),
    user_collection=Depends(get_user_collection),
    current_user=Depends(require_roles("admin", "manager"))
):
    return await get_all_employees(collection, user_collection=user_collection)


@router.get(
    "/{employee_id}",
    response_model=EmployeeResponseSchema
)
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


@router.put(
    "/{employee_id}",
    response_model=EmployeeResponseSchema
)
async def edit_employee(
    employee_id: str,
    employee: EmployeeUpdateSchema,
    employee_collection=Depends(get_employee_collection),
    user_collection=Depends(get_user_collection),
    current_user=Depends(require_roles("admin"))
):
    updated_employee = await update_employee(
        employee_collection,
        employee_id,
        employee
    )

    if not updated_employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )

    # Sync name/role to user collection if provided
    user_updates = {}
    if employee.name is not None:
        user_updates["name"] = employee.name
    if employee.role is not None:
        user_updates["role"] = employee.role

    if user_updates and updated_employee.get("user_id"):
        try:
            await user_collection.update_one(
                {"_id": ObjectId(updated_employee["user_id"])},
                {"$set": user_updates}
            )
        except Exception:
            pass

    return updated_employee


@router.patch(
    "/{employee_id}",
    response_model=EmployeeResponseSchema
)
async def update_profile(
    employee_id: str,
    payload: EmployeeProfileUpdateSchema,
    employee_collection=Depends(get_employee_collection),
    user_collection=Depends(get_user_collection),
    current_user=Depends(require_roles("admin")),
):
    return await update_employee_profile(
        employee_collection=employee_collection,
        user_collection=user_collection,
        employee_id=employee_id,
        payload=payload,
    )


@router.patch("/{employee_id}/deactivate")
async def deactivate(
    employee_id: str,
    employee_collection=Depends(get_employee_collection),
    user_collection=Depends(get_user_collection),
    team_collection=Depends(get_team_collection),
    activity_collection=Depends(get_activity_collection),
    current_user=Depends(require_roles("admin")),
):
    deactivated = await deactivate_employee(
        employee_collection=employee_collection,
        user_collection=user_collection,
        team_collection=team_collection,
        employee_id=employee_id,
        actor_user_id=current_user["user_id"],
    )

    await log_activity(
        activity_collection=activity_collection,
        actor_user_id=current_user["user_id"],
        action="user_deactivated",
        entity_type="employee",
        entity_id=employee_id,
        metadata={
            "name": deactivated.get("name"),
            "status": "inactive",
        },
    )

    return {
        "message": "Employee deactivated successfully",
        "employee": deactivated,
    }


@router.patch("/{employee_id}/reactivate")
async def reactivate(
    employee_id: str,
    employee_collection=Depends(get_employee_collection),
    user_collection=Depends(get_user_collection),
    activity_collection=Depends(get_activity_collection),
    current_user=Depends(require_roles("admin")),
):
    reactivated = await reactivate_employee(
        employee_collection=employee_collection,
        user_collection=user_collection,
        employee_id=employee_id,
        actor_user_id=current_user["user_id"],
    )

    await log_activity(
        activity_collection=activity_collection,
        actor_user_id=current_user["user_id"],
        action="user_reactivated",
        entity_type="employee",
        entity_id=employee_id,
        metadata={
            "name": reactivated.get("name"),
            "status": "active",
        },
    )

    return {
        "message": "Employee reactivated successfully",
        "employee": reactivated,
    }


@router.patch(
    "/{employee_id}/role",
    response_model=EmployeeResponseSchema
)
async def change_employee_role(
    employee_id: str,
    payload: EmployeeRoleUpdateSchema,
    employee_collection=Depends(get_employee_collection),
    user_collection=Depends(get_user_collection),
    team_collection=Depends(get_team_collection),
    activity_collection=Depends(get_activity_collection),
    current_user=Depends(require_roles("admin")),
):
    updated_employee, old_role = await update_employee_role(
        employee_collection=employee_collection,
        user_collection=user_collection,
        team_collection=team_collection,
        employee_id=employee_id,
        new_role=payload.role,
        actor_user_id=current_user["user_id"],
    )

    if old_role != payload.role:
        await log_activity(
            activity_collection=activity_collection,
            actor_user_id=current_user["user_id"],
            action="user_role_changed",
            entity_type="employee",
            entity_id=employee_id,
            metadata={
                "old_value": old_role,
                "new_value": payload.role,
                "name": updated_employee.get("name"),
            },
        )

    return updated_employee