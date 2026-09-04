# API Documentation

## Base URL

`http://localhost:8000`

---

## Authentication & Authorization

Protected endpoints require a standard Bearer token in the `Authorization` HTTP header:

```http
Authorization: Bearer <access_token>
```

Tokens are validated against cryptographic signatures, expiration time, and active database status.

- If a token is invalid, expired, or the user account no longer exists, the API returns `401 Unauthorized`.
- If the token is valid but the account is marked `status: "inactive"`, the API returns `403 Forbidden`.
- If an authenticated user attempts an operation restricted to a higher role or unauthorized resource (e.g. modifying another manager's team), the API returns `403 Forbidden`.

---

## Endpoints

### 1. Health & Diagnostics

#### `GET /`
- **Description:** Returns service welcome message.
- **Access:** Public
- **Response `200 OK`:**
  ```json
  {
    "message": "Welcome to TaskFlow"
  }
  ```

#### `GET /health`
- **Description:** Health check diagnostic endpoint.
- **Access:** Public
- **Response `200 OK`:**
  ```json
  {
    "status": "healthy"
  }
  ```

#### `GET /protected`
- **Description:** Diagnostic route verifying token validity and user state.
- **Access:** Authenticated (Any active role)
- **Response `200 OK`:**
  ```json
  {
    "message": "You are authenticated",
    "user": {
      "user_id": "string",
      "name": "string",
      "email": "user@example.com",
      "role": "admin | manager | employee",
      "status": "active"
    }
  }
  ```
- **Errors:**
  - `401 Unauthorized`: Missing, expired, malformed token, or user no longer exists.
  - `403 Forbidden`: User account is inactive.

---

### 2. Authentication & User Profile (`/auth`)

#### `POST /auth/register`
- **Description:** Public user registration. The first registered user is bootstrapped with the `admin` role; subsequent registrations default to `employee`.
- **Access:** Public
- **Request Body (`UserCreateSchema`):**
  ```json
  {
    "name": "John Doe",
    "email": "john@example.com",
    "password": "SecretPassword123"
  }
  ```
- **Response `201 Created` (`UserRegisterResponseSchema`):**
  ```json
  {
    "message": "User registered successfully",
    "user": {
      "id": "6a99d4398a5cbc1907f06f9a",
      "name": "John Doe",
      "email": "john@example.com",
      "role": "employee",
      "status": "active"
    }
  }
  ```
- **Errors:**
  - `400 Bad Request`: Email already registered.
  - `422 Unprocessable Entity`: Validation failure (e.g. password shorter than 8 characters or extra unexpected fields).

#### `POST /auth/login`
- **Description:** Authenticates credentials and returns a JWT access token.
- **Access:** Public
- **Request Body (`UserLoginSchema`):**
  ```json
  {
    "email": "john@example.com",
    "password": "SecretPassword123"
  }
  ```
- **Response `200 OK` (`TokenResponseSchema`):**
  ```json
  {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6...",
    "token_type": "bearer"
  }
  ```
- **Errors:**
  - `400 Bad Request`: Invalid email or password.
  - `403 Forbidden`: User account is inactive.
  - `422 Unprocessable Entity`: Validation failure.

#### `GET /auth/me`
- **Description:** Retrieves the profile of the currently authenticated active user directly from MongoDB (omitting password hash).
- **Access:** Authenticated (Any active role)
- **Response `200 OK` (`UserResponseSchema`):**
  ```json
  {
    "id": "6a99d4398a5cbc1907f06f9a",
    "name": "John Doe",
    "email": "john@example.com",
    "role": "employee",
    "status": "active"
  }
  ```
- **Errors:**
  - `401 Unauthorized`: Token invalid, expired, malformed, or user account deleted from database.
  - `403 Forbidden`: User account is inactive.

#### `PUT /auth/password`
- **Description:** Securely updates the authenticated user's password after verifying the current password. Performs an atomic MongoDB update.
- **Access:** Authenticated (Any active role)
- **Request Body (`UserPasswordChangeSchema`):**
  ```json
  {
    "current_password": "OldPassword123",
    "new_password": "NewSecretPassword123"
  }
  ```
- **Response `200 OK` (`PasswordChangeResponseSchema`):**
  ```json
  {
    "message": "Password changed successfully"
  }
  ```
- **Errors:**
  - `401 Unauthorized`: Token invalid, user deleted, or incorrect current password.
  - `403 Forbidden`: User account is inactive.
  - `422 Unprocessable Entity`: Validation failure (e.g., new password shorter than 8 characters or extra forbidden fields).

---

### 3. Employee Management (`/employees`)

#### `POST /employees/`
- **Description:** Creates an employee profile and associated active user account. Generates a secure temporary password if `initial_password` is omitted.
- **Access:** Admin only (`role: admin`)
- **Request Body (`EmployeeCreateSchema`):**
  ```json
  {
    "name": "Jane Smith",
    "email": "jane.smith@example.com",
    "phone": "+1-555-0199",
    "department": "Engineering",
    "role": "employee",
    "joining_date": "2026-09-01",
    "initial_password": "OptionalCustomPassword123"
  }
  ```
- **Response `201 Created` (`EmployeeCreateResponseSchema`):**
  ```json
  {
    "id": "6a99d4398a5cbc1907f06f9b",
    "user_id": "6a99d4398a5cbc1907f06f9c",
    "name": "Jane Smith",
    "email": "jane.smith@example.com",
    "phone": "+1-555-0199",
    "department": "Engineering",
    "role": "employee",
    "joining_date": "2026-09-01",
    "status": "active",
    "temporary_password": "secure_random_or_initial_pwd"
  }
  ```

#### `GET /employees/`
- **Description:** Retrieves list of all employees.
- **Access:** Admin or Manager (`role: admin, manager`)
- **Response `200 OK`:** Array of `EmployeeResponseSchema`.

#### `GET /employees/{employee_id}`
- **Description:** Retrieves employee details by ID.
- **Access:** Admin or Manager (`role: admin, manager`)
- **Response `200 OK`:** `EmployeeResponseSchema`.
- **Errors:**
  - `400 Bad Request`: Malformed ObjectId.
  - `404 Not Found`: Employee does not exist.

#### `PUT /employees/{employee_id}`
- **Description:** Updates employee details (and syncs name/role to user account).
- **Access:** Admin only (`role: admin`)
- **Request Body (`EmployeeUpdateSchema`):**
  ```json
  {
    "name": "Jane Doe",
    "phone": "+1-555-0200",
    "department": "Product",
    "role": "manager",
    "joining_date": "2026-09-01"
  }
  ```
- **Response `200 OK`:** `EmployeeResponseSchema`.
- **Errors:**
  - `400 Bad Request`: Malformed ObjectId.
  - `404 Not Found`: Employee does not exist.

#### `PATCH /employees/{employee_id}/deactivate`
- **Description:** Deactivates employee and revokes user login access (`status: "inactive"`).
- **Access:** Admin only (`role: admin`)
- **Response `200 OK`:**
  ```json
  {
    "message": "Employee deactivated successfully"
  }
  ```
- **Errors:**
  - `400 Bad Request`: Malformed ObjectId.
  - `404 Not Found`: Employee does not exist.

---

### 4. Team Management (`/teams`)

#### `POST /teams/`
- **Description:** Creates a new team with an empty member roster. Validates manager role and active status if assigned.
- **Access:** Admin or Manager (`role: admin, manager`)
- **Request Body (`TeamCreateSchema`):**
  ```json
  {
    "name": "Backend Guild",
    "description": "API and infrastructure engineering",
    "manager_id": "6a99d4398a5cbc1907f06f9a"
  }
  ```
- **Response `201 Created` (`TeamResponseSchema`):**
  ```json
  {
    "id": "6a99d4398a5cbc1907f06f9e",
    "name": "Backend Guild",
    "description": "API and infrastructure engineering",
    "manager_id": "6a99d4398a5cbc1907f06f9a",
    "member_ids": []
  }
  ```
- **Errors:**
  - `400 Bad Request`: Malformed `manager_id`.
  - `403 Forbidden`: Manager account is inactive.
  - `404 Not Found`: Manager employee does not exist.
  - `422 Unprocessable Entity`: Assigned manager does not hold a manager or admin role.

#### `GET /teams/`
- **Description:** Retrieves all teams for Admins and Managers; retrieves only teams where the authenticated employee is a member for Employees.
- **Access:** Authenticated (Admin, Manager, Employee)
- **Response `200 OK`:** Array of `TeamResponseSchema`.

#### `GET /teams/{team_id}`
- **Description:** Retrieves team details by ID. Admins and Managers can view any team; Employees can view only if they are in `member_ids`.
- **Access:** Authenticated (Admin, Manager, or assigned Employee member)
- **Response `200 OK`:** `TeamResponseSchema`.
- **Errors:**
  - `400 Bad Request`: Malformed `team_id`.
  - `403 Forbidden`: Employee is not a member of the team.
  - `404 Not Found`: Team does not exist.

#### `PUT /teams/{team_id}`
- **Description:** Performs a partial update on team fields (`name`, `description`, `manager_id`). `member_ids` cannot be altered through this endpoint.
- **Access:** Admin or Manager of own team (`team.manager_id == manager.employee_id`)
- **Request Body (`TeamUpdateSchema`):**
  ```json
  {
    "name": "Platform & Backend Guild",
    "description": "Updated team scope",
    "manager_id": "6a99d4398a5cbc1907f06f9b"
  }
  ```
- **Response `200 OK`:** `TeamResponseSchema`.
- **Errors:**
  - `400 Bad Request`: Malformed `team_id` or `manager_id`.
  - `403 Forbidden`: Manager does not manage this team, or manager account is inactive.
  - `404 Not Found`: Team or manager does not exist.
  - `422 Unprocessable Entity`: Assigned manager is not a manager or admin, or validation failure.

#### `DELETE /teams/{team_id}`
- **Description:** Hard deletes a team document from MongoDB.
- **Access:** Admin or Manager of own team (`team.manager_id == manager.employee_id`)
- **Response `204 No Content`**
- **Errors:**
  - `400 Bad Request`: Malformed `team_id`.
  - `403 Forbidden`: Manager does not manage this team.
  - `404 Not Found`: Team does not exist.

#### `POST /teams/{team_id}/members`
- **Description:** Assigns an active employee to the team member roster using `$addToSet`. Managers cannot be added to `member_ids`.
- **Access:** Admin or Manager of own team (`team.manager_id == manager.employee_id`)
- **Request Body (`TeamMemberAssignSchema`):**
  ```json
  {
    "employee_id": "6a99d4398a5cbc1907f06f9c"
  }
  ```
- **Response `200 OK`:** `TeamResponseSchema`.
- **Errors:**
  - `400 Bad Request`: Malformed IDs or attempting to add the team manager as a member.
  - `403 Forbidden`: Manager does not manage this team, or employee is inactive.
  - `404 Not Found`: Team or employee does not exist.
  - `409 Conflict`: Employee is already a member of this team.

#### `DELETE /teams/{team_id}/members/{employee_id}`
- **Description:** Removes an employee from the team member roster using `$pull`.
- **Access:** Admin or Manager of own team (`team.manager_id == manager.employee_id`)
- **Response `204 No Content`**
- **Errors:**
  - `400 Bad Request`: Malformed IDs.
  - `403 Forbidden`: Manager does not manage this team.
  - `404 Not Found`: Team does not exist, or employee is not a member of the team.

---

### 5. Project Management (`/projects`)

#### `POST /projects/`
- **Description:** Creates a new project associated with a team. Validates manager ownership on the target team.
- **Access:** Admin or Manager of target team (`team.manager_id == manager.employee_id`)
- **Request Body (`ProjectCreateSchema`):**
  ```json
  {
    "name": "Mobile Redesign",
    "description": "Flutter app UI overhaul",
    "team_id": "6a99d4398a5cbc1907f06f9e",
    "start_date": "2026-09-10",
    "end_date": "2026-10-15",
    "status": "planned"
  }
  ```
- **Response `201 Created` (`ProjectResponseSchema`):**
  ```json
  {
    "id": "6a99d4398a5cbc1907f06fa1",
    "name": "Mobile Redesign",
    "description": "Flutter app UI overhaul",
    "team_id": "6a99d4398a5cbc1907f06f9e",
    "start_date": "2026-09-10",
    "end_date": "2026-10-15",
    "status": "planned",
    "created_by": "6a99d4398a5cbc1907f06f9a",
    "created_at": "2026-09-04T15:20:00.000Z",
    "updated_at": "2026-09-04T15:20:00.000Z"
  }
  ```
- **Errors:**
  - `400 Bad Request`: Malformed `team_id`.
  - `401 Unauthorized`: Missing or invalid authentication token.
  - `403 Forbidden`: Inactive user, non-manager role, or manager does not manage the target team.
  - `404 Not Found`: Target team does not exist.
  - `422 Unprocessable Entity`: Validation failure (empty name, `start_date > end_date`, invalid status, or extra forbidden fields).

#### `GET /projects/`
- **Description:** Retrieves projects visible to the authenticated user. Admins see all projects; Managers see projects belonging to teams they manage; Employees see projects belonging to teams where they are enrolled in `member_ids`.
- **Query Parameters:**
  - `team_id` (optional): Filter projects by team.
- **Access:** Authenticated (Admin, Manager, Employee)
- **Response `200 OK`:** Array of `ProjectResponseSchema` (sorted by `created_at` descending, returns `[]` if none).

#### `GET /projects/{project_id}`
- **Description:** Retrieves project details by ID. Validates manager ownership or employee team membership.
- **Access:** Authenticated (Admin, Manager of project's team, or Employee in project's team)
- **Response `200 OK`:** `ProjectResponseSchema`.
- **Errors:**
  - `400 Bad Request`: Malformed `project_id`.
  - `401 Unauthorized`: Missing or invalid authentication token.
  - `403 Forbidden`: Inactive user or unauthorized user (manager does not manage team, or employee not a member).
  - `404 Not Found`: Project or referenced team does not exist.

#### `PUT /projects/{project_id}`
- **Description:** Performs a partial update on project fields (`name`, `description`, `team_id`, `start_date`, `end_date`, `status`). If `team_id` is updated, the user must be authorized for both the current team and target team.
- **Access:** Admin or Manager of project's current team (and target team if changed)
- **Request Body (`ProjectUpdateSchema`):**
  ```json
  {
    "name": "Mobile Redesign V2",
    "status": "active"
  }
  ```
- **Response `200 OK`:** `ProjectResponseSchema`.
- **Errors:**
  - `400 Bad Request`: Malformed `project_id` or `team_id`.
  - `401 Unauthorized`: Missing or invalid authentication token.
  - `403 Forbidden`: Inactive user or unauthorized manager for current or new target team.
  - `404 Not Found`: Project or new target team does not exist.
  - `422 Unprocessable Entity`: Validation failure (empty name, `start_date > end_date`, invalid status, or extra forbidden fields).

#### `DELETE /projects/{project_id}`
- **Description:** Permanently removes a project document from MongoDB.
- **Access:** Admin or Manager of project's team (`team.manager_id == manager.employee_id`)
- **Response `204 No Content`**
- **Errors:**
  - `400 Bad Request`: Malformed `project_id`.
  - `401 Unauthorized`: Missing or invalid authentication token.
  - `403 Forbidden`: Inactive user or manager does not manage the project's team.
  - `404 Not Found`: Project does not exist.

---

### 6. Task Management (`/tasks`)

#### `POST /tasks/`
- **Description:** Creates a new task within a project and assigns it to an eligible employee. Validates manager ownership on the project's team and employee eligibility (`member_ids` OR `manager_id`).
- **Access:** Admin or Manager of project's team (`team.manager_id == manager.employee_id`)
- **Request Body (`TaskCreateSchema`):**
  ```json
  {
    "title": "Build Auth API",
    "description": "Implement JWT endpoints",
    "project_id": "6a99d4398a5cbc1907f06fa1",
    "assigned_to": "6a99d4398a5cbc1907f06f9c",
    "priority": "high",
    "status": "todo",
    "due_date": "2026-09-20"
  }
  ```
- **Response `201 Created` (`TaskResponseSchema`):**
  ```json
  {
    "id": "6a99d4398a5cbc1907f06fb1",
    "title": "Build Auth API",
    "description": "Implement JWT endpoints",
    "project_id": "6a99d4398a5cbc1907f06fa1",
    "assigned_to": "6a99d4398a5cbc1907f06f9c",
    "priority": "high",
    "status": "todo",
    "due_date": "2026-09-20",
    "created_by": "6a99d4398a5cbc1907f06f9a",
    "created_at": "2026-09-04T15:50:00.000Z",
    "updated_at": "2026-09-04T15:50:00.000Z"
  }
  ```
- **Errors:**
  - `400 Bad Request`: Malformed `project_id` or `assigned_to`.
  - `401 Unauthorized`: Missing or invalid authentication token.
  - `403 Forbidden`: Inactive user, manager not managing the project's team, inactive assigned employee, or assigned employee not eligible for the project's team.
  - `404 Not Found`: Project, project team, or assigned employee not found.
  - `422 Unprocessable Entity`: Validation failure (empty title, invalid priority/status enum, or extra forbidden fields).

#### `GET /tasks/`
- **Description:** Retrieves tasks visible to the authenticated user. Admins see all tasks; Managers see tasks for projects on teams they manage; Employees see tasks assigned to them AND tasks in projects of teams where they are a member.
- **Query Parameters:**
  - `project_id` (optional): Filter tasks by project.
  - `assigned_to` (optional): Filter tasks by assignee.
- **Access:** Authenticated (Admin, Manager, Employee)
- **Response `200 OK`:** Array of `TaskResponseSchema` (sorted by `created_at` descending, returns `[]` if none).

#### `GET /tasks/{task_id}`
- **Description:** Retrieves task details by ID. Validates manager ownership or employee visibility (assigned or team member).
- **Access:** Authenticated (Admin, Manager of project's team, or Employee assigned / member of project's team)
- **Response `200 OK`:** `TaskResponseSchema`.
- **Errors:**
  - `400 Bad Request`: Malformed `task_id`.
  - `401 Unauthorized`: Missing or invalid authentication token.
  - `403 Forbidden`: Unauthorized user (manager does not manage team, or employee not assigned nor member).
  - `404 Not Found`: Task or referenced project/team not found.

#### `PUT /tasks/{task_id}`
- **Description:** Performs a partial update on task fields (`title`, `description`, `project_id`, `assigned_to`, `priority`, `status`, `due_date`). Employees can only update their own assigned tasks and are restricted to updating `title`, `description`, `priority`, `status`, `due_date` (submitting `project_id` or `assigned_to` returns 422).
- **Access:** Admin, Manager of project's team, or assigned Employee
- **Request Body (`TaskUpdateSchema`):**
  ```json
  {
    "status": "in_progress",
    "priority": "urgent"
  }
  ```
- **Response `200 OK`:** `TaskResponseSchema`.
- **Errors:**
  - `400 Bad Request`: Malformed `task_id`, `project_id`, or `assigned_to`.
  - `401 Unauthorized`: Missing or invalid authentication token.
  - `403 Forbidden`: Unauthorized manager, employee not assigned to task, or newly assigned employee not eligible.
  - `404 Not Found`: Task, project, team, or employee not found.
  - `422 Unprocessable Entity`: Employee submitting `project_id`/`assigned_to`, moving task to project where current assignee is ineligible, invalid enums, or extra forbidden fields.

#### `DELETE /tasks/{task_id}`
- **Description:** Permanently removes a task document from MongoDB and cascade-deletes all associated comments. Related historical activity trail records are preserved.
- **Access:** Admin or Manager of task's project team (`team.manager_id == manager.employee_id`)
- **Response `204 No Content`**
- **Errors:**
  - `400 Bad Request`: Malformed `task_id`.
  - `401 Unauthorized`: Missing or invalid authentication token.
  - `403 Forbidden`: Inactive user, employee role, or manager does not manage the task's project team.
  - `404 Not Found`: Task not found.

---

### 7. Comments (`/tasks/{task_id}/comments`, `/comments/{comment_id}`)

#### `POST /tasks/{task_id}/comments`
- **Description:** Creates a new comment on an existing task.
- **Access:** Authenticated users authorized to view the task:
  - Admin: Any task.
  - Manager: Tasks on projects of managed teams.
  - Employee: Tasks assigned to them or in projects of teams where they are a member.
- **Request Body (`CommentCreateSchema`):**
  ```json
  {
    "content": "Implemented user authentication and wrote unit tests."
  }
  ```
- **Response `201 Created` (`CommentResponseSchema`):**
  ```json
  {
    "id": "6a99d4398a5cbc1907f06fc1",
    "task_id": "6a99d4398a5cbc1907f06fb1",
    "user_id": "6a99d4398a5cbc1907f06f9a",
    "content": "Implemented user authentication and wrote unit tests.",
    "created_at": "2026-09-04T16:00:00.000Z",
    "updated_at": "2026-09-04T16:00:00.000Z"
  }
  ```
- **Errors:**
  - `400 Bad Request`: Malformed `task_id`.
  - `401 Unauthorized`: Missing or invalid token.
  - `403 Forbidden`: Inactive user or user not authorized to view/comment on the task.
  - `404 Not Found`: Task not found.
  - `422 Unprocessable Entity`: Empty content, content exceeding 2000 chars, or extra fields.

#### `GET /tasks/{task_id}/comments`
- **Description:** Lists comments for a task sorted by `created_at` descending with pagination.
- **Query Parameters:**
  - `skip` (int, default 0, ge 0)
  - `limit` (int, default 20, ge 1, le 100)
- **Access:** Authenticated users authorized to view the task.
- **Response `200 OK`:** Array of `CommentResponseSchema` (returns `[]` if no comments).

#### `PUT /comments/{comment_id}`
- **Description:** Edits the content of an existing comment. Updates `updated_at`.
- **Access:**
  - Admin: Any comment.
  - Manager: Comments on tasks in managed teams' projects.
  - Employee: Own comments only (`comment.user_id == JWT user_id`).
- **Request Body (`CommentUpdateSchema`):**
  ```json
  {
    "content": "Updated comment details with test results."
  }
  ```
- **Response `200 OK`:** `CommentResponseSchema`.
- **Errors:**
  - `400 Bad Request`: Malformed `comment_id`.
  - `401 Unauthorized`: Missing or invalid token.
  - `403 Forbidden`: Inactive user, manager not managing task's team, or employee attempting to edit another user's comment.
  - `404 Not Found`: Comment or referenced task not found.
  - `422 Unprocessable Entity`: Empty content or content > 2000 characters.

#### `DELETE /comments/{comment_id}`
- **Description:** Permanently deletes a comment document.
- **Access:**
  - Admin: Any comment.
  - Manager: Comments on tasks in managed teams' projects.
  - Employee: Own comments only (`comment.user_id == JWT user_id`).
- **Response `204 No Content`**
- **Errors:**
  - `400 Bad Request`: Malformed `comment_id`.
  - `401 Unauthorized`: Missing or invalid token.
  - `403 Forbidden`: Inactive user, manager not managing task's team, or employee attempting to delete another user's comment.
  - `404 Not Found`: Comment or referenced task not found.

---

### 8. Activities & Audit Trail (`/activities`)

#### `GET /activities/`
- **Description:** Retrieves system activity and audit trail records with scoped visibility and query filtering.
- **Query Parameters:**
  - `task_id` (optional string): Filter by task ObjectId.
  - `project_id` (optional string): Filter by project ObjectId.
  - `team_id` (optional string): Filter by team ObjectId.
  - `actor_user_id` (optional string): Filter by actor's user ID.
  - `action` (optional string): Filter by action enum (`task_created`, `task_updated`, `task_deleted`, `task_assigned_changed`, `task_status_changed`, `task_priority_changed`, `task_project_changed`, `comment_created`, `comment_updated`, `comment_deleted`).
  - `entity_type` (optional string): Filter by entity type enum (`task`, `comment`, `project`, `team`).
  - `skip` (int, default 0, ge 0)
  - `limit` (int, default 20, ge 1, le 100)
- **Access & Scoping:**
  - Admin: Sees all activities.
  - Manager: Sees activities where `team_id` matches a team they manage.
  - Employee: Sees activities for tasks visible to them (assigned to them or in a project of a team where they are a member). Activities without a visible `task_id` are not accessible to employees.
- **Response `200 OK`:** Array of `ActivityResponseSchema` sorted by `created_at` descending:
  ```json
  [
    {
      "id": "6a99d4398a5cbc1907f06fd1",
      "actor_user_id": "6a99d4398a5cbc1907f06f9a",
      "action": "task_status_changed",
      "entity_type": "task",
      "entity_id": "6a99d4398a5cbc1907f06fb1",
      "task_id": "6a99d4398a5cbc1907f06fb1",
      "project_id": "6a99d4398a5cbc1907f06fa1",
      "team_id": "6a99d4398a5cbc1907f06f9e",
      "metadata": {
        "old_value": "todo",
        "new_value": "in_progress"
      },
      "created_at": "2026-09-04T16:15:00.000Z"
    }
  ]
  ```
- **Errors:**
  - `400 Bad Request`: Malformed `task_id`, `project_id`, or `team_id`.
  - `401 Unauthorized`: Missing or invalid token.
  - `403 Forbidden`: Inactive user account.
  - `422 Unprocessable Entity`: Invalid `action` or `entity_type` parameter.

---

### 9. Redis Integration, Caching & Rate Limiting

#### Caching Strategy
- **Cached Endpoints (Detail only):**
  - `GET /teams/{team_id}` (key: `team:{team_id}`)
  - `GET /projects/{project_id}` (key: `project:{project_id}`)
  - `GET /tasks/{task_id}` (key: `task:{task_id}`)
- **Cache TTL:** 300 seconds (5 minutes).
- **Serialization:** Standard JSON with embedded ISO timestamp (`_cached_at`).
- **Authorization Before Cache Access:** The system strictly evaluates authentication and role-based permissions before returning cached data. Unauthorized users receive `403 Forbidden` without viewing cached entity payloads.
- **Cache Invalidation:**
  - `PUT /teams/{team_id}`, `DELETE /teams/{team_id}`, `POST /teams/{team_id}/members`, `DELETE /teams/{team_id}/members/{employee_id}` -> invalidates `team:{team_id}`.
  - `PUT /projects/{project_id}`, `DELETE /projects/{project_id}` -> invalidates `project:{project_id}`.
  - `PUT /tasks/{task_id}`, `DELETE /tasks/{task_id}` -> invalidates `task:{task_id}`.
- **Resilience:** If Redis is offline or encounters errors, the API fails open and queries MongoDB transparently.

#### Authentication Rate Limiting
- **Protected Endpoints:**
  - `POST /auth/login`
  - `POST /auth/register`
  - `PUT /auth/password`
- **Policy:** Fixed-window limiter of 5 requests per 60 seconds per client IP.
- **Key Format:** `ratelimit:{endpoint}:{client_ip}`
- **Exceeded Limit Response (`429 Too Many Requests`):**
  ```http
  HTTP/1.1 429 Too Many Requests
  Retry-After: 48
  Content-Type: application/json

  {
    "detail": "Too many requests"
  }
  ```
- **Fail-Open Behavior:** If Redis is down, authentication endpoints log a warning and continue processing requests.