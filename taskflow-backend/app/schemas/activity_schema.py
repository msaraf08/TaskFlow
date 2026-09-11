from datetime import datetime
from enum import Enum
from typing import Any, Dict, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


class ActivityAction(str, Enum):
    TASK_CREATED = "task_created"
    TASK_UPDATED = "task_updated"
    TASK_DELETED = "task_deleted"
    TASK_ASSIGNED_CHANGED = "task_assigned_changed"
    TASK_STATUS_CHANGED = "task_status_changed"
    TASK_PRIORITY_CHANGED = "task_priority_changed"
    TASK_PROJECT_CHANGED = "task_project_changed"
    COMMENT_CREATED = "comment_created"
    COMMENT_UPDATED = "comment_updated"
    COMMENT_DELETED = "comment_deleted"
    USER_ROLE_CHANGED = "user_role_changed"
    USER_DEACTIVATED = "user_deactivated"
    USER_REACTIVATED = "user_reactivated"


class ActivityEntityType(str, Enum):
    TASK = "task"
    COMMENT = "comment"
    PROJECT = "project"
    TEAM = "team"
    EMPLOYEE = "employee"


ALLOWED_METADATA_KEYS = {
    "old_value",
    "new_value",
    "title",
    "name",
    "assigned_to",
    "content_preview",
    "status",
}


def sanitize_metadata(meta: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if not meta:
        return None
    sanitized = {}
    for k, v in meta.items():
        if k in ALLOWED_METADATA_KEYS:
            if isinstance(v, (str, int, float, bool)) or v is None:
                if isinstance(v, str) and k == "content_preview":
                    sanitized[k] = v[:100]
                else:
                    sanitized[k] = v
        if len(sanitized) >= 5:
            break
    return sanitized if sanitized else None


class ActivityResponseSchema(BaseModel):
    id: str
    actor_user_id: str
    actor_name: Optional[str] = None
    action: str
    entity_type: str
    entity_id: str
    task_id: Optional[str] = None
    project_id: Optional[str] = None
    team_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
    created_at: datetime
