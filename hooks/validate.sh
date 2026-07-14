#!/usr/bin/env bash
# =============================================================================
# validate.sh  —  PostToolUse hook
# Runs FastAPI tests (pytest) and React tests (pnpm) after every file change.
# Exit 0  → validation passed  (AI continues)
# Exit 1  → validation failed  (AI sees the error output and must fix it)
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"

PASS="[PASS]"
FAIL="[FAIL]"
INFO="[INFO]"

echo ""
echo "============================================="
echo "  VALIDATION HOOK — AI Hooks Demo"
echo "============================================="

# ── Determine which file was changed (OpenCode passes it via env) ──────────
CHANGED_FILE="${OPENCODE_TOOL_INPUT_PATH:-}"
echo "$INFO Changed file: ${CHANGED_FILE:-unknown}"

BACKEND_FAILED=0
FRONTEND_FAILED=0

# ── Run FastAPI tests if a backend file changed ───────────────────────────
run_backend=false
if [[ -z "$CHANGED_FILE" ]] || [[ "$CHANGED_FILE" == *"/backend/"* ]]; then
  run_backend=true
fi

# Prefer the project's virtualenv python if it exists.
if [ -x "$BACKEND_DIR/.venv/Scripts/python.exe" ]; then
  PY="$BACKEND_DIR/.venv/Scripts/python.exe"      # Windows venv
elif [ -x "$BACKEND_DIR/.venv/bin/python" ]; then
  PY="$BACKEND_DIR/.venv/bin/python"              # POSIX venv
elif command -v python3 &>/dev/null; then
  PY="python3"
elif command -v python &>/dev/null; then
  PY="python"
else
  PY=""
fi

if $run_backend && [ -n "$PY" ]; then
  echo ""
  echo "--- FastAPI Tests (pytest) ---"
  if (cd "$BACKEND_DIR" && "$PY" -m pytest -q 2>&1); then
    echo "$PASS FastAPI tests passed"
  else
    echo "$FAIL FastAPI tests FAILED"
    BACKEND_FAILED=1
  fi
elif $run_backend; then
  echo "$INFO python not found — skipping backend tests"
fi

# ── Run React tests if a frontend file changed ────────────────────────────
run_frontend=false
if [[ -z "$CHANGED_FILE" ]] || [[ "$CHANGED_FILE" == *"/frontend/"* ]]; then
  run_frontend=true
fi

if $run_frontend && [ -d "$FRONTEND_DIR/node_modules" ]; then
  echo ""
  echo "--- React Tests (pnpm test) ---"
  if (cd "$FRONTEND_DIR" && pnpm test 2>&1); then
    echo "$PASS React tests passed"
  else
    echo "$FAIL React tests FAILED"
    FRONTEND_FAILED=1
  fi
elif $run_frontend; then
  echo "$INFO node_modules not found — run 'pnpm install' first. Skipping frontend tests."
fi

echo ""
echo "============================================="
if [[ $BACKEND_FAILED -eq 0 && $FRONTEND_FAILED -eq 0 ]]; then
  echo "  VALIDATION RESULT: PASS"
  echo "============================================="
  exit 0
else
  echo "  VALIDATION RESULT: FAIL"
  [[ $BACKEND_FAILED -eq 1 ]]  && echo "  - FastAPI tests failed"
  [[ $FRONTEND_FAILED -eq 1 ]] && echo "  - React tests failed"
  echo "  Please fix the errors above before proceeding."
  echo "============================================="
  exit 1
fi
