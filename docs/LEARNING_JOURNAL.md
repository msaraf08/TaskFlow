# Learning Journal

## 04-08-2026

### Completed

- Project initialized
- FastAPI installed
- Virtual environment created
- Git initialized
- Swagger working
- Health API created

### Issue

VS Code couldn't resolve FastAPI imports.

### Cause

Virtual environment was created using Python 3.11.

### Solution

Deleted the old virtual environment and recreated it using:

```bash
py -3.13 -m venv venv
```

Selected:

```
venv/Scripts/python.exe
```

### Lesson

Always create a virtual environment using:

```bash
py -3.13 -m venv venv
```