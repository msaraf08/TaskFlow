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
- **Access:** Authenticated (Any role)
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

---

### 2. Authentication (`/auth`)

#### `POST /auth/register`
- **Description:** Public user registration. The first registered user is bootstrapped with the `admin` role; subsequent registrations default to `employee`.
- **Access:** Public
- **Request Body:**
  ```json
  {
    "name": "John Doe",
    "email": "john@example.com",
    "password": "SecretPassword123"
  }
  ```
- **Response `201 Created`:**
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
  - `400 Bad Request`: Email already registered or invalid fields.

#### `POST /auth/login`
- **Description:** Authenticates credentials and returns a JWT access token.
- **Access:** Public
- **Request Body:**
  ```json
  {
    "email": "john@example.com",
    "password": "SecretPassword123"
  }
  ```
- **Response `200 OK`:**
  ```json
  {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6...",
    "token_type": "bearer"
  }
  ```
- **Errors:**
  - `400 Bad Request`: Invalid email or password.
  - `401 Unauthorized`: Account is inactive.

---

### 3. Employee Management (`/employees`)

#### `POST /employees/`
- **Description:** Creates an employee profile and associated active user account. Generates a secure temporary password if `initial_password` is omitted.
- **Access:** Admin only (`role: admin`)
- **Request Body:**
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
- **Response `201 Created`:**
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
- **Request Body:**
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
- **Request Body:**
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