## Passlib and bcrypt compatibility issue

### Error

ValueError: password cannot be longer than 72 bytes

### Cause

passlib 1.7.4 was being used with bcrypt 5.0.0.

### Solution

Use bcrypt 4.3.0:

```bash
pip uninstall bcrypt -y
pip install bcrypt==4.3.0