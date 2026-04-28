#!/usr/bin/env bash
# hookbus-publisher-claude-code — one-shot installer.
#
# Drops `claude-code-gate` to ~/.local/bin and merges HookBus hooks into
# ~/.claude/settings.json with a timestamped backup. Set
# HOOKBUS_CONFIGURE_CLAUDE=0 to print the snippet only.
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
PUBLISHER_ID="${HOOKBUS_PUBLISHER_ID:-uk.agenticthinking.publisher.anthropic.claude-code}"
HOOK_CMD="env HOOKBUS_URL=$BUS_URL HOOKBUS_TOKEN=$TOKEN HOOKBUS_SOURCE=claude-code HOOKBUS_PUBLISHER_ID=$PUBLISHER_ID"
for name in HOOKBUS_USER_ID HOOKBUS_ACCOUNT_ID HOOKBUS_INSTANCE_ID HOOKBUS_HOST_ID; do
  value="${!name:-}"
  if [ -n "$value" ]; then
    HOOK_CMD="$HOOK_CMD $name=$value"
  fi
done
HOOK_CMD="$HOOK_CMD $DST"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
CONFIGURE="${HOOKBUS_CONFIGURE_CLAUDE:-1}"

print_snippet() {
  cat <<EOF

────────────────────────────────────────────────────────────────
Claude Code HookBus hook configuration:
────────────────────────────────────────────────────────────────

{
  "hooks": {
    "UserPromptSubmit": [{ "matcher": "", "hooks": [{ "type": "command", "command": "$HOOK_CMD" }] }],
    "PreToolUse":       [{ "matcher": "", "hooks": [{ "type": "command", "command": "$HOOK_CMD" }] }],
    "PostToolUse":      [{ "matcher": "", "hooks": [{ "type": "command", "command": "$HOOK_CMD" }] }],
    "Stop":             [{ "matcher": "", "hooks": [{ "type": "command", "command": "$HOOK_CMD" }] }]
  }
}

────────────────────────────────────────────────────────────────
EOF
}

configure_claude_settings() {
  command -v python3 >/dev/null || {
    warn "python3 not found; cannot merge ~/.claude/settings.json automatically."
    print_snippet
    return 0
  }

  mkdir -p "$(dirname "$SETTINGS")"
  if [[ -f "$SETTINGS" ]]; then
    cp "$SETTINGS" "$SETTINGS.bak.hookbus-$(date +%Y%m%d-%H%M%S)"
  else
    printf '{}\n' > "$SETTINGS"
  fi

  SETTINGS_PATH="$SETTINGS" HOOKBUS_HOOK_COMMAND="$HOOK_CMD" python3 <<'PY'
import json
import os
import sys
from pathlib import Path

settings_path = Path(os.environ["SETTINGS_PATH"])
hook_command = os.environ["HOOKBUS_HOOK_COMMAND"]
events = ("UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop")

try:
    raw = settings_path.read_text(encoding="utf-8").strip()
    data = json.loads(raw) if raw else {}
except Exception as exc:
    print(f"settings parse failed: {exc}", file=sys.stderr)
    sys.exit(2)

if not isinstance(data, dict):
    print("settings root must be a JSON object", file=sys.stderr)
    sys.exit(2)

hooks = data.setdefault("hooks", {})
if not isinstance(hooks, dict):
    print("settings.hooks must be a JSON object", file=sys.stderr)
    sys.exit(2)

for event in events:
    entries = hooks.get(event)
    if not isinstance(entries, list):
        entries = []

    kept = []
    for entry in entries:
        if not isinstance(entry, dict):
            kept.append(entry)
            continue
        commands = entry.get("hooks")
        if not isinstance(commands, list):
            kept.append(entry)
            continue
        filtered = [
            command
            for command in commands
            if not (
                isinstance(command, dict)
                and command.get("type") == "command"
                and "claude-code-gate" in str(command.get("command", ""))
            )
        ]
        if filtered:
            replacement = dict(entry)
            replacement["hooks"] = filtered
            kept.append(replacement)

    matcher = "" if event in {"UserPromptSubmit", "Stop"} else ".*"
    kept.append({
        "matcher": matcher,
        "hooks": [{"type": "command", "command": hook_command}],
    })
    hooks[event] = kept

tmp_path = settings_path.with_suffix(settings_path.suffix + ".tmp")
tmp_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
tmp_path.replace(settings_path)
PY

  chmod 600 "$SETTINGS"
  say "updated $SETTINGS with HookBus hooks"
}

if [[ "$CONFIGURE" = "0" || "$CONFIGURE" = "false" || "$CONFIGURE" = "no" ]]; then
  print_snippet
else
  configure_claude_settings || {
    warn "Automatic settings merge failed. Printing manual snippet instead."
    print_snippet
  }
fi

cat <<EOF

Get the bearer token from the bus container if you haven't already:

  source ~/hookbus-light/.env

Or from the Compose install directory:

  cd ~/hookbus-light && docker compose exec -T hookbus cat /root/.hookbus/.token

Then restart your Claude Code session so settings.json is reloaded.
EOF
