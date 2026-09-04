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