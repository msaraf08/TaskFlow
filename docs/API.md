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