# Hooked Developer AI Workflow

> An AI-assisted developer workflow where **hooks** act as an automated engineering
> teammate — validating, securing, and reporting on every change the moment your AI
> coding assistant touches the code.
>
> Built as a full-stack **React + FastAPI** demo, orchestrated by **OpenCode hooks**.

---

## The question every developer with an AI assistant eventually asks

Imagine you are building a **React + FastAPI** application.

You ask your AI coding assistant (GitHub Copilot, Claude Code, or OpenCode) to implement
a new API, fix a bug, or refactor a feature. The AI updates multiple files. You review
the changes and click **"Keep"**.

Now comes the familiar routine before pushing to the `develop` branch. Do you do these
steps *every single time*?

- ✅ Review all AI-modified files
- ✅ Verify coding standards
- ✅ Run backend tests (`pytest`)
- ✅ Build / start the application and check startup logs
- ✅ Run React tests
- ✅ Run ESLint / Prettier
- ✅ Verify API contracts
- ✅ Check dependency vulnerabilities
- ✅ Write a meaningful commit message
- ✅ Update the CHANGELOG (if required)
- ✅ Push to GitHub
- ✅ Create a Pull Request + write a PR description
- ✅ Wait for CI to discover issues you could have caught earlier

Most developers do some — or all — of these steps every day.

**What if your AI assistant could run these checks automatically, the moment you accept
the change?**

That is exactly what this project demonstrates.

---

## The shift

| Today | Tomorrow |
|-------|----------|
| *"I need to remember my team's engineering process."* | *"My development environment remembers it for me."* |

AI coding assistants are not only about writing code faster. The next evolution is making
AI **understand and enforce how your team builds software**. Hooks are the mechanism that
makes this possible — they run at specific moments in your workflow and behave like an
automated engineering teammate.

---

## What the hooks do

**🔹 After code changes** (`PostToolUse`)
- Detect which files were modified
- Run **only** the checks relevant to that layer
  - React changes → run tests, lint, and build
  - FastAPI changes → run `pytest`, static analysis, and API-contract validation

**🔹 Before Git commit** (`pre-commit`, `prepare-commit-msg`)
- Check coding standards
- Scan for security issues (secrets, SQL injection, unsafe patterns)
- Generate a meaningful commit message

**🔹 Before Pull Request** (`pre-push`)
- Run the full test suite as a final gate
- Verify API-contract changes (flag removed/renamed endpoints)
- Highlight impacted modules
- Generate a PR summary with attached test results → `pr-summary.md`

**🔹 After the AI session ends** (`Stop`)
- Notify the team with a summary of everything that changed

---

## Hook lifecycle

```
Developer asks AI to change code
        │
        ▼
   AI edits a file  →  you approve / press "Keep"
        │
        ▼  PostToolUse hook fires
  ┌───────────────────────────────┐
  │  post-tool-use.sh             │  → detects layer (frontend / backend)
  │                               │  → React:  pnpm test + eslint + vite build
  │                               │  → FastAPI: pytest + API-contract check
  └───────────────────────────────┘
        │
        ▼  git commit
  ┌───────────────────────────────┐
  │  pre-commit.sh                │  → standards + security scan
  │  prepare-commit-msg.sh        │  → meaningful commit message
  └───────────────────────────────┘
        │
        ▼  git push
  ┌───────────────────────────────┐
  │  pre-push.sh                  │  → full test suite (FINAL GATE)
  │                               │  → API-contract diff
  │                               │  → PR summary → pr-summary.md
  └───────────────────────────────┘
        │
        ▼  AI session ends
  ┌───────────────────────────────┐
  │  notify-team.sh               │  → team notification + change summary
  └───────────────────────────────┘
```

### Example pre-push output

```
══════════════════════════════════════════
  PRE-PUSH GATE — Final check before GitHub
══════════════════════════════════════════
  1. FULL TEST SUITE
  [PASS] React        PASSED
  2. SECURITY SCAN
  [PASS] Security scan  PASSED
  3. API CONTRACT
  [PASS] API contract unchanged
  5. GENERATING PR SUMMARY
  [PASS] PR summary written to pr-summary.md
══════════════════════════════════════════
  PRE-PUSH PASSED — your code is ready for GitHub
══════════════════════════════════════════
```

---

## Project structure

```
ai-hooks-demo/
├── backend/                  # FastAPI — User Search REST API
│   ├── app/
│   │   ├── main.py           # app entrypoint + CORS + /health
│   │   ├── models.py         # SQLAlchemy models
│   │   ├── schemas.py        # Pydantic schemas
│   │   ├── repository.py     # data-access layer
│   │   ├── routers/users.py  # user CRUD + search routes
│   │   └── seed.py           # demo data
│   ├── tests/                # pytest suite
│   └── requirements.txt
├── frontend/                 # React 18 + Vite — User Search UI
│   ├── src/
│   │   ├── components/UserSearch.jsx
│   │   ├── services/userApi.js
│   │   └── __tests__/        # vitest suite
│   └── package.json
├── hooks/                    # Workflow hook scripts
│   ├── post-tool-use.sh      # PostToolUse: layer-aware validation
│   ├── notify-team.sh        # Stop: team notification
│   ├── pre-commit.sh         # git: standards + security
│   ├── prepare-commit-msg.sh # git: commit-message generation
│   ├── pre-push.sh           # git: final gate + PR summary
│   ├── validate.sh           # standalone: run all tests
│   ├── security-check.sh     # standalone: security scan
│   ├── generate-report.sh    # standalone: developer report
│   └── install-git-hooks.sh  # installs the git hooks
├── opencode.json             # OpenCode hook configuration
├── docker-compose.yml
├── CHANGELOG.md
└── README.md
```

---

## API contract

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

## Prerequisites

| Tool | Version |
|------|---------|
| Python | 3.11+ |
| Node.js | 20+ |
| pnpm | 9+ |
| Docker + Docker Compose | 24+ (optional) |

---

## Running locally

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

## Running tests

```bash
# FastAPI
cd backend && pytest

# React
cd frontend && pnpm test
```

---

## Running the hooks manually

```bash
# From the project root
bash hooks/validate.sh         # run all tests
bash hooks/security-check.sh   # security scan
bash hooks/generate-report.sh  # print the developer report
bash hooks/pre-push.sh         # final gate + PR summary
```

### Installing the git hooks

```bash
bash hooks/install-git-hooks.sh
# wires pre-commit, prepare-commit-msg, and pre-push into .git/hooks
```

---

## OpenCode hook configuration

Hooks are declared in `opencode.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      { "matcher": { "tool": "write_file" }, "command": "bash hooks/post-tool-use.sh" },
      { "matcher": { "tool": "edit_file" },  "command": "bash hooks/post-tool-use.sh" },
      { "matcher": { "tool": "patch_file" }, "command": "bash hooks/post-tool-use.sh" }
    ],
    "Stop": [
      { "command": "bash hooks/notify-team.sh" }
    ]
  }
}
```

`PostToolUse` fires only after you approve an AI file change; the script reads the JSON
payload OpenCode sends on `stdin`, detects whether the changed file is frontend or
backend, and runs only the relevant checks.

---

## The takeaway

> The one repetitive validation step you perform before every `git push` — the one you
> wish could be automated — is exactly the kind of step a hook is built to own.

AI assistants write the code. Hooks make sure it meets your team's bar *before* it ever
reaches GitHub.

---

## License

MIT
