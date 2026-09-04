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
- **Cause 2 (Referenced Team Not Found):** Specified `team_id` in project creation or update does not exist in `teams`.
  - *Resolution:* Ensure the team exists before associating projects with it.

### HTTP 422 Unprocessable Entity
- **Cause 1 (Invalid Date Range):** `start_date` is later than `end_date`.
  - *Resolution:* Ensure `end_date` is greater than or equal to `start_date`.
- **Cause 2 (Invalid Project Status):** `status` is not one of `planned`, `active`, `completed`, or `cancelled`.
  - *Resolution:* Supply a valid status string.
- **Cause 3 (Empty / Whitespace Project Name):** `name` is empty or consists solely of whitespace characters.
  - *Resolution:* Provide a non-empty string between 1 and 120 characters.
- **Cause 4 (Extra / Immutable Fields in Payload):** Attempted to send unmodeled or immutable fields (e.g. `created_by`, `created_at`).
  - *Resolution:* Do not pass server-managed audit fields in request payloads.

---

## 5. Task Management Error Scenarios

### HTTP 400 Bad Request
- **Cause 1 (Malformed ObjectId in Path or Body):** `task_id`, `project_id`, or `assigned_to` is not a valid 24-character hexadecimal string.
  - *Resolution:* Provide valid 24-hex-character MongoDB ObjectIds.

### HTTP 403 Forbidden
- **Cause 1 (Manager Managing Unassigned Project's Tasks):** Manager attempted to create, update, or delete a task on a project belonging to a team they do not manage.
  - *Resolution:* Managers can only manage tasks within projects belonging to their own teams.
- **Cause 2 (Assigned Employee Not Eligible):** Attempted to assign a task to an employee who is neither in `team.member_ids` nor matches `team.manager_id`.
  - *Resolution:* Ensure assigned employees belong to the project team before assignment.
- **Cause 3 (Assigned Employee Inactive):** Attempted to assign a task to an employee with `status: "inactive"`.
  - *Resolution:* Reactivate the employee profile before assigning tasks.
- **Cause 4 (Employee Updating Another Assignee's Task):** An employee attempted `PUT /tasks/{id}` on a task assigned to someone else.
  - *Resolution:* Employees may only update their own assigned tasks.
- **Cause 5 (Employee Deleting/Creating Task):** An employee attempted `POST /tasks/` or `DELETE /tasks/{id}`.
  - *Resolution:* Task creation and deletion are restricted to Admins and Team Managers.

### HTTP 404 Not Found
- **Cause 1 (Task Not Found):** Specified `task_id` does not exist in `tasks`.
  - *Resolution:* Verify the task ID.
- **Cause 2 (Project, Team, or Employee Not Found):** Specified `project_id` or `assigned_to` does not exist in the database.
  - *Resolution:* Verify entity existence prior to referencing in tasks.

### HTTP 422 Unprocessable Entity
- **Cause 1 (Employee Modifying Project or Assignee):** An employee included `project_id` or `assigned_to` in a task update payload.
  - *Resolution:* Employees cannot reassign tasks or transfer projects. Strip these fields from the update payload.
- **Cause 2 (Project Transfer Assignee Ineligible):** A manager moved a task to a project whose team does not include the current assignee as a member or manager.
  - *Resolution:* Reassign the task to an eligible team member before or during the project transfer.
- **Cause 3 (Invalid Enums / Empty Title):** `priority` is not in `[low, medium, high, urgent]`, `status` is not in `[todo, in_progress, completed, cancelled]`, or `title` is empty/whitespace.
  - *Resolution:* Provide valid priority, status, and non-empty title strings.