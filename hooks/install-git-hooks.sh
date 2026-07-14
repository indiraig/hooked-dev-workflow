#!/usr/bin/env bash
# =============================================================================
# hooks/install-git-hooks.sh
#
# One-time setup — installs the Git hooks so they fire on every
# commit and push made in this repo.
#
# Run this ONCE after cloning:
#   bash hooks/install-git-hooks.sh
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GIT_HOOKS_DIR="$ROOT_DIR/.git/hooks"
HOOKS_SRC="$ROOT_DIR/hooks"

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}[OK]${RESET}    $*"; }
fail() { echo -e "${RED}[FAIL]${RESET}  $*"; }
info() { echo -e "${CYAN}[INFO]${RESET}  $*"; }
sep()  { echo -e "${BOLD}──────────────────────────────────────────${RESET}"; }

echo ""
sep
echo -e "${BOLD}  INSTALLING GIT HOOKS — ai-hooks-demo${RESET}"
sep
echo ""

# ── Check this is a git repo ─────────────────────────────────────────────────
if [[ ! -d "$ROOT_DIR/.git" ]]; then
  fail "Not a git repository. Run: git init"
  exit 1
fi

# ── Install pre-commit ───────────────────────────────────────────────────────
cat > "$GIT_HOOKS_DIR/pre-commit" <<'HOOK'
#!/usr/bin/env bash
ROOT="$(git rev-parse --show-toplevel)"
exec bash "$ROOT/hooks/pre-commit.sh"
HOOK
chmod +x "$GIT_HOOKS_DIR/pre-commit"
ok "pre-commit        → runs coding standards + security gate"

# ── Install prepare-commit-msg ───────────────────────────────────────────────
cat > "$GIT_HOOKS_DIR/prepare-commit-msg" <<'HOOK'
#!/usr/bin/env bash
ROOT="$(git rev-parse --show-toplevel)"
exec bash "$ROOT/hooks/prepare-commit-msg.sh" "$@"
HOOK
chmod +x "$GIT_HOOKS_DIR/prepare-commit-msg"
ok "prepare-commit-msg → auto-generates conventional commit message"

# ── Install pre-push ─────────────────────────────────────────────────────────
cat > "$GIT_HOOKS_DIR/pre-push" <<'HOOK'
#!/usr/bin/env bash
ROOT="$(git rev-parse --show-toplevel)"
exec bash "$ROOT/hooks/pre-push.sh"
HOOK
chmod +x "$GIT_HOOKS_DIR/pre-push"
ok "pre-push          → full test suite + PR summary + API contract"

# ── Make all hook scripts executable ─────────────────────────────────────────
echo ""
info "Making hook scripts executable..."
chmod +x "$HOOKS_SRC"/*.sh
ok "All hooks/  scripts are now executable"

echo ""
sep
echo -e "${GREEN}${BOLD}  SETUP COMPLETE${RESET}"
sep
echo ""
echo "  Git hooks installed:"
echo "    pre-commit          fires on: git commit"
echo "    prepare-commit-msg  fires on: git commit (auto message)"
echo "    pre-push            fires on: git push"
echo ""
echo "  OpenCode hooks (opencode.json):"
echo "    PostToolUse         fires on: AI approves file change"
echo "    Stop                fires on: AI session ends"
echo ""
echo "  To test a hook manually:"
echo "    bash hooks/post-tool-use.sh"
echo "    bash hooks/pre-commit.sh"
echo "    bash hooks/pre-push.sh"
echo "    bash hooks/notify-team.sh"
echo ""
echo "  Optional — enable team notifications:"
echo "    Create .env and add:"
echo "      SLACK_WEBHOOK_URL=https://hooks.slack.com/..."
echo "      TEAMS_WEBHOOK_URL=https://outlook.office.com/webhook/..."
sep
echo ""
