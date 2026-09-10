# TaskFlow Setup Guide

## Prerequisites

- Python 3.13
- Docker Desktop
- Git
- VS Code / Android Studio
- Flutter SDK (3.x / Dart 3.x)

---

## Deployment & Development Modes

TaskFlow can be run in two primary modes:
1. **Mode A: Full Docker Compose Stack** (Backend + MongoDB + Redis containerized together)
2. **Mode B: Hybrid Development** (MongoDB & Redis containerized, FastAPI backend running on host virtual environment for live debugging)

---

## 1. Mode A: Full Docker Compose Stack

Run the complete backend stack (FastAPI, MongoDB, Redis) in containers:

### 1.1 Configure Environment

Copy `.env.example` to create your environment configuration:

```bash
cp taskflow-backend/.env.example .env
```

Ensure `JWT_SECRET` is set to a secure key in your `.env` file.

### 1.2 Build and Start Services

```bash
docker compose up --build -d
```

### 1.3 Verify Services and Health

Check container status and health:

```bash
docker compose ps
```

Verify backend health:
```bash
curl http://localhost:8000/health
```

Interactive API documentation (Swagger UI) is available at:
`http://localhost:8000/docs`

### 1.4 View Logs & Stop Stack

```bash
docker compose logs -f backend
docker compose down
```

---

## 2. Mode B: Hybrid Local Development

In this mode, MongoDB and Redis run in Docker while FastAPI runs on your host Python interpreter for fast iteration.

### 2.1 Start Database and Cache

```bash
docker compose up -d mongodb redis
```

### 2.2 Backend Setup

Navigate to `taskflow-backend`:

#### Create Virtual Environment

```bash
py -3.13 -m venv venv
```

#### Activate Virtual Environment

**PowerShell (Windows):**
```powershell
.\venv\Scripts\Activate.ps1
```

**Bash / macOS / Linux:**
```bash
source venv/bin/activate
```

#### Install Dependencies

```bash
pip install -r requirements.txt
```

#### Configure Environment Variables

```bash
cp .env.example .env
```

#### Run Backend Server

```bash
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

#### Run Backend Tests

```powershell
pytest -q
```

---

## 3. Flutter Frontend Setup

Navigate to `taskflow-app`:

### Install Dependencies

```bash
cd taskflow-app
flutter pub get
```

### Run Automated Tests & Static Analysis

```bash
flutter analyze
flutter test
```

### Run Frontend Application

**Run on Chrome / Web:**
```bash
flutter run -d chrome
```

**Run on Windows Desktop:**
```bash
flutter run -d windows
```

**Run on Connected Mobile Device / Emulator:**
```bash
flutter run
```

### Customizing Backend URL

By default, the client connects to `http://localhost:8000`. You can override this at launch:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000  # For Android Emulator
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000 # For Physical Device
```