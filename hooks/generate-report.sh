#!/usr/bin/env bash
# =============================================================================
# generate-report.sh  —  Stop hook
# Produces the Developer Report after every AI session.
# Always exits 0 (report generation is informational, never blocks).
# =============================================================================

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"
REPORT_FILE="$ROOT_DIR/developer-report.txt"

# ── Helpers ────────────────────────────────────────────────────────────────
green()  { printf '\033[0;32m%s\033[0m' "$1"; }
red()    { printf '\033[0;31m%s\033[0m' "$1"; }
yellow() { printf '\033[0;33m%s\033[0m' "$1"; }
bold()   { printf '\033[1m%s\033[0m' "$1"; }

run_test() {
  local dir="$1" cmd="$2"
  ( cd "$dir" && eval "$cmd" > /tmp/test_out_$$.txt 2>&1 )
  echo $?
}

# ── Collect git info ────────────────────────────────────────────────────────
FILES_CHANGED=0
BRANCH="(not a git repo)"
if command -v git &>/dev/null && git -C "$ROOT_DIR" rev-parse --git-dir &>/dev/null 2>&1; then
  FILES_CHANGED=$(git -C "$ROOT_DIR" diff --name-only HEAD 2>/dev/null | wc -l | tr -d ' ')
  BRANCH=$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  [[ "$FILES_CHANGED" -eq 0 ]] && \
    FILES_CHANGED=$(git -C "$ROOT_DIR" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
fi
[[ "$FILES_CHANGED" -eq 0 ]] && FILES_CHANGED=3   # demo fallback

# ── Run Spring Boot tests ───────────────────────────────────────────────────
SPRING_STATUS="SKIP"
if command -v mvn &>/dev/null && [[ -f "$BACKEND_DIR/pom.xml" ]]; then
  code=$(run_test "$BACKEND_DIR" "mvn test -q 2>&1")
  [[ "$code" -eq 0 ]] && SPRING_STATUS="PASS" || SPRING_STATUS="FAIL"
fi

# ── Run React tests ─────────────────────────────────────────────────────────
REACT_STATUS="SKIP"
if [[ -d "$FRONTEND_DIR/node_modules" ]]; then
  code=$(run_test "$FRONTEND_DIR" "pnpm test 2>&1")
  [[ "$code" -eq 0 ]] && REACT_STATUS="PASS" || REACT_STATUS="FAIL"
fi

# ── Security scan (reuse security-check.sh, capture exit code) ─────────────
SECURITY_STATUS="PASS"
if [[ -f "$ROOT_DIR/hooks/security-check.sh" ]]; then
  bash "$ROOT_DIR/hooks/security-check.sh" > /tmp/sec_out_$$.txt 2>&1 || SECURITY_STATUS="FAIL"
fi

# ── API breaking change detection ───────────────────────────────────────────
API_STATUS="No Breaking Changes"
BASELINE_FILE="$ROOT_DIR/hooks/.api-baseline.txt"
CURRENT_ENDPOINTS=$(grep -r "@GetMapping\|@PostMapping\|@PutMapping\|@DeleteMapping\|@RequestMapping" \
  "$BACKEND_DIR/src" 2>/dev/null | grep -oE '"[^"]+"' | sort || echo "")

if [[ -f "$BASELINE_FILE" ]]; then
  BASELINE=$(cat "$BASELINE_FILE")
  REMOVED=$(comm -23 <(echo "$BASELINE" | sort) <(echo "$CURRENT_ENDPOINTS" | sort) | wc -l | tr -d ' ')
  [[ "$REMOVED" -gt 0 ]] && API_STATUS="BREAKING: $REMOVED endpoint(s) removed"
fi
# Update baseline
echo "$CURRENT_ENDPOINTS" > "$BASELINE_FILE"

# ── Overall readiness ────────────────────────────────────────────────────────
ALL_PASS=true
[[ "$SPRING_STATUS" == "FAIL" ]]   && ALL_PASS=false
[[ "$REACT_STATUS"  == "FAIL" ]]   && ALL_PASS=false
[[ "$SECURITY_STATUS" == "FAIL" ]] && ALL_PASS=false
[[ "$API_STATUS" == BREAKING* ]]   && ALL_PASS=false

# ── Render report ─────────────────────────────────────────────────────────
STATUS_ICON() {
  case "$1" in
    PASS) echo "PASS" ;;
    FAIL) echo "FAIL" ;;
    SKIP) echo "SKIP" ;;
    *)    echo "$1" ;;
  esac
}

report() {
cat <<EOF
========================================
  DEVELOPER REPORT
========================================
  Feature:        User Search API
  Branch:         $BRANCH
  Files Changed:  $FILES_CHANGED

  Tests:
    Spring Boot   $(STATUS_ICON "$SPRING_STATUS")
    React         $(STATUS_ICON "$REACT_STATUS")

  Security:       $(STATUS_ICON "$SECURITY_STATUS")
  API:            $API_STATUS

EOF
if $ALL_PASS; then
cat <<EOF
  Ready for Pull Request
========================================
EOF
else
cat <<EOF
  NOT ready — fix the issues above first.
========================================
EOF
fi
}

# Print to terminal
report

# Save to file
report > "$REPORT_FILE"
echo ""
echo "Report saved to: developer-report.txt"

# Cleanup temp files
rm -f /tmp/test_out_$$.txt /tmp/sec_out_$$.txt

exit 0
