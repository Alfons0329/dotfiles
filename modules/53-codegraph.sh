#!/usr/bin/env bash
# modules/53-codegraph.sh - codegraph, a pre-indexed code graph for agents.
#
# Numbered after 50-claude.sh, not next to the other CLI tools in 40-tools.sh,
# because `codegraph install` wires an MCP server into Claude Code and needs it
# on the box already. Module order is the only dependency mechanism this
# installer has - same reason 52-herdr.sh sits where it does.
#
# What this module does NOT do is index anything. The vendor installer wires
# agents only; building a project's graph is `codegraph init` inside that repo,
# which stays manual on purpose: it writes a .codegraph/ directory into the
# checkout and starts a file-watching daemon, and neither of those belongs to a
# machine-setup script that runs before any repo has been cloned.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

CLAUDE_JSON="$HOME/.claude.json"

install_codegraph() {
    if have codegraph; then
        skip "codegraph already installed ($(codegraph --version 2>/dev/null || echo version unknown))"
        return 0
    fi

    log "Installing codegraph..."

    # No Homebrew formula exists, so the vendor installer is the same path on
    # both platforms. It is a POSIX sh script needing only curl and tar, it
    # installs to ${CODEGRAPH_BIN_DIR:-$HOME/.local/bin} - which ~/.zshrc
    # already puts first on $PATH - and it modifies no rc files and prompts for
    # nothing. The bundle ships its own Node runtime, so this does not depend on
    # 40-tools.sh having installed Node.
    #
    # One difference from herdr worth knowing before trusting it: herdr's
    # installer verifies the download against a SHA-256 in its published
    # manifest, and this one performs no checksum verification at all. That is
    # a deliberate trust decision, so it is recorded next to the pipe rather
    # than left to be discovered by whoever reads this next.
    if ! run_sh "curl $CURL_OPTS https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh"; then
        warn "codegraph install failed; skipping the rest of this module."
        return 1
    fi

    # The installer's target directory is on $PATH for a *login* shell, via
    # ~/.zshrc - not for this one. Without this, wire_claude below cannot find
    # the binary that was just installed and silently skips. That exact failure
    # already shipped once in this repo with herdr: the container came out with
    # the tool installed, no integration, and a green test suite. Same idiom as
    # 40-tools.sh for fzf and 52-herdr.sh for herdr.
    export PATH="$HOME/.local/bin:$PATH"
}

# ------------------------------------------------------------------
# Opt out of telemetry.
#
# codegraph collects anonymous usage stats by default - the first run prints a
# notice saying so and carries on. One of the events it reports fires from
# `codegraph install` itself ("which agents were configured"), which is why this
# runs BEFORE wire_claude rather than at the end of the module: afterwards would
# be too late to prevent the only event this installer causes.
#
# `codegraph telemetry off` persists the choice to ~/.codegraph/telemetry.json
# ("enabled": false, "consent_source": "cli") and deletes anything already
# queued. It is idempotent and sends nothing itself, so it is deliberately not
# guarded by an "is it already off?" check - running it unconditionally is both
# simpler than parsing that file and correct on a machine where codegraph was
# installed by hand before this module ever ran.
# ------------------------------------------------------------------
disable_telemetry() {
    if [ "$DRY_RUN" != "1" ] && ! have codegraph; then
        return 0
    fi

    step "codegraph telemetry -> off"
    run codegraph telemetry off \
        || warn "could not disable codegraph telemetry; run 'codegraph telemetry off' by hand."
}

# ------------------------------------------------------------------
# Wire the MCP server into Claude Code.
#
# `codegraph install` writes three things: the MCP server into ~/.claude.json,
# an auto-allow entry into ~/.claude/settings.json, and a marker-fenced section
# into an agent instructions file. That last one is why --location is not
# optional here - see the comment on the call itself.
# ------------------------------------------------------------------
wire_claude() {
    # Guarded on DRY_RUN because a dry run never actually installed anything -
    # install_codegraph only printed the curl line - so a bare `have` here
    # reports a missing binary on every dry run and makes a working module look
    # broken. Outside a dry run the check is real.
    if [ "$DRY_RUN" != "1" ] && ! have codegraph; then
        warn "codegraph not found; skipping the Claude Code wiring."
        return 0
    fi

    if ! have claude; then
        warn "Claude Code not found; skipping the codegraph MCP wiring."
        warn "  Run './install.sh --only claude,codegraph' once it is installed."
        return 0
    fi

    # Anchor the idempotence check on the parsed mcpServers key, not on a grep
    # for "codegraph" in ~/.claude.json. That file also stores a history entry
    # per project directory, so the bare string matches on any machine where a
    # path happened to contain it - a check that passes for the wrong reason.
    # python3 is a manifest package on both platforms; 50-claude.sh already
    # edits Claude's JSON this way rather than with jq.
    if [ "$DRY_RUN" != "1" ] && CODEGRAPH_CLAUDE_JSON="$CLAUDE_JSON" python3 - <<'PY' 2>/dev/null
import json, os, sys
try:
    with open(os.environ["CODEGRAPH_CLAUDE_JSON"]) as fh:
        data = json.load(fh)
except (OSError, ValueError):
    sys.exit(1)
sys.exit(0 if "codegraph" in (data.get("mcpServers") or {}) else 1)
PY
    then
        skip "codegraph already wired into Claude Code"
        return 0
    fi

    log "Wiring codegraph into Claude Code..."

    # --location=global is load-bearing. The other value is `local`, which
    # writes the MCP config and a marker-fenced CodeGraph block into the
    # *current project* - and this repo's CLAUDE.md is tracked and public, so a
    # project-local write here would put vendor boilerplate into a committed
    # file. `global` sends all three writes to ~/.claude.json,
    # ~/.claude/settings.json and ~/.claude/CLAUDE.md instead.
    #
    # Running from $HOME is belt-and-braces on top of that: if a future release
    # changes what `global` means, there is no repo checkout under the cwd for
    # a project-local write to land in. `codegraph uninstall` reverses all of it.
    #
    # --target=claude rather than `auto`: auto-detection would also wire up any
    # other agent CLI that happens to be installed, which is a decision for
    # whoever installed that agent, not for this script.
    ( cd "$HOME" && run codegraph install --target=claude --location=global --yes ) \
        || warn "codegraph install failed; run 'codegraph install' by hand to wire the MCP server."
}

main() {
    install_codegraph || return 0
    # Before wire_claude, not after - `codegraph install` reports a telemetry
    # event of its own, so the order here is the whole point.
    disable_telemetry
    wire_claude
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
