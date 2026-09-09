# Common Errors & Troubleshooting

## 1. Passlib and bcrypt compatibility issue

### Error
`ValueError: password cannot be longer than 72 bytes`

### Cause
`passlib 1.7.4` has compatibility issues with `bcrypt >= 5.0.0`.

### Solution
Pin `bcrypt` to version `4.3.0` in `requirements.txt`:
```bash
pip install bcrypt==4.3.0
```

---

## 2. Authentication & Authorization Error Scenarios

### HTTP 401 Unauthorized
- **Cause 1 (Invalid/Expired Token):** Bearer token is expired, malformed, or has an invalid cryptographic signature.
  - *Resolution:* Re-authenticate via `POST /auth/login` to obtain a fresh access token.
- **Cause 2 (User Account Deleted):** Token was issued for a user whose record has since been removed from the database.
  - *Resolution:* The account no longer exists; registration or administrator re-creation is required.
- **Cause 3 (Incorrect Current Password):** During `PUT /auth/password`, the provided `current_password` does not match the stored bcrypt hash.
  - *Resolution:* Verify and supply the correct existing password.

### HTTP 403 Forbidden
- **Cause 1 (Inactive User Account):** The user's status is set to `"inactive"`.
  - *Resolution:* Contact an administrator to reactivate the account.
- **Cause 2 (Insufficient Role Permissions):** The user's role (e.g., `employee` or `manager`) does not have permission for the requested administrative route (e.g., creating an employee).
  - *Resolution:* Request appropriate role elevation from an administrator.

### HTTP 422 Unprocessable Entity
- **Cause 1 (Weak/Short Password):** Password supplied to registration or password change is shorter than 8 characters.
  - *Resolution:* Provide a password with at least 8 characters.
- **Cause 2 (Extra Unexpected Fields):** Request payload contains unexpected fields when `extra="forbid"` is enforced.
  - *Resolution:* Strip unmodeled fields from the request JSON body.

### HTTP 400 Bad Request
- **Cause 1 (Malformed ObjectId):** URL parameter contains a string that is not a valid 24-character hexadecimal ObjectId.
  - *Resolution:* Ensure valid ObjectId strings are used in path parameters.
- **Cause 2 (Duplicate Email Registration):** Attempted registration with an email that is already in use.
  - *Resolution:* Use a unique email address or proceed to login.

---

## 3. Team Management Error Scenarios

### HTTP 400 Bad Request
- **Cause 1 (Malformed ObjectId in Path or Body):** `team_id`, `manager_id`, or `employee_id` is not a valid 24-character hexadecimal string.
  - *Resolution:* Provide valid 24-hex-character MongoDB ObjectIds.
- **Cause 2 (Manager Assigned as Member):** Attempted to add the team manager into the team's `member_ids` list.
  - *Resolution:* Managers cannot be added to `member_ids` for their own team; team managers are tracked via `manager_id`.

### HTTP 403 Forbidden
- **Cause 1 (Manager Modifying Another Manager's Team):** A manager attempted to update, delete, or modify membership on a team where `team.manager_id != current_user_employee_id`.
  - *Resolution:* Managers can only manage their own assigned teams. Contact an admin to update team ownership.
- **Cause 2 (Employee Viewing Unassigned Team):** An employee attempted to view details of a team they do not belong to.
  - *Resolution:* Employees can only view teams where their `employee_id` is listed in `member_ids`.
- **Cause 3 (Inactive Member or Manager):** Attempted to assign an inactive employee as manager or member.
  - *Resolution:* Reactivate the employee profile before assigning to a team.

### HTTP 404 Not Found
- **Cause 1 (Team Not Found):** Specified `team_id` does not exist in the `teams` collection.
  - *Resolution:* Verify the team ID.
- **Cause 2 (Manager or Member Employee Not Found):** Specified `manager_id` or `employee_id` does not exist in the `employees` collection.
  - *Resolution:* Verify that the employee profile exists before assigning to a team.
- **Cause 3 (Member Not in Team on Removal):** `DELETE /teams/{team_id}/members/{employee_id}` called for an employee not currently in `member_ids`.
  - *Resolution:* Verify that the employee is currently enrolled in the team.

### HTTP 409 Conflict
- **Cause 1 (Duplicate Team Member):** Attempted to add an employee who is already in `member_ids`.
  - *Resolution:* No action needed; the employee is already assigned to the team.

### HTTP 422 Unprocessable Entity
- **Cause 1 (Invalid Manager Role):** Assigned `manager_id` belongs to an employee whose role is `employee` instead of `manager` or `admin`.
  - *Resolution:* Promote the employee to `manager` or `admin` prior to assigning as team manager.

---

## 4. Project Management Error Scenarios

### HTTP 400 Bad Request
- **Cause 1 (Malformed ObjectId in Path or Body):** `project_id` or `team_id` is not a valid 24-character hexadecimal string.
  - *Resolution:* Provide valid 24-hex-character MongoDB ObjectIds in URL parameters and request bodies.

### HTTP 403 Forbidden
- **Cause 1 (Manager Managing Unassigned Team Project):** A manager attempted to create, update, or delete a project for a team they do not manage (`team.manager_id != current_user_employee_id`).
  - *Resolution:* Managers can only manage projects for teams they are assigned to lead.
- **Cause 2 (Manager Transferring to Unassigned Team):** A manager attempted to change a project's `team_id` to a team they do not manage.
  - *Resolution:* Team changes require manager ownership over both the current and new target teams.
- **Cause 3 (Employee Accessing Unassigned Project):** An employee attempted to view details of a project whose `team_id` does not include their `employee_id` in `member_ids`.
  - *Resolution:* Employees can only view projects for teams they are enrolled in.
- **Cause 4 (Employee Mutating Project):** An employee attempted `POST /projects/`, `PUT /projects/{id}`, or `DELETE /projects/{id}`.
  - *Resolution:* Project mutations are restricted to Admins and designated Team Managers.

### HTTP 404 Not Found
- **Cause 1 (Project Not Found):** Specified `project_id` does not exist in the `projects` collection.
  - *Resolution:* Verify the project ID.
- **Cause 2 (Team Not Found on Creation or Update):** Specified `team_id` does not exist in the `teams` collection.
  - *Resolution:* Verify the team exists prior to attaching a project.

### HTTP 422 Unprocessable Entity
- **Cause 1 (Invalid Date Range):** Project `end_date` is earlier than `start_date`.
  - *Resolution:* Ensure `end_date >= start_date`.
- **Cause 2 (Invalid Project Status):** Provided `status` is not one of `planned`, `active`, `completed`, or `cancelled`.
  - *Resolution:* Provide a valid status enum value.

---

## 5. Task Management Error Scenarios

### HTTP 400 Bad Request
- **Cause 1 (Malformed ObjectId in Path or Body):** `task_id`, `project_id`, or `assigned_to` is not a valid 24-character hexadecimal ObjectId.
  - *Resolution:* Provide valid 24-hex-character MongoDB ObjectIds.

### HTTP 403 Forbidden
- **Cause 1 (Ineligible Assignee):** Assigned employee is not a member of the project's team and not the team's manager.
  - *Resolution:* Assign only active members or the manager of the team owning the project.
- **Cause 2 (Manager Creating/Updating Task in Unmanaged Project):** Manager attempted to create or move a task in a project belonging to a team they do not manage.
  - *Resolution:* Managers can only manage tasks within their own teams' projects.
- **Cause 3 (Employee Modifying Unauthorized Fields):** Employee attempted to change `project_id` or `assigned_to` (returns 422).
  - *Resolution:* Employees can only modify title, description, priority, status, and due date on their own assigned tasks.

### HTTP 404 Not Found
- **Cause 1 (Task Not Found):** Specified `task_id` does not exist in `tasks`.
  - *Resolution:* Verify task ID.
- **Cause 2 (Project or Assignee Not Found):** Specified `project_id` or `assigned_to` employee does not exist in the database.
  - *Resolution:* Ensure project and employee records exist prior to task creation.

### HTTP 422 Unprocessable Entity
- **Cause 1 (Restricted Field Mutation by Employee):** Employee provided `project_id` or `assigned_to` in update payload.
  - *Resolution:* Strip reassignment fields from employee update requests.
- **Cause 2 (Invalid Status or Priority):** Provided status or priority does not match permitted enum values.
  - *Resolution:* Use `todo`, `in_progress`, `completed`, `cancelled` for status, and `low`, `medium`, `high`, `urgent` for priority.

---

## 6. Comment Error Scenarios

### HTTP 400 Bad Request
- **Cause 1 (Malformed Task or Comment ID):** `task_id` or `comment_id` is not a valid 24-character hexadecimal ObjectId.
  - *Resolution:* Supply valid 24-hex-character MongoDB ObjectIds.

### HTTP 403 Forbidden
- **Cause 1 (User Cannot View Task):** User attempted to comment on or list comments for a task they cannot view (e.g. employee not assigned and not on project team; manager not managing team).
  - *Resolution:* Only users with view access to a task can participate in its discussion.
- **Cause 2 (Employee Editing/Deleting Another User's Comment):** An employee attempted `PUT /comments/{id}` or `DELETE /comments/{id}` for a comment created by someone else.
  - *Resolution:* Employees can only edit and delete their own comments.
- **Cause 3 (Manager Modifying Comment on Other Team's Task):** A manager attempted to edit or delete a comment on a task belonging to a team they do not manage.
  - *Resolution:* Managers can only moderate comments on tasks belonging to teams they lead.

### HTTP 404 Not Found
- **Cause 1 (Task Not Found):** Specified `task_id` does not exist in `tasks`.
  - *Resolution:* Verify task existence before posting or querying comments.
- **Cause 2 (Comment Not Found):** Specified `comment_id` does not exist in `comments`.
  - *Resolution:* Verify comment ID before editing or deleting.

### HTTP 422 Unprocessable Entity
- **Cause 1 (Empty or Oversized Comment):** `content` is empty/whitespace or exceeds 2000 characters.
  - *Resolution:* Provide non-empty content between 1 and 2000 characters.

---

## 7. Activity Audit Trail Error Scenarios

### HTTP 400 Bad Request
- **Cause 1 (Malformed Filter ID):** `task_id`, `project_id`, or `team_id` query parameter is not a valid 24-character hexadecimal ObjectId.
  - *Resolution:* Provide valid 24-hex-character MongoDB ObjectIds in query parameters.

### HTTP 422 Unprocessable Entity
- **Cause 1 (Invalid Action Filter):** `action` query parameter is not one of the controlled action enums.
  - *Resolution:* Supply a valid action string (e.g. `task_created`, `task_status_changed`, `comment_created`).
- **Cause 2 (Invalid Entity Type Filter):** `entity_type` query parameter is not one of `task`, `comment`, `project`, or `team`.
  - *Resolution:* Supply a valid entity type string.

---

## 8. Redis Caching & Rate Limiting Error Scenarios

### HTTP 429 Too Many Requests
- **Cause 1 (Authentication Rate Limit Exceeded):** More than 5 requests submitted to `/auth/login`, `/auth/register`, or `/auth/password` from the same client IP within a 60-second window.
  - *Resolution:* Wait for the window to expire as indicated by the `Retry-After` response header before resubmitting credentials.

### Redis Connection Offline / Unreachable
- **Behavior:** The application logs a `WARNING` and automatically degrades to direct MongoDB execution without throwing `500 Internal Server Error` or preventing FastAPI startup.
  - *Resolution:* Start Redis via `docker compose up -d redis` or start a local Redis server on `localhost:6379`. No code changes required.

### Redis Mutation Invalidation Failure
- **Behavior:** If Redis encounters network errors or timeouts during cache deletion after a write, the error is caught and logged as a warning; the API operation succeeds normally without breaking client requests.
  - *Resolution:* Check Redis connectivity and system logs. Caches will automatically expire within 300 seconds (TTL).

---

## 9. Flutter Client & API Integration Error Scenarios

### SocketException / Connection Refused
- **Cause:** Flutter client is unable to reach the FastAPI backend server (e.g. backend not running, or Android emulator trying to connect to `127.0.0.1` instead of `10.0.2.2`).
  - *Resolution:* Ensure backend is running via `uvicorn app.main:app --reload`. On Android emulator, launch with `--dart-define=API_BASE_URL=http://10.0.2.2:8000`.

### UnauthorizedException / Auto-Logout (HTTP 401)
- **Cause:** JWT token expired (30m lifetime) or user account deactivated.
  - *Resolution:* The `ApiClient` triggers `onUnauthorized`, clearing stored tokens and returning the user to the Login screen with an expiration alert banner.

### ValidationException (HTTP 422) in Form Submissions
- **Cause:** Client submitted invalid data (e.g., end date earlier than start date, password shorter than 8 characters, or employee attempting to modify `assigned_to`).
  - *Resolution:* The UI extracts the backend error message and displays it in an inline error banner or SnackBar without crashing.

### RateLimitException (HTTP 429) on Login/Register
- **Cause:** More than 5 auth requests in 60 seconds from the client.
- **Resolution:** The UI displays a warning message indicating rate limit reached, prompting the user to wait before retrying.

---

## 10. Activity Stream & Task Mutation Logging

### Duplicate or Unexpected Generic `task_updated` Action on Single-Field Edits
- **Cause:** Form submissions that send the entire task schema (e.g. including `due_date`, `description`, etc.) caused false-positive dirty field detections due to type differences between Python `date`/`datetime` and MongoDB stored formats (`datetime.datetime` vs `datetime.date`), triggering `task_updated` instead of the specific field action (e.g. `task_priority_changed`).
- **Resolution:** Task update comparison normalizes types (e.g. ISO date substring formatting, whitespace stripping, and None/empty string equivalence) across all mutable fields (`due_date`, `title`, `description`, `project_id`, `assigned_to`, `status`, `priority`) before evaluating changed fields count. Single-field modifications log only the specific action (`task_priority_changed`, `task_status_changed`, `task_assigned_changed`, `task_project_changed`), multi-field modifications log `task_updated`, and zero-change submissions log no new activity.