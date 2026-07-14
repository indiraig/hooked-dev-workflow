# Contributing

Thanks for your interest in improving this project!

## Getting started

```bash
# Backend (FastAPI)
cd backend
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8080

# Frontend (React + Vite)
cd frontend
pnpm install
pnpm dev
```

## Before opening a pull request

Please make sure all tests pass:

```bash
# Backend
cd backend && pytest

# Frontend
cd frontend && pnpm test
```

## Guidelines

- Keep changes focused and small.
- Follow the existing code style.
- Add or update tests for any behavior you change.
- Do not commit secrets, `.env` files, build output (`dist/`, `target/`),
  or virtual environments (`.venv/`).
