#!/usr/bin/env bash
# =============================================================================
# hooks/pre-commit.sh  —  Git pre-commit hook
#
# Runs automatically before EVERY git commit.
# Gates the commit on:
#   1. Coding standards (no debug code, no bad patterns)
#   2. Security scan   (secrets, injections, unsafe config)
#
# Exit 0 → commit proceeds
# Exit 1 → commit BLOCKED (developer must fix issues)
# =============================================================================
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}[PASS]${RESET} $*"; }
fail() { echo -e "${RED}[FAIL]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
info() { echo -e "${CYAN}[HOOK]${RESET} $*"; }
sep()  { echo -e "${BOLD}──────────────────────────────────────────${RESET}"; }

echo ""
sep
echo -e "${BOLD}  PRE-COMMIT GATE${RESET}"
sep

# ── Get staged files ────────────────────────────────────────────────────────
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

if [[ -z "$STAGED_FILES" ]]; then
  ok "No staged files to check."
  sep; echo ""; exit 0
fi

info "Staged files:"
echo "$STAGED_FILES" | while read -r f; do echo "    → $f"; done
echo ""

ISSUES=0

# ══════════════════════════════════════════════════════════════════════════════
#  1. CODING STANDARDS CHECK
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}  1. CODING STANDARDS${RESET}"

declare -A STANDARDS
# Pattern : Human-readable label
STANDARDS['console\.log\(']="console.log() left in code (use a logger)"
STANDARDS['System\.out\.print']="System.out.print() left in code (use SLF4J)"
STANDARDS['\.printStackTrace\(\)']="printStackTrace() — use logger instead"
STANDARDS['TODO|FIXME|HACK|XXX']="Unresolved TODO/FIXME/HACK in staged code"
STANDARDS['debugger;']="debugger statement left in JS/TS code"
STANDARDS['\bvar\b']="var used in JS — prefer const/let"

for pattern in "${!STANDARDS[@]}"; do
  label="${STANDARDS[$pattern]}"
  matches=$(echo "$STAGED_FILES" | xargs -I{} git show "::{}" 2>/dev/null | \
            grep -nE "$pattern" 2>/dev/null | head -3 || true)
  if [[ -n "$matches" ]]; then
    warn "$label"
    echo "$matches" | while read -r m; do echo "       $m"; done
    ISSUES=$((ISSUES + 1))
  fi
done

[[ $ISSUES -eq 0 ]] && ok "Coding standards PASSED"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
#  2. SECURITY SCAN
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}  2. SECURITY SCAN${RESET}"

SEC_ISSUES=0

declare -A SECURITY
SECURITY['password\s*=\s*["\x27][^"\x27${}][^"\x27]*["\x27]']="Hardcoded password detected"
SECURITY['(api_key|apikey|secret_key|access_token)\s*=\s*["\x27][A-Za-z0-9+/]{8,}']="Hardcoded API key / secret"
SECURITY['(AKIA|AIza|sk-)[A-Za-z0-9]{20,}']="Looks like a real cloud/AI API key"
SECURITY['executeQuery\(.*\+|createQuery\(.*\+']="Potential SQL injection — string concat in query"
SECURITY['innerHTML\s*=']="innerHTML assignment — potential XSS"
SECURITY['eval\(']="eval() usage — dangerous"
SECURITY['csrf\(\)\.disable\(\)|csrf\.disable']="CSRF protection disabled"
SECURITY['\.anyRequest\(\)\.permitAll\(\)']="permitAll on all requests — review security config"
SECURITY['allowCredentials\(true\).*allowedOrigins\("\*"\)']="CORS: credentials + wildcard origin is unsafe"

for pattern in "${!SECURITY[@]}"; do
  label="${SECURITY[$pattern]}"
  matches=$(echo "$STAGED_FILES" | xargs -I{} git show "::{}" 2>/dev/null | \
            grep -nEi "$pattern" 2>/dev/null | head -2 || true)
  if [[ -n "$matches" ]]; then
    fail "$label"
    echo "$matches" | while read -r m; do echo "       $m"; done
    SEC_ISSUES=$((SEC_ISSUES + 1))
    ISSUES=$((ISSUES + 1))
  fi
done

[[ $SEC_ISSUES -eq 0 ]] && ok "Security scan PASSED"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
#  RESULT
# ══════════════════════════════════════════════════════════════════════════════
sep
if [[ $ISSUES -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}  PRE-COMMIT PASSED — proceeding with commit${RESET}"
  sep; echo ""
  exit 0
else
  echo -e "${RED}${BOLD}  COMMIT BLOCKED — $ISSUES issue(s) must be fixed${RESET}"
  echo ""
  echo "  To bypass (not recommended):"
  echo "    git commit --no-verify"
  sep; echo ""
  exit 1
fi
