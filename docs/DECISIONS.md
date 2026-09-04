# Technical Decisions

## Decision 001: Use MongoDB
- **Context:** Need flexible, document-based storage for organizations, employees, teams, and dynamic task attributes.
- **Decision:** Use MongoDB 8.0 with the Motor async driver.

---

## Decision 002: Use FastAPI
- **Context:** Need high-performance, async web API with automatic OpenAPI validation and interactive Swagger documentation.
- **Decision:** Use FastAPI with Pydantic V2.

---

## Decision 003: Public Registration Hardening & Initial Admin Bootstrap
- **Context:** Public registration previously allowed arbitrary role assignment (`role: admin`), posing a critical privilege escalation risk.
- **Decision:** Removed `role` selection from `UserCreateSchema`. Public registration always assigns `role: employee`. To resolve the bootstrap problem on a fresh deployment without hardcoded credentials, the system automatically assigns `role: admin` to the first user registered when the `users` collection is empty.

---

## Decision 004: Active User Status Validation in Auth Dependency
- **Context:** Deactivated employees or deleted accounts could still authenticate if they held an unexpired JWT token.
- **Decision:** Updated `get_current_user` to query the `users` collection and verify account existence and `status == "active"`. Deactivating an employee updates both the employee record and the corresponding user login account to `status: "inactive"`.

---

## Decision 005: Elimination of Hardcoded Passwords
- **Context:** Employee creation defaulted to a static password `"Temp@123"`.
- **Decision:** Removed static passwords. The admin can provide an explicit `initial_password` or the system will dynamically generate a secure 12-character random string using Python's `secrets` module and return it in the creation response for distribution.

---

## Decision 006: Reusable MongoDB ObjectId Validation
- **Context:** Direct conversion of request parameters using `ObjectId(id)` threw unhandled `bson.errors.InvalidId` exceptions resulting in 500 Internal Server Error.
- **Decision:** Created a centralized `validate_object_id` helper in `app/utils/object_id.py` that validates format and returns HTTP 400 Bad Request on invalid inputs.

---

## Decision 007: Database Verification & Explicit 401/403 Distinction in Auth
- **Context:** Authentication dependencies must differentiate between unauthenticated/missing credentials and unauthorized/inactive access.
- **Decision:** `get_current_user` verifies the token against the database on each request. Missing/expired tokens or deleted accounts return `401 Unauthorized`. Inactive accounts return `403 Forbidden`.

---

## Decision 008: Password Change Current Password Verification & Atomic Updates
- **Context:** Password modifications must ensure the requester knows the existing password and updates must not suffer race conditions.
- **Decision:** `PUT /auth/password` requires verifying `current_password` via bcrypt before generating the new hash and executing an atomic `$set` update in MongoDB.

---

## Decision 009: JWT Validity Post-Password Change in MVP
- **Context:** Invalidation of existing JWTs after a password change requires a distributed token blacklist or issued-at timestamp tracking in the database.
- **Decision:** For the MVP, issued JWTs remain valid until their natural expiration (30 minutes). Token blacklisting with Redis will be evaluated in Phase 6.

---

## Decision 010: Deferral of Refresh Token Infrastructure
- **Context:** Access token lifetime is configured to 30 minutes, providing a practical balance between security and user experience for the MVP.
- **Decision:** Refresh tokens are deferred to maintain a simple, robust authentication architecture without premature complexity.

---

## Decision 011: Teams Collection as Single Source of Truth for Team Membership
- **Context:** Team membership can be modeled either symmetrically (storing `team_id` on employee documents and `member_ids` on team documents) or unidirectionally.
- **Decision:** Use the `teams.member_ids` array as the single source of truth. The `employees` collection does not store a redundant `team_id`, preventing dual-write synchronization issues and race conditions.

---

## Decision 012: Strict Separation of Manager and Member Relationships
- **Context:** A team has a `manager_id` and a list of `member_ids`. If a manager is also included in `member_ids`, ownership checks and member roster mutations become ambiguous.
- **Decision:** `manager_id` and `member_ids` are kept distinct. Attempting to add the team manager to `member_ids` returns `400 Bad Request`.

---

## Decision 013: Dynamic Manager Ownership Resolution Without Redundant JWT Claims
- **Context:** Team authorization requires verifying if the requester is the manager of a team. Storing `employee_id` in JWT claims would create stale tokens when employee IDs change or when managers are re-assigned.
- **Decision:** Retain only `user_id` and `role` in the JWT token. Resolve `user_id -> employees._id` dynamically from MongoDB within `check_team_management_permission` to guarantee up-to-date ownership validation.

---

## Decision 014: Atomic Member Roster Management and Duplicate Conflict Handling
- **Context:** Adding an already assigned employee or an inactive employee must be handled cleanly.
- **Decision:** `POST /teams/{team_id}/members` validates that the employee exists and has `status == "active"`. If the employee is already present in `member_ids`, return `409 Conflict`. Use MongoDB `$addToSet` for atomic addition and `$pull` for atomic removal.

---

## Decision 015: Direct Hard Deletion of Team Documents in MVP
- **Context:** When deleting a team in the current stage, soft-deletion vs hard-deletion was considered.
- **Decision:** In the current phase before task associations are introduced (Phase 4), teams are hard-deleted (`delete_one`). Future phases will introduce cascading checks for attached projects and tasks.

---

## Decision 016: Project to Team Unidirectional Association
- **Context:** Linking projects to organizational structure could be done via multi-way relations or embedded arrays on teams/employees.
- **Decision:** Use `team_id` on the `projects` collection as the single normalized link. Avoid redundant `team.project_ids`, `employee.team_id`, or `project.member_ids` to eliminate synchronization overhead.

---

## Decision 017: Immutability of Project Creation Audit Fields
- **Context:** `created_by` and `created_at` track the creator and origin timestamp of a project.
- **Decision:** `created_by` is set exclusively from the authenticated user's `user_id` (JWT `sub`) and `created_at` from the server UTC clock. Both fields are immutable, enforced by `extra="forbid"` on `ProjectUpdateSchema`.

---

## Decision 018: Dual-Team Authorization on Project Team Transfer
- **Context:** When updating a project's `team_id`, a manager might move a project into a team they do not manage or transfer a project away from another manager's team.
- **Decision:** `PUT /projects/{project_id}` requires that managers possess management authority over BOTH the current project team and the new target team.

---

## Decision 019: Scoped Project Visibility for Managers and Employees
- **Context:** Project listings and detail endpoints must reflect organizational visibility rules.
- **Decision:** Managers see projects belonging to teams they manage (`team.manager_id == manager.employee_id`). Employees see projects belonging to teams where they are enrolled in `team.member_ids`. Admins retain full global visibility. Empty listings return `[]` with `200 OK`.

---

## Decision 020: Server-Side Date Range Consistency Validation
- **Context:** Projects have start and end boundaries (`start_date` and `end_date`).
- **Decision:** Validate `end_date >= start_date` both at schema ingestion via Pydantic model validators and at service level when partial updates merge existing project dates. Return `422 Unprocessable Entity` on violation.

---

## Decision 021: Task to Project and Assignee Normalized Relationships
- **Context:** Tasks link to projects and assigned employees.
- **Decision:** Use `project_id` and `assigned_to` on the `tasks` collection as normalized references. Avoid redundant `project.task_ids`, `employee.task_ids`, or `team.task_ids`.

---

## Decision 022: Task Assignment Eligibility Matrix (Members and Managers)
- **Context:** Teams maintain `manager_id` separately from `member_ids`. Both team members and the team manager should be assignable to tasks within the team's projects.
- **Decision:** An employee is eligible for assignment if `assigned_to in Team.member_ids` OR `assigned_to == Team.manager_id`. Inactive or non-affiliated employees are rejected with `403 Forbidden`.

---

## Decision 023: Dual-Project Manager Authorization and Ineligible Assignee Rejection
- **Context:** Moving a task across projects via `PUT /tasks/{task_id}` could violate manager governance or leave an employee assigned to a project whose team they cannot work on.
- **Decision:** When changing `project_id`, verify that the manager manages both current and target project teams (403 if not), and verify that the currently assigned employee is eligible on the target project's team (rejecting with `422 Unprocessable Entity` if ineligible).

---

## Decision 024: Explicit Rejection of Restricted Employee Update Fields (422)
- **Context:** Employees are allowed to update their own assigned tasks (`title`, `description`, `priority`, `status`, `due_date`) but must not reassign projects or assignees.
- **Decision:** When an employee submits `project_id` or `assigned_to` in `PUT /tasks/{task_id}`, the request is explicitly rejected with `422 Unprocessable Entity` rather than silently ignoring the fields.

---

## Decision 025: Deferred Due Date Cross-Project Validation
- **Context:** Task `due_date` could theoretically be constrained within `project.start_date` and `project.end_date`.
- **Decision:** For Phase 4 MVP, `due_date` is validated independently as a valid ISO date without cross-collection date range enforcement, deferring complex scheduling rules to future project phases.

---

## Decision 026: Comment Author User ID Binding
- **Context:** Comments need author identification that survives employee profile changes or team transfers.
- **Decision:** Store `user_id` from the verified JWT `sub` claim in the `comments` document instead of `employee_id`. The client cannot supply `user_id` in request payloads.

---

## Decision 027: Cascade Deletion for Task Comments
- **Context:** Deleting a task could leave orphaned comments in the database.
- **Decision:** In `DELETE /tasks/{task_id}`, delete all comments where `comment.task_id == task._id` immediately after the task is deleted.

---

## Decision 028: Permanent Historical Audit Trail Preservation
- **Context:** When tasks or comments are deleted, audit records referencing them could either be deleted, cascade-deleted, or preserved.
- **Decision:** Historical records in the `activities` collection are preserved permanently to maintain complete auditability and compliance.

---

## Decision 029: Explicit Activity Logging Helper vs Event System
- **Context:** Activity records need to be generated reliably on state mutations.
- **Decision:** Use an explicit service helper (`log_activity`) invoked at the end of successful service operations after database write operations succeed. Avoid decorators, event buses, or background hooks to keep the MVP architecture simple, predictable, and maintainable.

---

## Decision 030: Activity Metadata Whitelist & Content Preview Sanitization
- **Context:** Activity audit logs could accidentally leak sensitive tokens, passwords, or PII.
- **Decision:** Restrict activity `metadata` to a flat dictionary of max 5 key-value pairs using a strict key whitelist (`old_value`, `new_value`, `title`, `name`, `assigned_to`, `content_preview`). Truncate comment content previews to 100 characters max and strictly prohibit storing credentials, full bodies, or stack traces.

---

## Decision 031: Centralized Fail-Open Redis Manager Architecture
- **Context:** Redis serves as an optimization and supporting service. Network partitions, startup timing, or Redis downtime should not bring down the application.
- **Decision:** Implement a centralized singleton `RedisManager` in `app/database/redis.py` that connects with a 1.0-second socket timeout and catches connection failures at startup and runtime. If Redis is unavailable, the application logs a warning and transparently fails open to MongoDB.

---

## Decision 032: Selective Detail Endpoint Caching with Exact Invalidation
- **Context:** List endpoints have complex RBAC filters, search parameters, and pagination that make cache invalidation error-prone.
- **Decision:** Cache only detail endpoints (`GET /teams/{team_id}`, `GET /projects/{project_id}`, `GET /tasks/{task_id}`) with a 300-second TTL. Invalidate exact keys (`team:{id}`, `project:{id}`, `task:{id}`) immediately after successful MongoDB mutations. Do not cache list endpoints or use broad wildcard pattern deletion.

---

## Decision 033: Authorization Prior to Cache Retrieval
- **Context:** Storing user credentials or roles in cache keys creates security vulnerabilities and cache bloat.
- **Decision:** Cache keys contain only entity identifiers (`{entity}:{id}`). All requests must undergo standard JWT authentication and RBAC validation before any cached data is returned to the client, guaranteeing that unauthorized users receive `403 Forbidden` without accessing cached entity payloads.

---

## Decision 034: JSON Serialization with ISO Timestamping for Cache Values
- **Context:** Cached data must be easily inspectable, portable, and secure against deserialization exploits.
- **Decision:** Use standard `json.dumps()` and `json.loads()` with ISO 8601 datetime strings. Binary serializers such as `pickle` or `msgpack` are strictly prohibited. Every cached entity includes a `_cached_at` timestamp.

---

## Decision 035: Fixed-Window Redis Rate Limiting on Authentication Endpoints
- **Context:** Authentication endpoints require protection against brute-force and credential stuffing attacks without introducing heavy third-party dependencies.
- **Decision:** Implement a lightweight, dependency-injected fixed-window rate limiter (5 requests / 60 seconds per client IP) using Redis atomic `INCR` and `EXPIRE`. When exceeded, return `HTTP 429 Too Many Requests` with a `Retry-After` header. If Redis is offline, fail open to avoid locking out legitimate users.