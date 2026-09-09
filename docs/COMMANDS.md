# Useful Commands

## Infrastructure (Docker)

```bash
docker compose up -d          # Start MongoDB & Redis
docker compose down           # Stop services
docker compose ps             # Check service status
```

---

## Backend (FastAPI & Python)

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
pip freeze > requirements.txt
```

### Run Backend Server

```bash
uvicorn app.main:app --reload
```

### Backend Automated Tests

```bash
pytest -v
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
flutter run -d chrome         # Run on Chrome
flutter run -d windows        # Run on Windows Desktop
flutter run                   # Run on default connected device / emulator
```

### Frontend Automated Tests & Linting

```bash
flutter test                  # Run all unit and widget tests
flutter test --coverage       # Run tests with coverage report
flutter analyze               # Run static analyzer
dart format --output=none --set-exit-if-changed . # Check formatting
```

---

## Version Control (Git)

```bash
git status
git add .
git diff
```