# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.0.1] - 2026-07-13

### Added
- **Backend** — Spring Boot 3.2 User Search REST API
  - `GET /api/users/search?q=` — search by name, email, or department
  - `GET /api/users` — list all users
  - `GET /api/users/{id}` — get user by ID
  - H2 in-memory database with 10 seeded demo users
  - 8 JUnit/MockMvc integration tests (all passing)
- **Frontend** — React 18 + Vite User Search UI
  - `UserSearch` component with debounced input
  - Role and department tags per user card
  - Dark theme with responsive layout
  - 7 Vitest/React Testing Library unit tests (all passing)
- **Hooks** — OpenCode AI hook scripts
  - `hooks/validate.sh` — PostToolUse: runs `mvn test` + `pnpm test`
  - `hooks/security-check.sh` — PostToolUse: scans for 8 security patterns
  - `hooks/generate-report.sh` — Stop: prints the Developer Report
- **Config** — `opencode.json` wires all hooks to PostToolUse and Stop events
- **Docker** — individual Dockerfiles for backend and frontend; `docker-compose.yml`
  for single-command startup

---
