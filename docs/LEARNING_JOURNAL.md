# Learning Journal

## 04-08-2026

### Completed

- Project initialized
- FastAPI installed
- Virtual environment created
- Git initialized
- Swagger working
- Health API created

### Issue

VS Code couldn't resolve FastAPI imports.

### Cause

Virtual environment was created using Python 3.11.

### Solution

Deleted the old virtual environment and recreated it using:

```bash
py -3.13 -m venv venv
```

Selected:

```
venv/Scripts/python.exe
```

### Lesson

Always create a virtual environment using:

```bash
py -3.13 -m venv venv
```

---

## 10-09-2026

### Completed

- Implemented account soft deactivation and reactivation (`PATCH /employees/{id}/deactivate`, `PATCH /employees/{id}/reactivate`) with multi-level safety guards (self-protection, last active admin, active team manager guard).
- Added multi-criteria task query filtering and search (`GET /tasks/`) with regex sanitization (`re.escape`) and compound MongoDB indexes.
- Enriched dashboard with client-computed task metrics (My Tasks, Due Today, Overdue, Total Tasks), responsive layout, and accessibility semantics.
- Enhanced Flutter UI in User Management (status filtering, confirmation modal) and Task Management (search bar with debounce, filter chips).

### Issue

1. Unsanitized user search input could lead to regex injection or invalid regex execution against MongoDB.
2. Deactivating a manager who currently leads active teams could leave teams orphaned without managerial oversight.
3. Complex queries combining status and due date / assignee require proper indexing to prevent unindexed collection scans.

### Solution

1. Applied `re.escape(search.strip())` to escape special regex characters prior to querying MongoDB with `$regex: escaped_search, $options: "i"`.
2. Added proactive validation in `employee_service.py` to check for active teams where `manager_id == employee_id`, returning `409 Conflict` prompting the administrator to reassign team leadership before deactivation.
3. Added compound indexes `(status, due_date)`, `(assigned_to, status)`, and `(project_id, status)` to the `tasks` collection.

### Lesson

1. Never construct raw regular expressions from untrusted user input; always escape input when performing substring searches.
2. Business integrity constraints (e.g. team leadership, last admin) must always be validated and enforced authoritatively on the backend before state transitions occur.

---

## 11-09-2026

### Completed

- Implemented optional registration profile fields (`phone`, `department`) with strict rejection of client-provided role/status overrides (`extra = "forbid"`).
- Implemented Admin employee profile management (`PATCH /employees/{employee_id}`) with strict field validation, name synchronization across `employees` and `users` collections, and rollback on failure.
- Enhanced Flutter User Management screen with a dedicated "View Profile" dialog enabling profile inspection (read-only email, role, joining date, status) and inline updates for name, phone, and department.

### Issue

1. Newly registered users who omitted phone/department during registration could not be updated by administrators later due to missing profile update endpoints.
2. Updating user name in the `employees` collection without synchronizing the linked `users` authentication record causes name discrepancies between login sessions, tokens, and employee listings.

### Solution

1. Added `PATCH /employees/{employee_id}` endpoint accepting `EmployeeProfileUpdateSchema` (with `extra="forbid"`) to safely allow editing `name`, `phone`, and `department` while protecting system-controlled fields (`role`, `status`, `email`, `user_id`, `joining_date`).
2. Implemented two-phase synchronization in `employee_service.py` to update `name` in both `employees` and `users` collections, rolling back the employee change if user update fails.
3. Created `_EmployeeProfileDialog` in Flutter with structured form validation, clear separation between editable and read-only attributes, and reliable error reporting.

### Lesson

1. When domain entities span multiple database collections (e.g. `employees` and `users`), write operations must maintain explicit data synchronization and rollback mechanisms to prevent state drift.
2. Form dialogs in Flutter are most reliably implemented as standalone `StatefulWidget` instances to manage controller lifecycles and validation without race conditions during dialog transitions.