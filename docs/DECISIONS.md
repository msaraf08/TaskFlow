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