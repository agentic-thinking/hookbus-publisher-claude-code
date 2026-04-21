#!/usr/bin/env bash
# hookbus-publisher-claude-code — one-shot installer.
#
# Drops `claude-code-gate` to ~/.local/bin and prints a ready-to-paste
# snippet for ~/.claude/settings.json. Does NOT modify settings.json
# for you — you paste the snippet yourself to keep the install reversible.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/bin/claude-code-gate"
BIN_DIR="$HOME/.local/bin"
DST="$BIN_DIR/claude-code-gate"

say()  { printf "\033[1;32m[claude-code-publisher]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[claude-code-publisher]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[claude-code-publisher] error:\033[0m %s\n" "$*"; exit 1; }

[ -f "$SRC" ] || die "Source binary not found at $SRC. Run this from the repo root."

mkdir -p "$BIN_DIR"
install -Dm755 "$SRC" "$DST"
say "installed $DST"

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) warn "$BIN_DIR is not on PATH. Add this to your shell profile:"
       echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

TOKEN="${HOOKBUS_TOKEN:-YOUR_TOKEN_HERE}"
BUS_URL="${HOOKBUS_URL:-http://localhost:18800/event}"

cat <<EOF

────────────────────────────────────────────────────────────────
Paste this into your ~/.claude/settings.json (merge with existing
hooks if you already have some):
────────────────────────────────────────────────────────────────

{
  "hooks": {
    "UserPromptSubmit": [{ "matcher": "", "hooks": [{ "type": "command", "command": "env HOOKBUS_URL=$BUS_URL HOOKBUS_TOKEN=$TOKEN $DST" }] }],
    "PreToolUse":       [{ "matcher": "", "hooks": [{ "type": "command", "command": "env HOOKBUS_URL=$BUS_URL HOOKBUS_TOKEN=$TOKEN $DST" }] }],
    "PostToolUse":      [{ "matcher": "", "hooks": [{ "type": "command", "command": "env HOOKBUS_URL=$BUS_URL HOOKBUS_TOKEN=$TOKEN $DST" }] }],
    "Stop":             [{ "matcher": "", "hooks": [{ "type": "command", "command": "env HOOKBUS_URL=$BUS_URL HOOKBUS_TOKEN=$TOKEN $DST" }] }]
  }
}

────────────────────────────────────────────────────────────────

Get the bearer token from the bus container if you haven't already:

  docker exec hookbus cat /root/.hookbus/.token

Then restart your Claude Code session so settings.json is reloaded.
EOF
