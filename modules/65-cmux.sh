#!/usr/bin/env bash
# modules/65-cmux.sh - give cmux the tmux keymap, and make its mouse selection
# copy the way tmux's and herdr's do.
#
# Numbered after 60-desktop.sh, not next to 20-tmux.sh, even though cmux is a
# multiplexer: cmux is a Homebrew *cask* listed in packages/brew-cask.txt, so
# 60-desktop.sh's install_casks is what puts it on the machine, and module
# order is the only dependency mechanism this installer has. This module needs
# the `cmux` CLI that the cask ships in order to validate and reload what it
# writes.
#
# cmux does not replace tmux or herdr and nothing here touches either. What it
# does share with them is the <C-b> prefix - see docs/cmux-shortcut.md for the
# full map and for what that prefix costs.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

CMUX_CONFIG_DIR="$HOME/.config/cmux"
CMUX_CONFIG="$CMUX_CONFIG_DIR/cmux.json"

# ------------------------------------------------------------------
# The managed block: a JSONC fragment spliced into ~/.config/cmux/cmux.json
# between two markers.
#
# Why a splice and not a symlink or a seed:
#
#   - cmux owns that file. On first launch, when it is missing, cmux writes a
#     ~400-line JSONC template in which every setting appears commented out.
#     That template is the local documentation of the whole settings surface,
#     so replacing the file wholesale to write eight lines is a bad trade. A
#     symlink is worse: the app rewrites the file, which would mean it rewrites
#     a tracked file in a public checkout.
#
#   - Seeding once and never overwriting - the modules/52-herdr.sh pattern - is
#     exactly what must NOT happen here. docs/herdr-shortcut.md records what it
#     costs: a keymap in a seeded template reaches a *new* machine and never an
#     *existing* one, so every box ends up with a different map and no page is
#     right about all of them. This block is re-rendered on every run instead.
#
# A cmux action holds exactly ONE binding - the schema's shortcuts.bindings is
# a string or a two-stroke chord array, never a list of alternatives - so every
# chord below REPLACES that action's Cmd default. Cmd+T, Cmd+W, Cmd+N, Cmd+B,
# Cmd+[ and Cmd+] stop firing in cmux as a result. That is the deliberate
# trade: one keymap across tmux, herdr and cmux.
#
# Keys with no literal spelling are written as their shifted form, because the
# schema's key grammar accepts [A-Za-z0-9] and ,./\;'`=[]- and nothing else:
# '%' is shift+5, '"' is shift+', '$' is shift+4, '(' and ')' are shift+9 and
# shift+0. Check any edit with `cmux config doctor`, then press it - doctor
# validates JSONC syntax and lists top-level keys, and does not check that an
# action id exists or that two actions want the same chord. test/verify.sh does
# both of those.
# ------------------------------------------------------------------
cmux_managed_block() {
    cat <<'BLOCK'
  "shortcuts": {
    "bindings": {
      // Panes. cmux has no resize-by-direction action, so tmux's <prefix> H J
      // K L has nothing to point at and is left out rather than approximated;
      // equalizeSplits on '=' is the nearest thing and '=' is free in tmux.
      "splitRight": ["ctrl+b", "shift+5"],
      "splitDown": ["ctrl+b", "shift+'"],
      "focusLeft": ["ctrl+b", "h"],
      "focusDown": ["ctrl+b", "j"],
      "focusUp": ["ctrl+b", "k"],
      "focusRight": ["ctrl+b", "l"],
      // These two ship UNBOUND in cmux - the schema lists them and the
      // shortcut table notes "unbound by default" - so binding them overrides
      // nothing, the same argument that lets modules/52-herdr.sh bind herdr's
      // agent keys.
      "focusNextPane": ["ctrl+b", "o"],
      "focusPreviousPane": ["ctrl+b", ";"],
      "toggleSplitZoom": ["ctrl+b", "z"],
      "equalizeSplits": ["ctrl+b", "="],

      // Tabs. cmux nests one level deeper than tmux (window > workspace > pane
      // > surface), and a surface is the thing a tmux window maps onto: it is
      // what the digit row selects and what c/x create and destroy.
      "newSurface": ["ctrl+b", "c"],
      "closeTab": ["ctrl+b", "x"],
      "renameTab": ["ctrl+b", ","],
      // "1" names the 1..9 family here exactly as it does in the "cmd+1"
      // default cmux ships for this action; it is not a binding for the 1 key.
      "selectSurfaceByNumber": ["ctrl+b", "1"],
      // oh-my-tmux unbinds n and p and moves window switching to C-h / C-l, so
      // those are the keys the hands know. n and p are left free here for the
      // same reason they are free there: a stale habit should do nothing
      // rather than something.
      "prevSurface": ["ctrl+b", "ctrl+h"],
      "nextSurface": ["ctrl+b", "ctrl+l"],
      // tmux's last-window. Moving these off Cmd+[ / Cmd+] is a bonus rather
      // than a cost: cmux binds focus-back/forward to those by default, which
      // is what stops a terminal program inside cmux from ever seeing them.
      "focusHistoryBack": ["ctrl+b", "tab"],
      "focusHistoryForward": ["ctrl+b", "shift+tab"],

      // Workspaces - the tmux session axis. s is the picker, ( and ) step
      // through them, $ renames, C-c creates, exactly as in tmux.
      "goToWorkspace": ["ctrl+b", "s"],
      "commandPalette": ["ctrl+b", "w"],
      "prevSidebarTab": ["ctrl+b", "shift+9"],
      "nextSidebarTab": ["ctrl+b", "shift+0"],
      "renameWorkspace": ["ctrl+b", "shift+4"],
      "newTab": ["ctrl+b", "ctrl+c"],
      // closeWorkspace is deliberately absent: it stays on Cmd+Shift+W. tmux's
      // '&' kills a *window*, which in this map is closeTab above, and a
      // chord that destroys a whole workspace is not one to add by analogy.

      // b matches herdr's <prefix> b for the same sidebar-shaped thing.
      "toggleSidebar": ["ctrl+b", "b"],
      // The closest cmux has to tmux's copy-mode. The mouse half of this is
      // terminal.copyOnSelect below.
      "toggleTerminalCopyMode": ["ctrl+b", "["],
      // oh-my-tmux's <prefix> r. Reloads cmux.json and the Ghostty config.
      "reloadConfiguration": ["ctrl+b", "r"]
    }
  },
  "terminal": {
    // tmux gets this from `set -g mouse on` plus the MouseDragEnd1Pane unbind
    // in ~/.tmux.conf.local, and herdr gets it for free - copy_on_select is
    // true in `herdr --default-config`. cmux defaults it to false, which is
    // the one place the three tools disagree about the mouse.
    "copyOnSelect": true
  }
BLOCK
}

# ------------------------------------------------------------------
# Splice the block into cmux.json, or leave the file untouched if it already
# says exactly this. Idempotency is the whole point: re-running must not
# accumulate backups, must not disturb the app's commented template, and must
# not care whether this machine is new or has had the block for months.
# ------------------------------------------------------------------
configure_cmux() {
    log "Configuring $CMUX_CONFIG..."
    run mkdir -p "$CMUX_CONFIG_DIR"

    if [ "$DRY_RUN" = "1" ]; then
        run_sh "python3 - <<'PY' (splice the dotfiles-managed block into $CMUX_CONFIG)"
        return 0
    fi

    local rc=0
    CMUX_CONFIG_PATH="$CMUX_CONFIG" \
    CMUX_BLOCK="$(cmux_managed_block)" \
    CMUX_BACKUP="$CMUX_CONFIG.bak.$(_timestamp)" \
    python3 <<'PY' || rc=$?
import json, os, re, sys

path = os.environ["CMUX_CONFIG_PATH"]
block = os.environ["CMUX_BLOCK"]
backup = os.environ["CMUX_BACKUP"]

BEGIN = "  // >>> dotfiles-managed (modules/65-cmux.sh) - rewritten on every install"
END = "  // <<< dotfiles-managed"

# Exit codes the shell branches on: 0 wrote, 10 nothing to do, 20 refused.
WROTE, UNCHANGED, REFUSED = 0, 10, 20


def strip_jsonc(text):
    """Comments and trailing commas out, string literals left alone.

    Written by hand rather than pulled from a library because this module runs
    on a machine that may have nothing installed but python3 itself, and
    because the file being parsed is one cmux generates: ~400 lines of `//`
    comments around a couple of live keys.
    """
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == '"':
                    break
                j += 1
            out.append(text[i:j + 1])
            i = j + 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j == -1 else j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j == -1 else j + 2
        else:
            out.append(c)
            i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


managed = BEGIN + "\n" + block + "\n" + END

original = ""
if os.path.isfile(path):
    with open(path) as fh:
        original = fh.read()

# A file cmux has never written. Create the minimum it needs; cmux only
# generates its commented template when the file is ABSENT, so writing one
# here means this machine never gets that template - hence the pointer.
if not original.strip():
    body = (
        "{\n"
        '  "$schema": "https://raw.githubusercontent.com/manaflow-ai/cmux/main/'
        'web/data/cmux.schema.json",\n'
        '  "schemaVersion": 1,\n\n'
        "  // Created by dotfiles/modules/65-cmux.sh before cmux first ran, so the\n"
        "  // commented template cmux writes for a missing file is not here.\n"
        "  // `cmux docs settings` prints the schema URL; `cmux settings` opens the UI.\n\n"
        + managed + "\n}\n"
    )
    with open(path, "w") as fh:
        fh.write(body)
    print("  created %s with the managed block" % path)
    sys.exit(WROTE)

start = original.find(BEGIN)
end = original.find(END)
if (start == -1) != (end == -1) or (start != -1 and end < start):
    print("  managed markers in %s are damaged (only one, or out of order)" % path)
    sys.exit(REFUSED)

if start != -1:
    before, after = original[:start], original[end + len(END):]
else:
    before, after = None, None

# Refuse rather than write a duplicate key. Two "terminal" keys is the
# silent-wrong-answer case: the file still parses and one of the two loses.
outside = (before + after) if start != -1 else original
try:
    data = json.loads(strip_jsonc(outside))
except ValueError as exc:
    print("  %s is not valid JSONC outside the managed block (%s)" % (path, exc))
    print("  leaving it alone; fix it or delete it and re-run")
    sys.exit(REFUSED)

clashes = [k for k in ("shortcuts", "terminal") if k in data]
if clashes:
    print("  %s already sets %s outside the managed block."
          % (path, " and ".join(clashes)))
    print("  Remove or comment those keys out and re-run; two of the same key")
    print("  would parse fine and silently drop one of them. Per-machine values")
    print("  belong in cmux's own Settings UI (`cmux settings`), which this file")
    print("  overrides key by key - not in a second copy of the key here.")
    sys.exit(REFUSED)

if start != -1:
    updated = before + managed + after
else:
    # Splice before the closing brace, so the block wins over any key a later
    # edit uncomments above it, and so the app's template survives byte for
    # byte. The character it lands after decides whether a comma is needed:
    # cmux's own template ends "schemaVersion": 1, with the comma already
    # there, but a hand-edited file may not.
    close = original.rfind("}")
    if close == -1:
        print("  %s has no closing brace; leaving it alone" % path)
        sys.exit(REFUSED)
    head, tail = original[:close], original[close:]
    live = strip_jsonc(head).rstrip()
    sep = "" if live.endswith(("{", ",")) else ","
    updated = head.rstrip() + sep + "\n\n" + managed + "\n" + tail

if updated == original:
    print("  already up to date")
    sys.exit(UNCHANGED)

os.rename(path, backup)
with open(path, "w") as fh:
    fh.write(updated)
print("  managed block written (previous file kept as %s)" % os.path.basename(backup))
sys.exit(WROTE)
PY

    case "$rc" in
        0)  cmux_validate ;;
        10) skip "$CMUX_CONFIG already up to date" ; return 10 ;;
        *)  warn "cmux config left unchanged; see the message above." ; return 1 ;;
    esac
}

# ------------------------------------------------------------------
# Ask cmux whether it can still read what we just wrote, and put the file back
# if it cannot. `cmux config doctor` reports "JSONC syntax is valid" and lists
# the top-level keys it found - which is all it does, so a wrong action id or a
# chord two actions both want passes here and is caught in test/verify.sh
# instead.
# ------------------------------------------------------------------
cmux_validate() {
    have cmux || return 0

    if cmux config doctor 2>/dev/null | grep -q 'JSONC syntax is valid'; then
        step "cmux config doctor: JSONC syntax is valid"
        return 0
    fi

    warn "cmux rejected the config this module just wrote. Restoring the backup."
    local newest
    newest="$(ls -1t "$CMUX_CONFIG".bak.* 2>/dev/null | head -1 || true)"
    if [ -n "$newest" ]; then
        mv "$newest" "$CMUX_CONFIG"
        warn "  restored $CMUX_CONFIG from $(basename "$newest")"
    fi
    return 1
}

# Apply it to a running app, the same way modules/20-tmux.sh re-sources a live
# tmux server. `cmux ping` answers PONG over the Unix socket only when the app
# is up, so this is also the "is it running" test; reload-config reloads
# cmux.json and the Ghostty config and refreshes terminals in place.
reload_cmux() {
    [ "$DRY_RUN" = "1" ] && return 0
    have cmux || return 0

    if ! cmux ping >/dev/null 2>&1; then
        skip "cmux is not running; the new keymap applies at next launch"
        return 0
    fi

    log "Reloading the running cmux..."
    cmux reload-config >/dev/null 2>&1 \
        || warn "cmux reload-config failed; quit and reopen cmux to pick up the keymap."
}

main() {
    if [ "$MINIMAL" = "1" ]; then
        skip "--minimal: skipping cmux"
        return 0
    fi

    # cmux is a macOS app. Unlike the Ghostty config, which deploys everywhere
    # because Ghostty reads the XDG path on every platform, there is nothing on
    # a Linux box for this file to configure.
    if ! is_macos; then
        skip "cmux is macOS-only; skipping"
        return 0
    fi

    # Guarded on DRY_RUN for the reason spelled out in modules/52-herdr.sh: a
    # dry run installs nothing, so a bare `have` reports a missing binary on
    # every dry run against a machine without cmux and makes a working module
    # look broken.
    if [ "$DRY_RUN" != "1" ] && ! have cmux; then
        warn "cmux not found; skipping its keymap."
        warn "  It comes from packages/brew-cask.txt via './install.sh --only desktop'."
        return 0
    fi

    # 10 is configure_cmux's "nothing to do", which is a success, not a failure.
    local rc=0
    configure_cmux || rc=$?
    [ "$rc" = "0" ] || [ "$rc" = "10" ] || return "$rc"

    [ "$rc" = "0" ] && reload_cmux
    return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
