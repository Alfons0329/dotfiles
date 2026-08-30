#!/usr/bin/env bash
# modules/50-claude.sh - Claude Code, ccstatusline, and a completion notifier.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

CLAUDE_DIR="$HOME/.claude"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
NOTIFY_SCRIPT="$HOME/.local/bin/claude-notify.sh"

install_claude_code() {
    if have claude; then
        skip "Claude Code already installed"
        return 0
    fi

    log "Installing Claude Code..."
    if is_macos && have brew; then
        run brew install --cask claude && return 0
        warn "Homebrew cask install failed; trying the official installer."
    fi

    # Official installer first: it manages its own updates and needs no Node.
    if run_sh "curl $CURL_OPTS https://claude.ai/install.sh | bash"; then
        return 0
    fi

    warn "Official installer failed; falling back to npm."
    if have npm; then
        run npm install -g @anthropic-ai/claude-code \
            || warn "npm install of Claude Code failed."
    else
        warn "Neither installer worked and npm is unavailable; skipping Claude Code."
    fi
}

install_ccstatusline() {
    if ! have npm; then
        warn "npm not found; skipping ccstatusline."
        return 0
    fi
    log "Installing ccstatusline..."
    # On Linux, Node comes from NodeSource's apt package, whose global prefix
    # (/usr/lib/node_modules) is root-owned - `npm install -g` as the normal
    # user fails EACCES (verified: this was silently broken until a presence
    # check was added). Homebrew's Node on macOS is user-owned, so sudo there
    # would instead leave root-owned files in a brew-managed directory.
    if is_macos; then
        run npm install -g ccstatusline || warn "ccstatusline install failed."
    else
        as_root npm install -g ccstatusline || warn "ccstatusline install failed."
    fi
}

# ------------------------------------------------------------------
# Completion notifier.
#
# Claude Code fires a Stop hook when a turn ends. This surfaces that as a
# desktop notification, picking the mechanism that actually works on the
# machine it lands on:
#   macOS            -> Notification Center via osascript
#   Linux with a GUI -> notify-send
#   Linux VM / SSH   -> OSC 9, which the terminal emulator forwards to the host
# ------------------------------------------------------------------
install_notifier() {
    log "Installing the Claude Code completion notifier..."
    run mkdir -p "$(dirname "$NOTIFY_SCRIPT")"

    if [ "$DRY_RUN" = "1" ]; then
        run_sh "write $NOTIFY_SCRIPT"
    else
        cat > "$NOTIFY_SCRIPT" <<'NOTIFY_EOF'
#!/usr/bin/env bash
# Claude Code Stop hook: announce that a turn has finished.
# Installed by dotfiles/modules/50-claude.sh.

input="$(cat)"

read -r title body <<<"$(
    printf '%s' "$input" | python3 -c '
import json, os, sys

def last_assistant_text(path):
    if not path or not os.path.isfile(path):
        return ""
    text = ""
    with open(path, errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if entry.get("type") == "assistant" or entry.get("role") == "assistant":
                for block in entry.get("content", []) or []:
                    if isinstance(block, dict) and block.get("type") == "text":
                        stripped = block.get("text", "").strip()
                        if stripped:
                            text = stripped
    return text

try:
    data = json.load(sys.stdin)
except Exception:
    print("Claude Task complete")
    sys.exit(0)

session = data.get("session_name") or (data.get("session_id") or "")[:8] or "Claude"
summary = last_assistant_text(data.get("transcript_path", ""))
summary = summary.split("\n")[0][:80] if summary else "Task complete"
# Single line, two fields: the shell splits on the first space.
print(session.replace(" ", "_"), summary)
' 2>/dev/null
)"

title="${title:-Claude} finished"
body="${body:-Task complete}"

case "$(uname -s)" in
    Darwin)
        osascript -e "display notification \"${body//\"/}\" with title \"${title//\"/}\" sound name \"Glass\"" 2>/dev/null || true
        ;;
    Linux)
        printf '\a'
        # systemd-detect-virt says "none" on bare metal; anything else means we
        # are in a VM or container, where a local desktop notification has
        # nowhere to appear and OSC 9 to the terminal is the working channel.
        if [ "$(systemd-detect-virt 2>/dev/null || echo unknown)" = "none" ] \
           && command -v notify-send >/dev/null 2>&1; then
            notify-send "$title" "$body" 2>/dev/null || true
        else
            printf '\033]9;%s: %s\033\\' "$title" "$body"
        fi
        ;;
esac
NOTIFY_EOF
        chmod +x "$NOTIFY_SCRIPT"
    fi
}

# ------------------------------------------------------------------
# Wire both the statusline and the Stop hook into settings.json.
#
# One pass, not two: settings.json may not exist yet, and a second pass that
# reads it before the first has created it silently does nothing.
# ------------------------------------------------------------------
configure_claude_settings() {
    log "Configuring ~/.claude/settings.json..."
    run mkdir -p "$CLAUDE_DIR"

    if [ "$DRY_RUN" = "1" ]; then
        run_sh "python3 - <<'PY' (merge statusLine + Stop hook into $CLAUDE_SETTINGS)"
        return 0
    fi

    SETTINGS_PATH="$CLAUDE_SETTINGS" NOTIFY_PATH="$NOTIFY_SCRIPT" python3 <<'PY'
import json, os, sys

path = os.environ["SETTINGS_PATH"]
notify = os.environ["NOTIFY_PATH"]

# Preserve whatever is already there; this file is user-owned and may hold
# permissions, MCP servers, and other settings we must not drop.
data = {}
if os.path.isfile(path):
    try:
        with open(path) as fh:
            data = json.load(fh)
    except ValueError:
        backup = path + ".corrupt"
        os.rename(path, backup)
        print(f"  existing settings.json was not valid JSON; moved to {backup}")

data["statusLine"] = {
    "type": "command",
    "command": "ccstatusline",
    "refreshInterval": 10,
}

command = f'bash "{notify}"'
hooks = data.setdefault("hooks", {})
stop = hooks.setdefault("Stop", [])

def already_wired(entries):
    for entry in entries:
        for hook in entry.get("hooks", []) or []:
            if "claude-notify" in hook.get("command", ""):
                return True
    return False

if not already_wired(stop):
    for entry in stop:
        if entry.get("matcher", "") == "":
            entry.setdefault("hooks", []).append({"type": "command", "command": command})
            break
    else:
        stop.append({"matcher": "", "hooks": [{"type": "command", "command": command}]})

with open(path, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")

print("  statusLine + Stop hook configured")
PY
}

main() {
    install_claude_code
    install_ccstatusline
    install_notifier
    configure_claude_settings
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
