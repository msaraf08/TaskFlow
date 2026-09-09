# System Architecture

TaskFlow is a cross-platform team and task management system built with a decoupled client-server architecture consisting of a Flutter client application, a FastAPI backend, MongoDB as the primary document database, and Redis for performance caching and rate limiting.

```
+-------------------------------------------------------------------------+
|                              TaskFlow Client                            |
|                          (Flutter 3.x / Dart 3.x)                       |
|                                                                         |
|  +-------------------+  +---------------------+  +-------------------+  |
|  | Presentation      |  | State Management    |  | Core & API Layer  |  |
|  | - Screens (7)     |  | - MultiProvider     |  | - ApiClient (HTTP)|  |
|  | - Widgets (Badges,|  | - AuthProvider      |  | - SecureStorage   |  |
|  |   Dialogs, Lists) |  | - TeamProvider      |  | - Validators      |  |
|  | - Material 3 Theme|  | - ProjectProvider   |  | - CustomExceptions|  |
|  |                   |  | - TaskProvider      |  | - AppConfig       |  |
|  |                   |  | - ActivityProvider  |  |                   |  |
|  +-------------------+  +---------------------+  +-------------------+  |
+-------------------------------------------------------------------------+
                                    |
                                    | HTTPS / JSON (Bearer JWT Auth)
                                    v
+-------------------------------------------------------------------------+
|                              Backend API                                |
|                        (FastAPI / Python 3.13)                          |
|                                                                         |
|  +-------------------------------------------------------------------+  |
|  | Routers: /auth, /employees, /teams, /projects, /tasks, /comments, |  |
|  |          /activities, /health                                     |  |
|  +-------------------------------------------------------------------+  |
|  | Dependencies: RBAC, Auth Verification, RateLimiter (5 req/60s)    |  |
|  +-------------------------------------------------------------------+  |
|  | Services: Business logic, Audit logging, Caching helpers          |  |
|  +-------------------------------------------------------------------+  |
+-------------------------------------------------------------------------+
                |                                          |
                | Motor Async Driver                       | redis-py (Socket Timeout 1s)
                v                                          v
+-------------------------------+          +-------------------------------+
|      MongoDB Database         |          |          Redis Cache          |
|    (Single Source of Truth)   |          |      (Fail-Open Layer)        |
|                               |          |                               |
| - users & employees           |          | - Detail caches (300s TTL)    |
| - teams & projects            |          |   (team:{id}, project:{id},   |
| - tasks & comments            |          |    task:{id})                 |
| - activities (permanent audit)|          | - Rate limiting fixed windows |
+-------------------------------+          +-------------------------------+
```

---

## 1. Frontend Architecture (`taskflow-app/`)

The client application follows a clean layered structure:

```
taskflow-app/lib/
|-- config/          # App constants, environment settings, Material 3 theming
|-- core/            # HTTP client, secure storage, custom exceptions, validators
|-- models/          # Type-safe Dart models mapped to backend Pydantic schemas
|-- providers/       # State management using Provider + ChangeNotifier
|-- screens/         # UI screens organized by domain feature
|   |-- auth/        # Login, Register
|   |-- dashboard/   # Metrics overview, status charts, quick actions
|   |-- teams/       # Team list, details, create/edit form
|   |-- projects/    # Project list, details, create/edit form
|   |-- tasks/       # Task list, details, create/edit form, filters
|   |-- activities/  # Paginated activity audit feed
|   |-- profile/     # User profile, password update dialog
|   `-- main_navigation_screen.dart # Tab navigation & app shell
|-- widgets/         # Reusable UI widgets (Badges, Empty states, Dialogs, Comments)
`-- main.dart        # MultiProvider initialization and root auth state gate
```

### 1.1 State Management Flow
- State is managed using **`Provider`** with `ChangeNotifier`.
- `MultiProvider` at the root injects singleton instances of `AuthProvider`, `TeamProvider`, `ProjectProvider`, `TaskProvider`, and `ActivityProvider`.
- Providers interact exclusively with `ApiClient` and expose reactive states (`isLoading`, `error`, `items`, `selectedItem`).
- Changes trigger `notifyListeners()`, causing consumer widgets to rebuild efficiently.

### 1.2 Networking & API Layer
- **`ApiClient`**: Centralized HTTP abstraction over `package:http/http.dart`.
  - Configurable `baseUrl` (defaults to `http://127.0.0.1:8000`).
  - Strict 10-second request timeouts.
  - Automatic injection of `Authorization: Bearer <token>` from `SecureStorageService`.
  - Global `401 Unauthorized` interceptor invoking `onUnauthorized` callback to transition the app to the login screen and clear local storage.
  - Maps HTTP status codes to typed exceptions: `BadRequestException` (400), `UnauthorizedException` (401), `ForbiddenException` (403), `NotFoundException` (404), `ConflictException` (409), `ValidationException` (422), `RateLimitException` (429), and `ApiException` (500+).

### 1.3 Secure Storage & Token Lifecycle
- `SecureStorageService` wraps `flutter_secure_storage` with fallback mechanisms across platforms.
- Stores JWT access token under key `auth_token`.
- On application boot, `AuthProvider.tryAutoLogin()` checks for an existing token, validates it against `GET /auth/me`, and navigates to `MainNavigationScreen` or `LoginScreen`.

### 1.4 Accessibility & Design System
- Built with **Material 3** theming (`AppTheme.lightTheme` and `AppTheme.darkTheme`).
- **Non-Color-Only Status & Priority**: Badges combine distinct icons, descriptive text labels, and color semantics to satisfy WCAG accessibility standards.
- Form inputs feature clear helper text, validation feedback, and minimum 48x48 dp touch targets.

---

## 2. Backend Architecture (`taskflow-backend/`)

- **FastAPI**: Async web framework providing automatic OpenAPI schema generation and validation.
- **Pydantic V2**: Request validation, response serialization, and data coercion with `extra="forbid"` on mutation schemas.
- **Motor**: Async MongoDB driver for non-blocking database queries.
- **Redis Manager**: Fail-open caching and fixed-window rate limiter using connection pooling.

---

## 3. Security & Access Control

- **Authentication**: JWT Bearer tokens signed with SHA-256 HMAC (30-minute expiration).
- **Authorization**: Backend RBAC on all endpoints across `admin`, `manager`, and `employee` roles.
  - Admins: Unrestricted access to all resources.
  - Managers: Scoped to teams they lead (`team.manager_id`), projects belonging to those teams, and tasks within those projects.
  - Employees: Scoped to teams they belong to (`team.member_ids`), projects under those teams, and tasks assigned to them or within their teams.
- **Rate Limiting**: 5 requests per 60 seconds per IP on sensitive authentication routes (`/auth/login`, `/auth/register`, `/auth/password`).