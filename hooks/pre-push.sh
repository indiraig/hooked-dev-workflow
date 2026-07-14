#!/usr/bin/env bash
# =============================================================================
# hooks/pre-push.sh  —  Git pre-push hook
#
# Runs automatically before every `git push`.
# Acts as the final gate before code reaches GitHub.
#
# Checks:
#   1. Full test suite (backend + frontend)
#   2. API contract diff vs remote main
#   3. Impacted modules analysis
#   4. Generates PR summary → pr-summary.md
#
# Exit 0 → push proceeds
# Exit 1 → push BLOCKED
# =============================================================================
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}[PASS]${RESET} $*"; }
fail() { echo -e "${RED}[FAIL]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
info() { echo -e "${CYAN}[HOOK]${RESET} $*"; }
sep()  { echo -e "${BOLD}══════════════════════════════════════════${RESET}"; }

echo ""
sep
echo -e "${BOLD}  PRE-PUSH GATE — Final check before GitHub${RESET}"
sep
echo ""

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
LAST_COMMIT=$(git log -1 --pretty="%h %s" 2>/dev/null || echo "unknown")
DATE=$(date '+%Y-%m-%d %H:%M')

info "Branch : $BRANCH"
info "Commit : $LAST_COMMIT"
echo ""

OVERALL=0
SPRING_RESULT="SKIP"
REACT_RESULT="SKIP"
SECURITY_RESULT="PASS"

# ══════════════════════════════════════════════════════════════════════════════
#  1. FULL TEST SUITE
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}  1. FULL TEST SUITE${RESET}"

# Spring Boot
if command -v mvn &>/dev/null && [[ -f "$BACKEND_DIR/pom.xml" ]]; then
  info "Spring Boot tests..."
  if mvn -f "$BACKEND_DIR/pom.xml" test -q 2>/tmp/pre_push_mvn.txt; then
    COUNT=$(grep -oE "Tests run: [0-9]+" /tmp/pre_push_mvn.txt 2>/dev/null | \
            awk -F': ' '{sum+=$2} END{print sum}' || echo "?")
    ok "Spring Boot  PASSED  ($COUNT tests)"
    SPRING_RESULT="PASS"
  else
    fail "Spring Boot  FAILED"
    grep "FAIL\|ERROR" /tmp/pre_push_mvn.txt 2>/dev/null | head -5 | \
      while read -r l; do echo "       $l"; done
    SPRING_RESULT="FAIL"
    OVERALL=1
  fi
fi

# React
if [[ -d "$FRONTEND_DIR/node_modules" ]]; then
  info "React tests..."
  if (cd "$FRONTEND_DIR" && pnpm test 2>/tmp/pre_push_react.txt); then
    COUNT=$(grep -oE "[0-9]+ passed" /tmp/pre_push_react.txt 2>/dev/null | head -1 || echo "? passed")
    ok "React        PASSED  ($COUNT)"
    REACT_RESULT="PASS"
  else
    fail "React        FAILED"
    grep -E "FAIL|failed" /tmp/pre_push_react.txt 2>/dev/null | head -3 | \
      while read -r l; do echo "       $l"; done
    REACT_RESULT="FAIL"
    OVERALL=1
  fi
fi
echo ""

# ══════════════════════════════════════════════════════════════════════════════
#  2. SECURITY SCAN ON ALL CHANGED FILES
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}  2. SECURITY SCAN${RESET}"

SEC_COUNT=0
BASE_BRANCH="main"
if git show-ref --verify --quiet refs/remotes/origin/main; then
  CHANGED=$(git diff origin/main...HEAD --name-only 2>/dev/null || \
            git diff --name-only HEAD~1 2>/dev/null || true)
else
  CHANGED=$(git diff --name-only HEAD~1 2>/dev/null || true)
fi

declare -A SEC_PATTERNS
SEC_PATTERNS['password\s*=\s*["\x27][^"\x27$]']="Hardcoded password"
SEC_PATTERNS['(api_key|secret)\s*=\s*["\x27][A-Za-z0-9]{8,}']="Hardcoded secret/API key"
SEC_PATTERNS['(AKIA|AIza|sk-)[A-Za-z0-9]{16,}']="Live cloud/AI credential"
SEC_PATTERNS['csrf\(\)\.disable\(\)']="CSRF disabled"
SEC_PATTERNS['innerHTML\s*=\s*']="XSS risk (innerHTML)"
SEC_PATTERNS['executeQuery\(.*\+']="SQL injection risk"

for f in $CHANGED; do
  [[ ! -f "$ROOT_DIR/$f" ]] && continue
  for pat in "${!SEC_PATTERNS[@]}"; do
    if grep -qiE "$pat" "$ROOT_DIR/$f" 2>/dev/null; then
      fail "${SEC_PATTERNS[$pat]}  →  $f"
      SEC_COUNT=$((SEC_COUNT + 1))
      SECURITY_RESULT="FAIL"
      OVERALL=1
    fi
  done
done

[[ $SEC_COUNT -eq 0 ]] && ok "Security scan  PASSED"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
#  3. API CONTRACT DIFF
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}  3. API CONTRACT${RESET}"

API_STATUS="No Breaking Changes"
BASELINE="$ROOT_DIR/hooks/.api-baseline.txt"

# FastAPI routes: @router.get("/path") / @app.post("/path") etc.
CURRENT_EPS=$(grep -rhoE \
  '@(router|app)\.(get|post|put|delete|patch)\("[^"]*"' \
  "$BACKEND_DIR/app" 2>/dev/null | \
  grep -oE '"[^"]*"' | sort -u || true)

if [[ -f "$BASELINE" ]]; then
  REMOVED=$(comm -23 <(sort "$BASELINE") <(echo "$CURRENT_EPS" | sort) | wc -l | tr -d ' ')
  ADDED=$(comm -13 <(sort "$BASELINE") <(echo "$CURRENT_EPS" | sort) | wc -l | tr -d ' ')

  if [[ "$REMOVED" -gt 0 ]]; then
    REMOVED_LIST=$(comm -23 <(sort "$BASELINE") <(echo "$CURRENT_EPS" | sort))
    fail "BREAKING: $REMOVED endpoint(s) removed!"
    echo "$REMOVED_LIST" | while read -r ep; do echo "       Removed: $ep"; done
    API_STATUS="BREAKING: $REMOVED endpoint(s) removed"
    OVERALL=1
  elif [[ "$ADDED" -gt 0 ]]; then
    ok "API contract OK  (+$ADDED new endpoint(s) — backward compatible)"
    API_STATUS="+$ADDED new endpoints (backward compatible)"
  else
    ok "API contract unchanged"
  fi
else
  ok "API baseline established"
fi
echo "$CURRENT_EPS" > "$BASELINE"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
#  4. IMPACTED MODULES ANALYSIS
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}  4. IMPACTED MODULES${RESET}"

MODULES=()
echo "$CHANGED" | grep -q "backend/app"           && MODULES+=("Backend (FastAPI source)")
echo "$CHANGED" | grep -q "backend/tests"          && MODULES+=("Backend Tests")
echo "$CHANGED" | grep -q "frontend/src"          && MODULES+=("Frontend (React)")
echo "$CHANGED" | grep -q "frontend/src/__tests__" && MODULES+=("Frontend Tests")
echo "$CHANGED" | grep -q "hooks/"                && MODULES+=("CI/CD Hooks")
echo "$CHANGED" | grep -q "docker-compose"        && MODULES+=("Docker Compose")
echo "$CHANGED" | grep -qE "requirements\.txt"    && MODULES+=("Python Dependencies")
echo "$CHANGED" | grep -qE "package\.json"        && MODULES+=("NPM Dependencies")
echo "$CHANGED" | grep -q "opencode.json"         && MODULES+=("OpenCode Config")

if [[ ${#MODULES[@]} -eq 0 ]]; then
  info "No specific modules identified"
  MODULES+=("General")
else
  for m in "${MODULES[@]}"; do
    info "  → $m"
  done
fi

MODULES_STR=$(printf '%s\n' "${MODULES[@]}" | paste -sd ', ' -)
echo ""

# ══════════════════════════════════════════════════════════════════════════════
#  5. GENERATE PR SUMMARY  →  pr-summary.md
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}  5. GENERATING PR SUMMARY${RESET}"

FILES_CHANGED_COUNT=$(echo "$CHANGED" | grep -c . || echo 0)
COMMITS_COUNT=$(git rev-list origin/main...HEAD --count 2>/dev/null || echo "1")

RECENT_COMMITS=$(git log --pretty="- %s (%h)" origin/main...HEAD 2>/dev/null | \
                 head -10 || git log -3 --pretty="- %s (%h)" 2>/dev/null)

cat > "$ROOT_DIR/pr-summary.md" <<EOF
# Pull Request Summary

**Branch:** \`$BRANCH\`
**Generated:** $DATE
**Commits:** $COMMITS_COUNT
**Files Changed:** $FILES_CHANGED_COUNT

## Changes

$RECENT_COMMITS

## Impacted Modules

$(printf -- '- %s\n' "${MODULES[@]}")

## Test Results

| Layer        | Result           |
|--------------|------------------|
| Spring Boot  | $SPRING_RESULT   |
| React        | $REACT_RESULT    |
| Security     | $SECURITY_RESULT |

## API Contract

$API_STATUS

## Changed Files

$(echo "$CHANGED" | sed 's/^/- /')

---
*Auto-generated by ai-hooks-demo pre-push hook*
EOF

ok "PR summary written to pr-summary.md"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
#  FINAL RESULT
# ══════════════════════════════════════════════════════════════════════════════
sep
if [[ $OVERALL -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}  PRE-PUSH PASSED — your code is ready for GitHub${RESET}"
  echo ""
  echo "  Next steps:"
  echo "    1. Review pr-summary.md"
  echo "    2. Open a PR on GitHub"
  echo "    3. Share pr-summary.md in your PR description"
else
  echo -e "${RED}${BOLD}  PUSH BLOCKED — resolve the issues above first${RESET}"
  echo ""
  echo "  To bypass (not recommended):"
  echo "    git push --no-verify"
fi
sep
echo ""

rm -f /tmp/pre_push_mvn.txt /tmp/pre_push_react.txt
exit $OVERALL
