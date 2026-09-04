# Changelog

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