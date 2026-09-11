# Changelog

## v1.1.0 - Phase 9: Practical Enhancements (Deactivation, Task Filtering & Search, Dashboard)

### Added
- Backend account deactivation (`PATCH /employees/{employee_id}/deactivate`) and reactivation (`PATCH /employees/{employee_id}/reactivate`) restricted strictly to administrators.
- Comprehensive deactivation guards: self-deactivation prevention (`403 Forbidden`), last active administrator protection (`409 Conflict`), and active team manager guard (`409 Conflict` prompting team reassignment).
- Synchronized status transitions across `employees` and `users` collections (`active` / `inactive`) with two-phase rollback on failure.
- Audit trail logging for `user_deactivated` and `user_reactivated` actions with actor metadata.
- Backend task filtering on `GET /tasks/` by `status`, `priority`, `assigned_to`, `project_id`, `due_date`, and `overdue` (boolean).
- Sanitized task text search (`search` parameter) filtering title and description via escaped regular expressions (`re.escape`).
- Compound MongoDB indexes on `tasks` collection: `(status, due_date)`, `(assigned_to, status)`, and `(project_id, status)`.
- Authoritative backend RBAC preserved across all task query filters for Admin, Manager, and Employee roles.
- Flutter `TeamProvider` methods `deactivateEmployee` and `reactivateEmployee` with status state management.
- Flutter `UserManagementScreen` status filter chips (All / Active / Inactive), user status badges, action menus with confirmation dialogs, and disabled self-deactivation.
- Flutter `TaskProvider` support for task search, due date, and overdue filtering.
- Flutter `TaskListScreen` real-time search bar with debouncing, multi-filter dropdowns/chips (Status, Priority, Project, Overdue), and clear filters action.
- Flutter `DashboardScreen` client-side computed metrics (My Tasks, Due Today, Overdue, Total Tasks), responsive grid layout (360x640 compatible), and screen reader accessibility semantics.
- Flutter `TaskFormScreen` and backend task creation/update schemas enhanced to support optional task due dates.
- Registration Profile Enhancement: optional `phone` and `department` fields exposed in `UserCreateSchema`, `register_user` endpoint, `AuthProvider.register()`, and `RegisterScreen` with strict rejection (`422`) of client-supplied `role` or `status` overrides.
- Admin Employee Profile Management: Backend endpoint `PATCH /employees/{employee_id}` allowing administrators to edit `name`, `phone`, and `department` with automatic two-phase user synchronization on name changes and strict `extra="forbid"` rejection of system-controlled/unknown fields.
- Flutter User Management Profile Dialog: Added "View Profile" dialog on `UserManagementScreen` with editable Full Name, Phone Number, Department and read-only Email, Role, Joining Date, and Status badges.
- Backend unit and integration tests covering employee deactivation/reactivation lifecycle, task query/search filters, registration profile fields, and admin profile updates (72 backend tests passing).
- Flutter widget and unit tests covering deactivation dialogs, task search/filter interactions, due date handling, registration profile submissions, and profile editing (55 tests passing).

## v1.0.0 - Phase 8: Dockerization & Deployment Readiness

### Added
- Production-capable `taskflow-backend/Dockerfile` based on `python:3.13-slim` with layer-cached dependency installation and non-root execution (`USER taskflow`, UID 1000).
- Build context exclusion file `taskflow-backend/.dockerignore` filtering local virtual environments, test artifacts, caches, and secrets.
- Docker Compose service orchestration in `compose.yaml` linking `backend`, `mongodb`, and `redis` under a shared bridge network.
- Container healthchecks and dependency startup ordering (`condition: service_healthy`) for MongoDB (`mongosh ping`), Redis (`redis-cli ping`), and FastAPI backend (`GET /health`).
- Runtime environment variable injection for `MONGODB_URL`, `REDIS_URL`, `JWT_SECRET`, and application settings.
- Updated `taskflow-backend/.env.example` documenting both local host and containerized networking variables.
- Dual-mode setup instructions in `docs/SETUP.md` and diagnostic commands in `docs/COMMANDS.md`.

## v0.9.0 - Phase 7.5: Admin User & Role Management

### Added
- Backend endpoint `PATCH /employees/{employee_id}/role` strictly restricted to `admin` callers (`require_roles("admin")`), accepting target roles `employee`, `manager`, or `admin`.
- Two-phase role synchronization between `employees.role` and `users.role` with automatic rollback on secondary update failure.
- Self-demotion prevention returning `403 Forbidden` (`Administrators cannot change their own role.`).
- Last-admin protection returning `409 Conflict` (`Cannot remove the last administrator.`).
- Team-manager safety check returning `409 Conflict` (`Cannot demote {name}. They are currently managing {count} team(s). Reassign those teams first.`) if demoting an active team manager to non-manager.
- Activity audit logging capturing `user_role_changed` with metadata (`old_value`, `new_value`, `name`).
- Frontend `ApiClient.patch` method.
- Flutter `TeamProvider.updateEmployeeRole(employeeId, newRole)` method.
- Admin-only `UserManagementScreen` with user listing, current role display, disabled self-modification, role selection dialog, confirmation modal, and accessible semantics.
- Admin drawer in `MainNavigationScreen` exposing "User Management" exclusively to administrators.
### Fixed
- Fixed `ResponseValidationError` on `GET /employees/` by normalizing `joining_date` in `auth.py` and `employee_service.py` to zero-time `datetime`/`date` instances and defining both `/employees` and `/employees/` routes.
- Enhanced Activity formatting across Dashboard and Activity Stream to prominently show actor names alongside resolved task titles (e.g. `"Neha added a comment on task \"Implement User Authentication\""`, `"Amit Sharma changed task \"Implement User Authentication\" priority from Low to High"`, `"Raj changed Amit Sharma's role from Employee to Manager"`).
- Updated `TeamProvider.fetchEmployees()` to manage loading states, track errors, and properly notify listeners.

### Added
- Backend response enrichment for Activity (`actor_name`), Comment (`author_name`), and Task (`assignee_name`) schemas with batch `$in` lookups to prevent N+1 queries.
- Frontend model updates across `Activity`, `Comment`, and `Task` parsing server-enriched names.
- Accessible UI rendering in `ActivityListScreen` displaying actor name and accessible Semantics (`"$actorName performed: <action>"`).
- Accessible UI rendering in `CommentsSection` showing `"You"` for current user and `authorName` with `"Unknown User"` fallback (never generic `"User"`).
- Accessible UI rendering in `TaskDetailScreen` displaying `assigneeName` with `"Unknown User"` fallback on missing profiles and `"Unassigned"` only on empty assignment.
- Automated tests across backend (`test_comments_and_activities.py`) and Flutter (`models_test.dart`, `widget_test.dart`).

## v0.8.0 - Phase 7: Flutter Frontend Application & Client Architecture

### Added
- Complete Flutter client application initialized in `taskflow-app/` with clean 6-layer architecture (`config/`, `core/`, `models/`, `providers/`, `screens/`, `widgets/`).
- Centralized `ApiClient` with 10-second request timeout, Bearer token injection, query parameter mapping, auto-logout on HTTP 401, and typed exception mapping (`400`, `401`, `403`, `404`, `409`, `422`, `429`, `500+`).
- Secure JWT credential storage (`SecureStorageService`) wrapping `flutter_secure_storage`.
- Type-safe Dart models mapped to backend Pydantic schemas: `User`, `Employee`, `Team`, `Project`, `Task`, `Comment`, and `Activity`.
- Reactive state management using `Provider` and `ChangeNotifier` across `AuthProvider`, `TeamProvider`, `ProjectProvider`, `TaskProvider`, and `ActivityProvider`.
- Accessible design system with Material 3 theming (light/dark modes), non-color-only status badges (`StatusBadge`), priority badges (`PriorityBadge`), and 48x48 dp minimum touch targets.
- Role-scoped UI screens for Authentication (`LoginScreen`, `RegisterScreen`), Dashboard (`DashboardScreen`), Teams (`TeamListScreen`, `TeamDetailScreen`, `TeamFormScreen`), Projects (`ProjectListScreen`, `ProjectDetailScreen`, `ProjectFormScreen`), Tasks (`TaskListScreen`, `TaskDetailScreen`, `TaskFormScreen`), Comments (`CommentsSection`), Activities (`ActivityListScreen`), and Profile (`ProfileScreen`, `ChangePasswordDialog`).
- Frontend automated test suite with 20 passing unit and widget test cases.

## v0.7.0 - Phase 6: Redis Integration (Caching, Invalidation & Auth Rate Limiting)

### Added
- Centralized `RedisManager` in `app/database/redis.py` with connection pooling, socket timeouts, health checks (`ping`), and fail-open startup/runtime exception handling.
- JSON detail response caching for `GET /teams/{team_id}`, `GET /projects/{project_id}`, and `GET /tasks/{task_id}` with a 300-second TTL and `_cached_at` ISO 8601 timestamp.
- Strict authorization-before-cache validation ensuring cached data is never returned to unauthorized users.
- Exact cache invalidation on team, project, and task update, delete, and member change endpoints.
- Fixed-window rate limiter dependency (5 req / 60s per client IP) on `POST /auth/login`, `POST /auth/register`, and `PUT /auth/password`, returning `429 Too Many Requests` with a `Retry-After` header.
- Fail-open resilience on all cache and rate limiting operations: API calls transparently fall back to MongoDB if Redis is offline.
- Automated test suite expanded to 50 passing test cases with in-memory Redis mocking.

## v0.6.0 - Phase 5: Comments + Activity / Audit Trail

### Added
- Comment creation endpoint (`POST /tasks/{task_id}/comments`) with scoped task view authorization and user ID extraction from JWT `sub`.
- Comment listing endpoint (`GET /tasks/{task_id}/comments`) with descending timestamp sorting and pagination (`skip`/`limit`).
- Comment edit endpoint (`PUT /comments/{comment_id}`) restricting edits to author (employees) or team managers and admins.
- Comment deletion endpoint (`DELETE /comments/{comment_id}`) with role-based moderation.
- Cascade deletion of task comments upon task deletion (`DELETE /tasks/{task_id}`).
- Activity / Audit Trail model and service layer logging helper (`log_activity`) capturing task lifecycle, field modifications (`task_assigned_changed`, `task_status_changed`, `task_priority_changed`, `task_project_changed`), and comment actions.
- Activity listing endpoint (`GET /activities/`) with query filters (`task_id`, `project_id`, `team_id`, `actor_user_id`, `action`, `entity_type`), role-based scoping (Admin all, Manager managed teams, Employee visible tasks), and pagination.
- MongoDB indexes on `comments` (`task_id`, `user_id`, `created_at`) and `activities` (`actor_user_id`, compound `entity_type + entity_id`, `task_id`, `project_id`, `team_id`, `created_at`).
- Automated test suite expanded to 33 passing test suites covering 120+ assertions.

## v0.5.0 - Phase 4: Task Management

### Added
- Task creation endpoint (`POST /tasks/`) with manager ownership verification and assignee eligibility validation (`member_ids` OR `manager_id`).
- Task listing endpoint (`GET /tasks/`) with role-based visibility (all for Admins, managed projects for Managers, assigned & team-member tasks for Employees).
- Task detail endpoint (`GET /tasks/{task_id}`) with team membership and manager access verification.
- Task partial update endpoint (`PUT /tasks/{task_id}`) supporting employee updates on their own tasks (with strict 422 rejection if submitting `project_id`/`assigned_to`) and manager dual-project transfer verification.
- Task hard deletion endpoint (`DELETE /tasks/{task_id}`) returning `204 No Content`.
- Task prioritization (`low`, `medium`, `high`, `urgent`) and status workflow (`todo`, `in_progress`, `completed`, `cancelled`).
- MongoDB indexes for `tasks` collection on `project_id`, `assigned_to`, `status`, `priority`, `due_date`, and `created_by`.
- Automated test suite expanded to 29 passing test cases.

## v0.4.0 - Phase 3: Project Management

### Added
- Project creation endpoint (`POST /projects/`) with manager ownership verification and server-generated audit fields (`created_by`, `created_at`, `updated_at`).
- Project listing endpoint (`GET /projects/`) with role-based visibility (all for Admins, managed teams for Managers, member teams for Employees) and sorting by `created_at` descending.
- Project detail endpoint (`GET /projects/{project_id}`) with team membership and manager access controls.
- Project partial update endpoint (`PUT /projects/{project_id}`) with dual-team authorization verification on team transfer.
- Project hard deletion endpoint (`DELETE /projects/{project_id}`) returning `204 No Content`.
- Strict date validation (`end_date >= start_date`) and status lifecycle validation (`planned`, `active`, `completed`, `cancelled`).
- MongoDB indexes for `projects` collection on `team_id`, `created_by`, and `status`.
- Automated test suite expanded to 25 passing test cases.

## v0.3.0 - Phase 2: Team Management Completion & Member Assignment

### Added
- Team update endpoint (`PUT /teams/{team_id}`) supporting partial updates for `name`, `description`, and `manager_id`.
- Team hard delete endpoint (`DELETE /teams/{team_id}`) returning `204 No Content`.
- Member assignment endpoint (`POST /teams/{team_id}/members`) using atomic MongoDB `$addToSet` and returning `409 Conflict` on duplicates.
- Member removal endpoint (`DELETE /teams/{team_id}/members/{employee_id}`) using atomic MongoDB `$pull`.
- Ownership-based authorization verifying that managers can only mutate teams where `team.manager_id == manager.employee_id`.
- Employee visibility filtering ensuring employees can only view teams where their ID is present in `member_ids`.
- Automated test suite expanded to 21 passing test cases.

## v0.2.0 - Phase 0 & Phase 1: Security Stabilization & User Profile Management

### Added
- Public registration hardening: default `employee` role, first-user `admin` bootstrap.
- Authenticated user profile retrieval (`GET /auth/me`) directly from database.
- Authenticated password change (`PUT /auth/password`) verifying existing credentials and performing atomic bcrypt updates.
- Inactive user and deleted account rejection with distinct 403 Forbidden and 401 Unauthorized status codes.
- Employee profile management CRUD and temporary password generation.
- Reusable MongoDB ObjectId validation helper (`validate_object_id`).

## v0.1.0 - Initial Project Setup

### Added
- Project initialization with FastAPI, Motor, Pydantic, and Docker Compose.
- Health check and diagnostic API endpoints.
- Technical documentation structure.