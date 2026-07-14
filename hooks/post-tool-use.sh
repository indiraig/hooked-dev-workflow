#!/usr/bin/env bash
# =============================================================================
# hooks/post-tool-use.sh
#
# Triggered by OpenCode ONLY when you approve / press Enter on an AI change.
# Never runs during normal `mvn test` or `pnpm test`.
#
# Flow:
#   AI edits file  →  you approve  →  OpenCode fires PostToolUse
#   →  this script reads which file changed
#   →  detects layer (frontend / backend / config / hook)
#   →  runs ONLY the checks relevant to that layer
# =============================================================================
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Colour helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()  { echo -e "${CYAN}[AI-HOOK]${RESET} $*"; }
ok()    { echo -e "${GREEN}[PASS]${RESET}    $*"; }
fail()  { echo -e "${RED}[FAIL]${RESET}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET}    $*"; }
sep()   { echo -e "${BOLD}──────────────────────────────────────────${RESET}"; }

# ── Extract file path from OpenCode's stdin JSON payload ───────────────────
# OpenCode sends JSON on stdin: { "toolName": "...", "input": { "path": "..." } }
PAYLOAD=""
if [ -t 0 ]; then
  FILE_PATH="${OPENCODE_TOOL_INPUT_PATH:-}"           # env-var fallback
else
  PAYLOAD=$(cat)
  # Try jq first, then python3, then grep fallback
  if command -v jq &>/dev/null; then
    FILE_PATH=$(echo "$PAYLOAD" | jq -r '
      .input.path // .tool_input.path // .input.file_path // ""
    ' 2>/dev/null || echo "")
  elif command -v python3 &>/dev/null; then
    FILE_PATH=$(echo "$PAYLOAD" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    inp = d.get('input', d.get('tool_input', {}))
    print(inp.get('path', inp.get('file_path', '')))
except: print('')
" 2>/dev/null || echo "")
  else
    FILE_PATH=$(echo "$PAYLOAD" | grep -oE '"path"\s*:\s*"[^"]+"' | \
                head -1 | sed 's/.*"path"\s*:\s*"\(.*\)"/\1/' || echo "")
  fi
  # Absolute path if relative
  [[ -n "$FILE_PATH" && "$FILE_PATH" != /* ]] && FILE_PATH="$ROOT_DIR/$FILE_PATH"
fi

FILE_PATH="${FILE_PATH:-unknown}"

echo ""
sep
echo -e "${BOLD}  AI CODE CHANGE DETECTED${RESET}"
sep
info "File: ${FILE_PATH#$ROOT_DIR/}"
echo ""

# ── Classify the changed file ──────────────────────────────────────────────
is_frontend=false
is_backend=false

case "$FILE_PATH" in
  */frontend/src/*|*\.jsx|*\.tsx|*\.js|*\.ts|*\.css)
    is_frontend=true ;;
  */backend/src/*|*\.java|*/pom.xml)
    is_backend=true ;;
  */frontend/*)
    is_frontend=true ;;
  */backend/*)
    is_backend=true ;;
esac

# If path unknown, check both (safe default)
if [[ "$FILE_PATH" == "unknown" ]]; then
  is_frontend=true
  is_backend=true
fi

OVERALL_STATUS=0

# ══════════════════════════════════════════════════════════════════════════════
#  FRONTEND CHECKS  (React change detected)
# ══════════════════════════════════════════════════════════════════════════════
if $is_frontend; then
  echo -e "${BOLD}  REACT CHECKS${RESET}"
  sep

  FRONTEND_DIR="$ROOT_DIR/frontend"

  # 1. Unit tests
  info "Running React unit tests (vitest)..."
  if [[ -d "$FRONTEND_DIR/node_modules" ]]; then
    if (cd "$FRONTEND_DIR" && pnpm test 2>&1 | tee /tmp/react_test_out.txt | \
        grep -E "Tests.*passed|Test Files.*passed" > /dev/null); then
      ok "React tests PASSED"
    else
      RESULT=$(grep -E "passed|failed|Tests" /tmp/react_test_out.txt 2>/dev/null | tail -2)
      fail "React tests FAILED"
      echo "       $RESULT"
      OVERALL_STATUS=1
    fi
  else
    warn "node_modules not found — run 'pnpm install' first"
  fi

  # 2. ESLint (if configured)
  if [[ -f "$FRONTEND_DIR/eslint.config.js" || -f "$FRONTEND_DIR/.eslintrc.js" || \
        -f "$FRONTEND_DIR/.eslintrc.json" ]]; then
    info "Running ESLint..."
    if (cd "$FRONTEND_DIR" && pnpm exec eslint src --max-warnings 0 2>&1); then
      ok "ESLint PASSED"
    else
      fail "ESLint found issues"
      OVERALL_STATUS=1
    fi
  else
    warn "ESLint not configured — skipping lint check"
  fi

  # 3. Build check (vite build --dry-run / type-check)
  info "Checking Vite build compiles..."
  if (cd "$FRONTEND_DIR" && pnpm exec vite build --mode development 2>&1 | \
      grep -v "^$" | tail -5 | tee /tmp/vite_build.txt > /dev/null); then
    ok "Vite build PASSED"
  else
    # Non-fatal: build warnings don't block
    VITE_ERR=$(grep -i "error" /tmp/vite_build.txt 2>/dev/null | head -3)
    if [[ -n "$VITE_ERR" ]]; then
      fail "Vite build FAILED"
      echo "       $VITE_ERR"
      OVERALL_STATUS=1
    else
      ok "Vite build PASSED (with warnings)"
    fi
  fi

  rm -f /tmp/react_test_out.txt /tmp/vite_build.txt
  echo ""
fi

# ══════════════════════════════════════════════════════════════════════════════
#  BACKEND CHECKS  (Spring Boot change detected)
# ══════════════════════════════════════════════════════════════════════════════
if $is_backend; then
  echo -e "${BOLD}  SPRING BOOT CHECKS${RESET}"
  sep

  BACKEND_DIR="$ROOT_DIR/backend"

  if ! command -v mvn &>/dev/null; then
    warn "Maven (mvn) not found in PATH — skipping backend checks"
  else
    # 1. Maven test
    info "Running Spring Boot tests (mvn test)..."
    if (cd "$BACKEND_DIR" && mvn test -q 2>&1 | tee /tmp/mvn_test.txt > /dev/null); then
      TEST_COUNT=$(grep -oE "Tests run: [0-9]+" /tmp/mvn_test.txt | tail -1)
      ok "Maven tests PASSED  ($TEST_COUNT)"
    else
      FAIL_LINE=$(grep -E "FAIL|ERROR|Tests run" /tmp/mvn_test.txt | tail -3)
      fail "Maven tests FAILED"
      echo "       $FAIL_LINE"
      OVERALL_STATUS=1
    fi

    # 2. Checkstyle (if plugin present in pom.xml)
    if grep -q "checkstyle" "$BACKEND_DIR/pom.xml" 2>/dev/null; then
      info "Running Checkstyle..."
      if (cd "$BACKEND_DIR" && mvn checkstyle:check -q 2>&1); then
        ok "Checkstyle PASSED"
      else
        fail "Checkstyle violations found"
        OVERALL_STATUS=1
      fi
    else
      warn "Checkstyle not in pom.xml — skipping static analysis"
    fi

    # 3. API contract validation
    # Compare current endpoints to baseline; flag removed/renamed ones
    info "Validating API contract..."
    BASELINE="$ROOT_DIR/hooks/.api-baseline.txt"
    CURRENT=$(grep -rhoE \
      '@(router|app)\.(get|post|put|delete|patch)\("[^"]*"' \
      "$BACKEND_DIR/app" 2>/dev/null | \
      grep -oE '"[^"]*"' | sort -u || true)

    if [[ -f "$BASELINE" ]]; then
      REMOVED=$(comm -23 \
        <(cat "$BASELINE" | sort) \
        <(echo "$CURRENT" | sort) | wc -l | tr -d ' ')
      ADDED=$(comm -13 \
        <(cat "$BASELINE" | sort) \
        <(echo "$CURRENT" | sort) | wc -l | tr -d ' ')
      if [[ "$REMOVED" -gt 0 ]]; then
        fail "API CONTRACT BROKEN — $REMOVED endpoint(s) removed!"
        comm -23 <(cat "$BASELINE" | sort) <(echo "$CURRENT" | sort) | \
          while read -r ep; do echo "       Removed: $ep"; done
        OVERALL_STATUS=1
      elif [[ "$ADDED" -gt 0 ]]; then
        ok "API contract OK  (+$ADDED new endpoint(s))"
      else
        ok "API contract unchanged"
      fi
    else
      ok "API baseline created"
    fi
    echo "$CURRENT" > "$BASELINE"

    rm -f /tmp/mvn_test.txt
  fi
  echo ""
fi

# ══════════════════════════════════════════════════════════════════════════════
#  RESULT SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
sep
if [[ $OVERALL_STATUS -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}  ALL CHECKS PASSED — change is safe to commit${RESET}"
else
  echo -e "${RED}${BOLD}  CHECKS FAILED — fix the issues above before committing${RESET}"
fi
sep
echo ""

exit $OVERALL_STATUS
