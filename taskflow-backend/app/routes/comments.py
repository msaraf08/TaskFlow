from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from app.core.dependencies import get_current_user
from app.database.dependencies import (
    get_comment_collection,
    get_task_collection,
    get_project_collection,
    get_team_collection,
    get_employee_collection,
    get_activity_collection,
)
from app.schemas.comment_schema import (
    CommentCreateSchema,
    CommentUpdateSchema,
    CommentResponseSchema,
)
from app.services.comment_service import (
    create_comment,
    get_comments_by_task,
    get_comment_by_id,
    update_comment,
    delete_comment,
)
from app.services.task_service import (
    get_task_by_id,
    validate_project_and_team,
)
from app.services.activity_service import log_activity

router = APIRouter(tags=["Comments"])


async def _authorize_task_view(
    current_user: dict,
    task_id: str,
    task_collection,
    project_collection,
    team_collection,
    employee_collection,
) -> tuple[dict, dict, dict]:
    task = await get_task_by_id(task_collection, task_id)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )

    project, team = await validate_project_and_team(
        project_collection,
        team_collection,
        task["project_id"],
    )

    role = current_user.get("role")
    if role == "admin":
        return task, project, team

    emp = await employee_collection.find_one({"user_id": current_user["user_id"]})
    if not emp or emp.get("status") == "inactive":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view or comment on this task",
        )

    emp_id = str(emp["_id"])

    if role == "manager":
        if team.get("manager_id") != emp_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to access comments for this task",
            )
        return task, project, team

    # Role is employee: must be assignee or team member
    if task.get("assigned_to") == emp_id or emp_id in team.get("member_ids", []):
        return task, project, team

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="You do not have permission to access comments for this task",
    )


@router.post(
    "/tasks/{task_id}/comments",
    status_code=status.HTTP_201_CREATED,
    response_model=CommentResponseSchema,
)
async def add_comment(
    task_id: str,
    comment_in: CommentCreateSchema,
    comment_collection=Depends(get_comment_collection),
    task_collection=Depends(get_task_collection),
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    activity_collection=Depends(get_activity_collection),
    current_user=Depends(get_current_user),
):
    task, _, team = await _authorize_task_view(
        current_user,
        task_id,
        task_collection,
        project_collection,
        team_collection,
        employee_collection,
    )

    created_comment = await create_comment(
        comment_collection,
        task_id,
        current_user["user_id"],
        comment_in,
    )

    await log_activity(
        activity_collection=activity_collection,
        actor_user_id=current_user["user_id"],
        action="comment_created",
        entity_type="comment",
        entity_id=created_comment["id"],
        task_id=task_id,
        project_id=task["project_id"],
        team_id=str(team["_id"]),
        metadata={"content_preview": comment_in.content[:100]},
    )

    return created_comment


@router.get(
    "/tasks/{task_id}/comments",
    response_model=List[CommentResponseSchema],
)
async def list_comments(
    task_id: str,
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    comment_collection=Depends(get_comment_collection),
    task_collection=Depends(get_task_collection),
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    current_user=Depends(get_current_user),
):
    await _authorize_task_view(
        current_user,
        task_id,
        task_collection,
        project_collection,
        team_collection,
        employee_collection,
    )

    return await get_comments_by_task(
        comment_collection,
        task_id,
        skip=skip,
        limit=limit,
    )


@router.put(
    "/comments/{comment_id}",
    response_model=CommentResponseSchema,
)
async def edit_comment(
    comment_id: str,
    comment_in: CommentUpdateSchema,
    comment_collection=Depends(get_comment_collection),
    task_collection=Depends(get_task_collection),
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    activity_collection=Depends(get_activity_collection),
    current_user=Depends(get_current_user),
):
    comment = await get_comment_by_id(comment_collection, comment_id)
    if not comment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Comment not found",
        )

    task = await get_task_by_id(task_collection, comment["task_id"])
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Referenced task not found",
        )

    _, team = await validate_project_and_team(
        project_collection,
        team_collection,
        task["project_id"],
    )

    role = current_user.get("role")
    emp = await employee_collection.find_one({"user_id": current_user["user_id"]})

    if role == "employee":
        if comment["user_id"] != current_user["user_id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Employees may only edit their own comments",
            )
    elif role == "manager":
        if not emp or team.get("manager_id") != str(emp["_id"]):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to edit comments for this team's tasks",
            )

    updated = await update_comment(comment_collection, comment_id, comment_in)

    await log_activity(
        activity_collection=activity_collection,
        actor_user_id=current_user["user_id"],
        action="comment_updated",
        entity_type="comment",
        entity_id=comment_id,
        task_id=comment["task_id"],
        project_id=task["project_id"],
        team_id=str(team["_id"]),
        metadata={"content_preview": comment_in.content[:100]},
    )

    return updated


@router.delete(
    "/comments/{comment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def remove_comment(
    comment_id: str,
    comment_collection=Depends(get_comment_collection),
    task_collection=Depends(get_task_collection),
    project_collection=Depends(get_project_collection),
    team_collection=Depends(get_team_collection),
    employee_collection=Depends(get_employee_collection),
    activity_collection=Depends(get_activity_collection),
    current_user=Depends(get_current_user),
):
    comment = await get_comment_by_id(comment_collection, comment_id)
    if not comment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Comment not found",
        )

    task = await get_task_by_id(task_collection, comment["task_id"])
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Referenced task not found",
        )

    _, team = await validate_project_and_team(
        project_collection,
        team_collection,
        task["project_id"],
    )

    role = current_user.get("role")
    emp = await employee_collection.find_one({"user_id": current_user["user_id"]})

    if role == "employee":
        if comment["user_id"] != current_user["user_id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Employees may only delete their own comments",
            )
    elif role == "manager":
        if not emp or team.get("manager_id") != str(emp["_id"]):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to delete comments for this team's tasks",
            )

    content_preview = comment.get("content", "")[:100]
    await delete_comment(comment_collection, comment_id)

    await log_activity(
        activity_collection=activity_collection,
        actor_user_id=current_user["user_id"],
        action="comment_deleted",
        entity_type="comment",
        entity_id=comment_id,
        task_id=comment["task_id"],
        project_id=task["project_id"],
        team_id=str(team["_id"]),
        metadata={"content_preview": content_preview},
    )

    return Response(status_code=status.HTTP_204_NO_CONTENT)
