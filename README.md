# AI Assisted Developer Workflow with Claude Code Hooks

A full-stack **FastAPI + React** demo that shows how OpenCode AI hooks
automatically validate every code change and generate a developer report
before you push to GitHub.

---

## Project Structure

```
ai-hooks-demo/
├── backend/              # FastAPI — User Search REST API
│   ├── app/
│   ├── tests/
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/             # React 18 + Vite — User Search UI
│   ├── src/
│   ├── package.json
│   └── Dockerfile
├── hooks/                # OpenCode hook scripts
│   ├── validate.sh       # Runs pytest + pnpm test
│   ├── security-check.sh # Scans for security anti-patterns
│   └── generate-report.sh# Produces the Developer Report
├── opencode.json         # OpenCode hook configuration
├── docker-compose.yml
├── CHANGELOG.md
└── README.md
```

---

## API Contract

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/users` | Return all users |
| GET | `/api/users/search?q=<term>` | Search by name, email, or department |
| GET | `/api/users/{id}` | Get user by ID |
| GET | `/api/users/role/{role}` | Get users by role (case-insensitive) |
| POST | `/api/users` | Create a user |
| PUT | `/api/users/{id}` | Update a user (partial) |
| DELETE | `/api/users/{id}` | Delete a user |

Example:
```
GET http://localhost:8080/api/users/search?q=john

[
  { "id": 1, "name": "John Doe", "email": "john.doe@example.com",
    "role": "Engineer", "department": "Backend" }
]
```

---

## How the Hooks Work

```
Developer asks AI to change code
        │
        ▼
  AI edits a file
        │
        ▼  PostToolUse hook fires
  ┌─────────────────────────┐
  │  validate.sh            │  → pytest    (FastAPI)
  │  security-check.sh      │  → npm test  (React)
  └─────────────────────────┘  → secret / SQL-injection scan
        │
        ▼  AI session ends
  ┌─────────────────────────┐
  │  generate-report.sh     │  → prints Developer Report
  └─────────────────────────┘
```

### Developer Report (output)

```
========================================
  DEVELOPER REPORT
========================================
  Feature:        User Search API
  Branch:         feature/user-search
  Files Changed:  3

  Tests:
    FastAPI       PASS
    React         PASS

  Security:       PASS
  API:            No Breaking Changes

  Ready for Pull Request
========================================
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| Python | 3.11+ |
| Node.js | 20+ |
| pnpm | 9+ |
| Docker + Docker Compose | 24+ (optional) |

---

## Running Locally

### 1. Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8080
# API available at   http://localhost:8080
# Swagger UI at      http://localhost:8080/docs
```

### 2. Frontend

```bash
cd frontend
pnpm install
pnpm dev
# UI available at http://localhost:5173
```

### 3. Both via Docker Compose

```bash
docker-compose up --build
# Frontend → http://localhost:5173
# Backend  → http://localhost:8080
```

---

## Running Tests

```bash
# FastAPI
cd backend && pytest

# React
cd frontend && pnpm test
```

---

## Running Hooks Manually

```bash
# From project root
bash hooks/validate.sh        # run all tests
bash hooks/security-check.sh  # security scan
bash hooks/generate-report.sh # print developer report
```

---

## OpenCode Hook Configuration

Hooks are declared in `opencode.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      { "matcher": { "tool": "write_file" }, "command": "bash hooks/validate.sh" },
      { "matcher": { "tool": "edit_file" },  "command": "bash hooks/validate.sh && bash hooks/security-check.sh" }
    ],
    "Stop": [
      { "command": "bash hooks/generate-report.sh" }
    ]
  }
}
```

---

## License

MIT
