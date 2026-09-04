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
- If an authenticated user attempts an operation restricted to a higher role, the API returns `403 Forbidden`.

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
- **Description:** Creates a new team.
- **Access:** Admin or Manager (`role: admin, manager`)
- **Request Body (`TeamCreateSchema`):**
  ```json
  {
    "name": "Backend Guild",
    "description": "API and infrastructure engineering",
    "manager_id": "6a99d4398a5cbc1907f06f9a"
  }
  ```
- **Response `201 Created`:**
  ```json
  {
    "id": "6a99d4398a5cbc1907f06f9e",
    "name": "Backend Guild",
    "description": "API and infrastructure engineering",
    "manager_id": "6a99d4398a5cbc1907f06f9a",
    "member_ids": []
  }
  ```

#### `GET /teams/`
- **Description:** Retrieves list of all teams.
- **Access:** Admin or Manager (`role: admin, manager`)
- **Response `200 OK`:** Array of `TeamResponseSchema`.

#### `GET /teams/{team_id}`
- **Description:** Retrieves team details by ID.
- **Access:** Admin or Manager (`role: admin, manager`)
- **Response `200 OK`:** `TeamResponseSchema`.
- **Errors:**
  - `400 Bad Request`: Malformed ObjectId.
  - `404 Not Found`: Team does not exist.