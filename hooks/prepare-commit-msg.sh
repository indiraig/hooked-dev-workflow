#!/usr/bin/env bash
# =============================================================================
# hooks/prepare-commit-msg.sh  —  Git prepare-commit-msg hook
#
# Auto-generates a meaningful, conventional-commit-style message based on
# what files are staged.
#
# Usage (installed as git hook):
#   .git/hooks/prepare-commit-msg  <commit-msg-file> <source> <sha>
#
# Only runs when there is no existing message (i.e., not amend/merge/squash).
# =============================================================================
set -uo pipefail

COMMIT_MSG_FILE="${1:-}"
COMMIT_SOURCE="${2:-}"

# Don't overwrite amend, merge, squash, or fixup messages
[[ "$COMMIT_SOURCE" =~ ^(commit|merge|squash|message)$ ]] && exit 0
[[ -z "$COMMIT_MSG_FILE" ]] && exit 0

# ── Gather staged file info ─────────────────────────────────────────────────
STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
[[ -z "$STAGED" ]] && exit 0

# ── Count file categories ───────────────────────────────────────────────────
JAVA_FILES=$(echo "$STAGED"  | grep -c '\.java$'            || true)
JSX_FILES=$(echo "$STAGED"   | grep -cE '\.(jsx|tsx|js|ts)$' || true)
TEST_FILES=$(echo "$STAGED"  | grep -cE 'Test|\.test\.|\.spec\.' || true)
CSS_FILES=$(echo "$STAGED"   | grep -cE '\.(css|scss|less)$' || true)
CONFIG_FILES=$(echo "$STAGED" | grep -cE '\.(json|yml|yaml|xml|properties|env)$' || true)
DOC_FILES=$(echo "$STAGED"   | grep -cE '\.(md|txt|rst)$'   || true)
HOOK_FILES=$(echo "$STAGED"  | grep -c 'hooks/'              || true)
TOTAL=$(echo "$STAGED" | wc -l | tr -d ' ')

# ── Determine commit type ───────────────────────────────────────────────────
TYPE="chore"
SCOPE=""
DESCRIPTION=""

if [[ $TEST_FILES -gt 0 && $((JAVA_FILES + JSX_FILES)) -eq 0 ]]; then
  TYPE="test"
elif [[ $DOC_FILES -gt 0 && $TOTAL -eq $DOC_FILES ]]; then
  TYPE="docs"
elif [[ $CONFIG_FILES -gt 0 && $TOTAL -eq $CONFIG_FILES ]]; then
  TYPE="config"
elif [[ $HOOK_FILES -gt 0 ]]; then
  TYPE="ci"
  SCOPE="hooks"
elif [[ $CSS_FILES -gt 0 && $JSX_FILES -eq 0 && $JAVA_FILES -eq 0 ]]; then
  TYPE="style"
elif [[ $JAVA_FILES -gt 0 && $TEST_FILES -gt 0 ]]; then
  TYPE="feat"
  SCOPE="backend"
elif [[ $JAVA_FILES -gt 0 ]]; then
  TYPE="feat"
  SCOPE="backend"
elif [[ $JSX_FILES -gt 0 && $TEST_FILES -gt 0 ]]; then
  TYPE="feat"
  SCOPE="frontend"
elif [[ $JSX_FILES -gt 0 ]]; then
  TYPE="feat"
  SCOPE="frontend"
fi

# ── Infer description from changed file names ───────────────────────────────
# Find the most significant changed file
MAIN_FILE=$(echo "$STAGED" | grep -vE 'test|Test|spec|Spec' | head -1 || echo "$STAGED" | head -1)
BASENAME=$(basename "$MAIN_FILE" 2>/dev/null | sed 's/\.[^.]*$//' || echo "")

# Convert CamelCase / kebab-case to words
WORDS=$(echo "$BASENAME" | sed 's/\([A-Z]\)/ \1/g' | tr '-_' '  ' | \
        tr '[:upper:]' '[:lower:]' | xargs)

if [[ -n "$WORDS" && "$WORDS" != "." ]]; then
  DESCRIPTION="update $WORDS"
else
  DESCRIPTION="update $TOTAL file(s)"
fi

# ── Special pattern overrides ───────────────────────────────────────────────
if echo "$STAGED" | grep -q "Controller"; then
  DESCRIPTION=$(echo "$STAGED" | grep "Controller" | head -1 | \
                xargs basename | sed 's/Controller\.java//' | \
                sed 's/\([A-Z]\)/ \1/g' | tr '[:upper:]' '[:lower:]' | xargs)
  DESCRIPTION="add ${DESCRIPTION} controller endpoints"
fi
if echo "$STAGED" | grep -q "Service"; then
  SVC=$(echo "$STAGED" | grep "Service" | head -1 | \
        xargs basename | sed 's/Service\.java//' | \
        sed 's/\([A-Z]\)/ \1/g' | tr '[:upper:]' '[:lower:]' | xargs)
  DESCRIPTION="implement ${SVC} service logic"
fi
if echo "$STAGED" | grep -q "Repository"; then
  DESCRIPTION="add repository layer"
fi
if echo "$STAGED" | grep -q "pom.xml"; then
  DESCRIPTION="update Maven dependencies"
fi
if echo "$STAGED" | grep -qE "package.json|pnpm-lock"; then
  DESCRIPTION="update npm dependencies"
fi
if echo "$STAGED" | grep -q "Dockerfile"; then
  DESCRIPTION="update Docker configuration"
fi

# ── Build the commit message ─────────────────────────────────────────────────
if [[ -n "$SCOPE" ]]; then
  HEADER="${TYPE}(${SCOPE}): ${DESCRIPTION}"
else
  HEADER="${TYPE}: ${DESCRIPTION}"
fi

# ── List changed files in body ───────────────────────────────────────────────
BODY="Changed files ($TOTAL):"$'\n'
while IFS= read -r f; do
  STATUS=$(git diff --cached --name-status "$f" 2>/dev/null | cut -f1 || echo "M")
  case "$STATUS" in
    A*) LABEL="added"    ;;
    D*) LABEL="deleted"  ;;
    R*) LABEL="renamed"  ;;
    *)  LABEL="modified" ;;
  esac
  BODY+="  - $f ($LABEL)"$'\n'
done <<< "$STAGED"

# ── Write to commit message file ─────────────────────────────────────────────
{
  echo "$HEADER"
  echo ""
  echo "$BODY"
  echo ""
  echo "# AI-Hooks-Demo — auto-generated commit message"
  echo "# Edit this message as needed before saving."
} > "$COMMIT_MSG_FILE"
