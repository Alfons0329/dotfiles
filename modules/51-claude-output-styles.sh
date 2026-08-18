#!/usr/bin/env bash
# modules/51-claude-output-styles.sh - Claude Code output styles.
#
# Split out from 50-claude.sh rather than folded in: adding a style is then a
# file drop with no shell changes, and `--only claude-output-styles` doesn't
# drag in a CLI reinstall to test one.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

OUTPUT_STYLES_SRC="$HOME_SRC/.claude/output-styles"
OUTPUT_STYLES_DST="$HOME/.claude/output-styles"

# ~/.claude is Claude Code's live state dir - sessions, plugins, caches,
# settings.json - and 50-claude.sh deliberately never symlinks it wholesale.
# This only ever touches one subdirectory of it, file by file, the same way
# the Ghostty config is a single symlink inside an otherwise real directory.
deploy_output_styles() {
    log "Deploying Claude Code output styles..."
    run mkdir -p "$OUTPUT_STYLES_DST"

    local f name
    for f in "$OUTPUT_STYLES_SRC"/*.md; do
        [ -e "$f" ] || continue
        name="$(basename "$f")"
        link "$f" "$OUTPUT_STYLES_DST/$name"
    done
}

main() {
    deploy_output_styles
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
