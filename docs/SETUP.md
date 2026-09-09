# TaskFlow Setup Guide

## Prerequisites

- Python 3.13
- Docker Desktop
- Git
- VS Code / Android Studio
- Flutter SDK (3.x / Dart 3.x)

---

## 1. Start Infrastructure Services

Run MongoDB and Redis via Docker Compose:

```bash
docker compose up -d
```

Verify services are healthy:
```bash
docker compose ps
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

### Run Backend Server

```bash
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Interactive API documentation (Swagger UI) is available at:
`http://localhost:8000/docs`

### Run Backend Tests

```powershell
pytest -v
```

---

## 3. Flutter Frontend Setup

Navigate to `taskflow-app`:

### Install Dependencies

```bash
cd taskflow-app
flutter pub get
```

### Run Automated Tests

Execute the Flutter unit and widget test suite:

```bash
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

By default, the client connects to `http://127.0.0.1:8000`. You can override this at launch:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000  # For Android Emulator
```