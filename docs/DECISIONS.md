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
- **Decision:** Implement a singleton `RedisManager` in `app/database/redis.py` that connects with a 1.0-second socket timeout and catches connection failures at startup and runtime. If Redis is unavailable, the application logs a warning and transparently fails open to MongoDB.

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
- **Context:** Cached data must be easily inspectable, practical, and secure against deserialization exploits.
- **Decision:** Use standard `json.dumps()` and `json.loads()` with ISO 8601 datetime strings. Binary serializers such as `pickle` or `msgpack` are strictly prohibited. Every cached entity includes a `_cached_at` timestamp.

---

## Decision 035: Fixed-Window Redis Rate Limiting on Authentication Endpoints
- **Context:** Authentication endpoints require protection against brute-force and credential stuffing attacks without introducing heavy third-party dependencies.
- **Decision:** Implement a lightweight, dependency-injected fixed-window rate limiter (5 requests / 60 seconds per client IP) using Redis atomic `INCR` and `EXPIRE`. When exceeded, return `HTTP 429 Too Many Requests` with a `Retry-After` header. If Redis is offline, fail open to avoid locking out legitimate users.

---

## Decision 036: Flutter Client Architecture and Package Structure
- **Context:** The frontend needs a maintainable, clean architecture without premature enterprise bloat.
- **Decision:** Organize `taskflow-app/` into 6 core layers: `config/`, `core/`, `models/`, `providers/`, `screens/`, and `widgets/`. Avoid unnecessary domain/use-case layers for the MVP.

---

## Decision 037: Provider + ChangeNotifier for State Management
- **Context:** Needed a reactive state management solution that integrates seamlessly with Flutter without excessive boilerplate (e.g., BloC) or external code generation dependencies.
- **Decision:** Use `package:provider` with `ChangeNotifier` across distinct domain providers (`AuthProvider`, `TeamProvider`, `ProjectProvider`, `TaskProvider`, `ActivityProvider`).

---

## Decision 038: Centralized ApiClient with Typed HTTP Exceptions and 401 Interceptor
- **Context:** Client API operations need standard timeouts, Bearer token injection, query parameter formatting, error decoding, and automatic logout upon token expiry.
- **Decision:** Implement a centralized `ApiClient` in `lib/core/api_client.dart` with a 10-second timeout, typed exception mapping (`400`, `401`, `403`, `404`, `409`, `422`, `429`, `500+`), and an `onUnauthorized` callback to automatically reset application state and navigate to the login screen.

---

## Decision 039: Secure JWT Storage via flutter_secure_storage
- **Context:** Storing JWT tokens in unencrypted local storage (like `shared_preferences`) exposes authentication credentials to extraction.
- **Decision:** Use `flutter_secure_storage` to persist `auth_token` in platform-native encrypted keychains/keystores with in-memory fallback.

---

## Decision 040: Non-Color-Only Accessibility Badges
- **Context:** Accessibility guidelines require that status, priority, and critical information must not rely solely on color cues.
- **Decision:** Implement `StatusBadge` and `PriorityBadge` combining unique iconography, text labels, and color coding. Form controls adhere to WCAG minimum 48x48 dp touch targets.

---

## Decision 041: Strict Client-Side Validation Mirroring Backend Schemas
- **Context:** Preventing unnecessary roundtrips and providing instant user feedback while ensuring compliance with backend Pydantic constraints.
- **Decision:** Implement `Validators` utility class matching backend rules (e.g., email regex, 8+ char password, non-empty names, date sequence verification).

---

## Decision 042: Frontend Role-Scoped UI with Authoritative Backend RBAC
- **Context:** UI elements (create buttons, edit/delete actions, team assignment options) should only appear when relevant to the user's role, but the client must never be trusted as the security authority.
- **Decision:** Conditionally render management UI controls based on the logged-in user's role while relying on the backend API as the final authoritative security gate, catching and displaying backend `403 Forbidden` and `422 Unprocessable Entity` errors clearly.

---

## Decision 043: CORSMiddleware Configuration for Flutter Web Integration
- **Context:** Flutter Web development on localhost / 127.0.0.1 sends cross-origin `OPTIONS` preflight requests for authenticated mutation endpoints (`/auth/register`, `/auth/login`, etc.) requiring permissive local CORS handling without compromising production origin security.
- **Decision:** Configure `fastapi.middleware.cors.CORSMiddleware` in `app/main.py` using `cors_origins` list and `cors_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"`, enabling `allow_credentials=True`, methods `["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"]`, and explicit/wildcard request headers. This allows dynamic Flutter Web ephemeral debugging ports on localhost/127.0.0.1 while strictly rejecting untrusted origins.

---

## Decision 044: Admin User & Role Management with Two-Phase Synchronization and Safety Protections
- **Context:** Organizational role changes require atomic updates across both `employees` and `users` collections, prevention of lockout (self-demotion / last-admin removal), and prevention of orphaned teams when demoting managers.
- **Decision:** Implement `PATCH /employees/{employee_id}/role` restricted strictly to callers with the `admin` role. Target role may be `employee`, `manager`, or `admin`. Apply safety constraints:
  1. **Self-demotion prevention:** Reject caller modifying their own role with `403 Forbidden` (`Administrators cannot change their own role.`).
  2. **Last-admin protection:** Query `users` count where `role == "admin"`; if count is 1 and target is that admin, reject with `409 Conflict` (`Cannot remove the last administrator.`).
  3. **Team-manager safety:** Query `teams` where `manager_id` matches the employee's ID (`str(employee["_id"])` or `ObjectId`); if any teams are managed, reject demotion with `409 Conflict` (`Cannot demote {name}. They are currently managing {count} team(s). Reassign those teams first.`).
  4. **Two-phase synchronization with rollback:** Update `employees.role` first, then `users.role`. If updating `users` fails, compensate/roll back `employees.role`; if rollback fails, return `500 Internal Server Error`.
  5. **Activity audit trail:** Create exactly one `user_role_changed` activity log per successful role modification.

---

## Decision 045: Flutter Web Containerization, Nginx SPA Serving, and Cross-Platform HTTP Handling
- **Context:** To provide a single-command deployment experience, the Flutter Web client must be packaged into a lightweight, secure container and served with single-page application fallback routing. Additionally, client networking code must compile seamlessly across Web, Android, iOS, and desktop without unsupported `dart:io` imports.
- **Decision:**
  1. **Cross-Platform HTTP Client:** Refactor `ApiClient` to remove `import 'dart:io'` and catch `package:http/http.dart`'s `ClientException`, enabling universal compilation across all Flutter targets while maintaining uniform typed exception mapping.
  2. **Multi-Stage Docker Build:** Build the Flutter Web application in release mode using a Flutter SDK builder stage, and copy the compiled static assets into an unprivileged `nginx:alpine` runtime container.
  3. **Nginx SPA Routing & Asset Optimization:** Configure Nginx with `try_files $uri $uri/ /index.html;` for seamless client-side routing, gzip compression, and caching headers for static assets while disabling caching on `index.html` and bootstrap scripts.
  4. **Full Stack Orchestration:** Add the `frontend` service to `compose.yaml` on port 8080 (mapped to internal port 80), depending on `backend` with healthcheck synchronization.