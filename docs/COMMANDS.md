# Useful Commands

## Docker & Container Management

### Full Stack Orchestration
```bash
docker compose up --build -d  # Build and start all services (FastAPI, MongoDB, Redis)
docker compose up -d          # Start existing services in background
docker compose down           # Stop and remove containers and networks
docker compose down -v        # Stop and remove containers, networks, and named volumes
docker compose ps             # Check status and health of all containers
docker compose config         # Validate and render Compose configuration
```

### Logs & Diagnostics
```bash
docker compose logs -f        # Stream logs for all services
docker compose logs -f backend# Stream backend service logs
docker compose logs -f mongodb# Stream MongoDB logs
docker compose logs -f redis  # Stream Redis logs
```

### Container Execution & Health
```bash
docker compose exec backend whoami     # Verify non-root user (taskflow)
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')" # Test Mongo ping
docker compose exec redis redis-cli ping # Test Redis ping
curl http://localhost:8000/health       # Check backend health endpoint
```

---

## Backend (FastAPI & Python Local Development)

### Virtual Environment
```bash
py -3.13 -m venv venv         # Create virtual environment
.\venv\Scripts\Activate.ps1   # Activate (Windows PowerShell)
source venv/bin/activate      # Activate (Bash/Linux/macOS)
deactivate                    # Deactivate
```

### Dependencies
```bash
pip install -r requirements.txt
```

### Run Backend Server (Host)
```bash
uvicorn app.main:app --reload
```

### Backend Automated Tests
```bash
pytest -q                     # Run all backend tests
pytest -v                     # Run with verbose output
```

---

## Frontend (Flutter & Dart)

### Dependencies
```bash
cd taskflow-app
flutter pub get
```

### Run Flutter Application
```bash
flutter run -d chrome         # Run on Chrome Web
flutter run -d windows        # Run on Windows Desktop
flutter run                   # Run on default connected device / emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 # Run on Android Emulator
```

### Frontend Automated Tests & Linting
```bash
flutter analyze               # Run static analyzer
flutter test                  # Run all unit and widget tests
flutter test --coverage       # Run tests with coverage report
dart format --output=none --set-exit-if-changed . # Check code formatting
dart format .                 # Format all Dart files
```

---

## Version Control (Git)
```bash
git status --short
git add .
git diff
```