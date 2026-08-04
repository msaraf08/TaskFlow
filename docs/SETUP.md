# TaskFlow Setup Guide

## Prerequisites

- Python 3.13
- Docker Desktop
- Git
- VS Code
- Flutter SDK

## Create Virtual Environment

```bash
py -3.13 -m venv venv
```

## Activate

PowerShell

```powershell
.\venv\Scripts\Activate.ps1
```

## Install Packages

```bash
pip install -r requirements.txt
```

## Run

```bash
uvicorn app.main:app --reload
```