# Changelog

## v0.8.1 - Person-Name Resolution & Display Enrichment

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