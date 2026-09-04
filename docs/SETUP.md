# TaskFlow Setup Guide

## Prerequisites

- Python 3.13
- Docker Desktop
- Git
- VS Code
- Flutter SDK (for mobile/web client development)

---

## 1. Start Infrastructure Services

Run MongoDB and Redis via Docker Compose:

```bash
docker compose up -d
```

---

## 2. Backend Setup

Navigate to `taskflow-backend`:

### Create Virtual Environment

```bash
py -3.13 -m venv venv
```

### Activate Virtual Environment

**PowerShell (Windows):**

```powershell
.\venv\Scripts\Activate.ps1
```

**Bash / macOS / Linux:**

```bash
source venv/bin/activate
```

### Install Dependencies

```bash
pip install -r requirements.txt
```

### Configure Environment Variables

Copy template to create local configuration:

```bash
cp .env.example .env
```

---

## 3. Run Development Server

```bash
uvicorn app.main:app --reload
```

Interactive API documentation (Swagger UI) is available at:
`http://localhost:8000/docs`

---

## 4. Run Automated Tests

Execute the pytest suite:

```powershell
pytest -v
```