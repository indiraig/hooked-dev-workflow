#!/usr/bin/env bash
# =============================================================================
# security-check.sh  —  PostToolUse hook
# Scans changed files for common security anti-patterns.
# Exit 0  → clean
# Exit 1  → issues found (AI must address them)
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS="[PASS]"
FAIL="[FAIL]"
WARN="[WARN]"
INFO="[INFO]"

echo ""
echo "============================================="
echo "  SECURITY CHECK — AI Hooks Demo"
echo "============================================="

CHANGED_FILE="${OPENCODE_TOOL_INPUT_PATH:-}"
ISSUES=0

# ── Determine which files to scan ─────────────────────────────────────────
if [[ -n "$CHANGED_FILE" && -f "$CHANGED_FILE" ]]; then
  FILES_TO_SCAN=("$CHANGED_FILE")
else
  # Fall back: scan all source files tracked by git (or all src files)
  if command -v git &>/dev/null && git -C "$ROOT_DIR" rev-parse --git-dir &>/dev/null; then
    mapfile -t FILES_TO_SCAN < <(git -C "$ROOT_DIR" diff --name-only HEAD 2>/dev/null | \
      grep -E '\.(java|js|jsx|ts|tsx|properties|yml|yaml|env)$' | \
      sed "s|^|$ROOT_DIR/|" || true)
  else
    mapfile -t FILES_TO_SCAN < <(find "$ROOT_DIR/backend/src" "$ROOT_DIR/frontend/src" \
      -type f \( -name "*.java" -o -name "*.jsx" -o -name "*.js" \) 2>/dev/null || true)
  fi
fi

if [[ ${#FILES_TO_SCAN[@]} -eq 0 ]]; then
  echo "$INFO No files to scan."
  echo "============================================="
  echo "  SECURITY RESULT: PASS (nothing to scan)"
  echo "============================================="
  exit 0
fi

echo "$INFO Scanning ${#FILES_TO_SCAN[@]} file(s)..."

# ── Define patterns ────────────────────────────────────────────────────────
declare -A PATTERNS
PATTERNS["Hardcoded password"]='password\s*=\s*["'"'"'][^"'"'"'${}][^"'"'"']*["'"'"']'
PATTERNS["Hardcoded secret/token"]='(secret|token|api_key|apikey)\s*=\s*["'"'"'][A-Za-z0-9+/]{8,}["'"'"']'
PATTERNS["SQL string concatenation"]='\"SELECT.*\+|executeQuery\(.*\+'
PATTERNS["System.exit() call"]='System\.exit\('
PATTERNS["TODO / FIXME security note"]='(TODO|FIXME).*(auth|sql|xss|inject|secret|password)'
PATTERNS["Console.log with sensitive data"]='console\.log\(.*password|console\.log\(.*token'
PATTERNS["Disabled CSRF protection"]='csrf\(\)\.disable\(\)|csrf\.disable'
PATTERNS["permitAll on everything"]='\.anyRequest\(\)\.permitAll\(\)'

for file in "${FILES_TO_SCAN[@]}"; do
  [[ ! -f "$file" ]] && continue
  rel_file="${file#$ROOT_DIR/}"

  for label in "${!PATTERNS[@]}"; do
    pattern="${PATTERNS[$label]}"
    if grep -qiE "$pattern" "$file" 2>/dev/null; then
      lineno=$(grep -niE "$pattern" "$file" | head -1 | cut -d: -f1)
      echo "$FAIL $label detected"
      echo "     File : $rel_file (line ~$lineno)"
      ISSUES=$((ISSUES + 1))
    fi
  done
done

echo ""
echo "============================================="
if [[ $ISSUES -eq 0 ]]; then
  echo "  SECURITY RESULT: PASS — no issues found"
else
  echo "  SECURITY RESULT: FAIL — $ISSUES issue(s) found"
  echo "  Review and resolve the issues listed above."
fi
echo "============================================="

[[ $ISSUES -eq 0 ]] && exit 0 || exit 1
