# Project Roadmap

## Sprint 1: Foundation & Security
- [x] Project Setup
- [x] FastAPI Backend
- [x] MongoDB Integration & Indexing
- [x] Redis Connection & Lifecycle
- [x] Docker Infrastructure (`compose.yaml`)

## Sprint 2: Authentication & User Profile
- [x] Authentication & JWT Verification
- [x] Role-Based Access Control (`admin`, `manager`, `employee`)
- [x] User Profile & Password Change

## Sprint 3: Employee Management
- [x] Employee Profile CRUD
- [x] Deactivation & Auth Sync

## Sprint 4: Team Management
- [x] Team CRUD & Manager Authorization
- [x] Member Assignment & Scoped Visibility

## Sprint 5: Project Management
- [x] Project CRUD & Lifecycle Statuses
- [x] Team Association & Dual-Team Authorization

## Sprint 6: Task Management & Audit Trail
- [x] Task CRUD & Prioritization
- [x] Dynamic Assignee Eligibility
- [x] Task Comments & Cascade Deletion
- [x] System Activity / Audit Trail

## Sprint 7: Redis Caching & Rate Limiting
- [x] Detail Endpoint Caching (300s TTL)
- [x] Exact Cache Mutation Invalidation
- [x] Auth Rate Limiting (5 req/60s, HTTP 429)
- [x] Fail-Open Resilience

## Sprint 8: Flutter Integration
- [x] Flutter Frontend App & State Management (`Provider`)
- [x] Backend API Integration (`ApiClient` + typed exceptions)
- [x] Role-scoped UI (Admin, Manager, Employee)
- [x] Non-color-only Accessibility Badges & Material 3 Theming
- [x] Automated Unit & Widget Test Suite (20 tests passing)

## Sprint 9: Production Packaging & Deployment
- [ ] Backend Containerization & Production Configuration
- [ ] Deployment & Monitoring