#!/usr/bin/env bash
#
# install.sh - one-shot development environment setup.
#
# Targets Ubuntu 22.04+ / Debian and macOS. Idempotent: safe to re-run, and
# anything it would overwrite in $HOME is backed up with a timestamp first.
#
#   ./install.sh                       # everything appropriate for this machine
#   ./install.sh --dry-run             # print every command, change nothing
#   ./install.sh --minimal             # headless server: skip desktop/GUI bits
#   ./install.sh --only editor         # run a single module
#   ./install.sh --skip claude,tmux    # run everything except these
#   ./install.sh --no-lsp-servers      # skip language servers (large download)
#   ./install.sh --ghostty-build       # macOS: build the patched Ghostty
#   ./install.sh --insecure            # behind a TLS-inspecting corporate proxy
#   ./install.sh --powerline           # use the bullet-train zsh theme instead of starship
#   ./install.sh --theme kanagawa      # tokyonight (default) | kanagawa | ayu-dark, for nvim + Ghostty
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/core.sh
source "$SCRIPT_DIR/lib/core.sh"

ONLY=""
SKIP=""
THEME="tokyonight"

usage() {
    # Print the header comment block, stopping at the first line of code, so
    # the usage text cannot drift out of sync with the comment above it.
    awk 'NR >= 3 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
    cat <<'EOF'

Modules (in run order):
  packages   system packages, locale
  shell      zsh, oh-my-zsh, theme, plugins
  tmux       oh-my-tmux + tmux-resurrect
  editor     Neovim (pinned release) + native Lua config; plain vim gets its own .vimrc
  tools      fzf (Ctrl+R/Ctrl+T/Alt+C), ag, ripgrep, Node.js
  claude     Claude Code, ccstatusline, completion notifications
  herdr      herdr, an agent-aware multiplexer (does not replace tmux)
  desktop    macOS only: fonts, terminal config, iTerm2 profile
  ghostty    macOS only: opt-in patched Ghostty build (asks first)

Environment:
  NVIM_VERSION   Neovim release tag to install (default: pinned known-good)
  DOTFILES_THEME tokyonight (default) | kanagawa | ayu-dark, for nvim + Ghostty
  DRY_RUN=1      same as --dry-run
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run|-n)   DRY_RUN=1 ;;
        --minimal)      MINIMAL=1 ;;
        --yes|-y)       ASSUME_YES=1 ;;
        --lsp-servers)    LSP_SERVERS=1 ;;
        --no-lsp-servers) LSP_SERVERS=0 ;;
        --ghostty-build)  GHOSTTY_BUILD=1 ;;
        --insecure|-k)  INSECURE=1 ;;
        --powerline)    POWERLINE=1 ;;
        --theme)        shift; THEME="${1:-}" ;;
        --theme=*)      THEME="${1#*=}" ;;
        --only)         shift; ONLY="${1:-}" ;;
        --only=*)       ONLY="${1#*=}" ;;
        --skip)         shift; SKIP="${1:-}" ;;
        --skip=*)       SKIP="${1#*=}" ;;
        --help|-h)      usage; exit 0 ;;
        *)              die "Unknown option: $1  (try --help)" ;;
    esac
    shift
done

export DRY_RUN MINIMAL ASSUME_YES LSP_SERVERS GHOSTTY_BUILD INSECURE POWERLINE THEME

# Validate the theme name up front - a typo should fail loudly, not silently
# leave a machine on the default while the user thinks they switched.
case "$THEME" in
    tokyonight|kanagawa|ayu-dark) ;;
    *) die "Unknown theme '$THEME'. Available: tokyonight, kanagawa, ayu-dark" ;;
esac
export DOTFILES_THEME="$THEME"

# ------------------------------------------------------------------
# Preflight
# ------------------------------------------------------------------
detect_os
detect_sudo
apply_insecure

# A headless Linux box has no GUI to configure. Detect it so the common case
# (SSH into a build server) needs no flags at all.
if [ "$MINIMAL" != "1" ] && is_linux && [ -z "${DISPLAY:-}" ]; then
    MINIMAL=1
    export MINIMAL
    log "No DISPLAY detected - enabling --minimal (skipping desktop module)."
fi

[ "$DRY_RUN" = "1" ] && warn "DRY RUN - no changes will be made."

# ------------------------------------------------------------------
# Module selection
# ------------------------------------------------------------------
# Module files are numbered so the run order is a property of the filesystem,
# not a list that can drift out of sync with what is on disk.
read_lines MODULE_FILES < <(find "$SCRIPT_DIR/modules" -maxdepth 1 -name '[0-9][0-9]-*.sh' | sort)
[ "${#MODULE_FILES[@]}" -gt 0 ] || die "No modules found in $SCRIPT_DIR/modules"

# "30-editor.sh" -> "editor"
module_name() { basename "$1" .sh | sed 's/^[0-9]*-//'; }

in_csv() {
    local needle="$1" csv="$2" item
    IFS=',' read -ra _items <<< "$csv"
    for item in "${_items[@]}"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

# Validate selectors up front - a typo in --only should fail loudly, not
# silently run nothing.
ALL_NAMES=()
for f in "${MODULE_FILES[@]}"; do ALL_NAMES+=("$(module_name "$f")"); done
for sel in $(echo "${ONLY},${SKIP}" | tr ',' ' '); do
    [ -z "$sel" ] && continue
    printf '%s\n' "${ALL_NAMES[@]}" | grep -qx "$sel" \
        || die "Unknown module '$sel'. Available: ${ALL_NAMES[*]}"
done

FAILED=()
RAN=()

for module_file in "${MODULE_FILES[@]}"; do
    name="$(module_name "$module_file")"

    if [ -n "$ONLY" ] && ! in_csv "$name" "$ONLY"; then
        continue
    fi
    if [ -n "$SKIP" ] && in_csv "$name" "$SKIP"; then
        skip "skipping module: $name"
        continue
    fi

    printf '\n%s=== %s ===%s\n' "$C_GRN" "$name" "$C_OFF"

    # Modules run in a subshell: one module blowing up cannot corrupt the
    # orchestrator's state, and `set -e` inside a module stays scoped to it.
    # shellcheck source=/dev/null  # module path is resolved at runtime
    if ( source "$module_file" && main ); then
        RAN+=("$name")
    else
        warn "Module '$name' failed."
        FAILED+=("$name")
    fi
done

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
printf '\n%s=====================================================%s\n' "$C_GRN" "$C_OFF"
if [ "${#FAILED[@]}" -eq 0 ]; then
    printf '%s  Setup complete.%s  Modules: %s\n' "$C_GRN" "$C_OFF" "${RAN[*]:-none}"
else
    printf '%s  Setup finished with errors.%s\n' "$C_YEL" "$C_OFF"
    printf '    ok:     %s\n' "${RAN[*]:-none}"
    printf '    failed: %s\n' "${FAILED[*]}"
fi
printf '%s=====================================================%s\n' "$C_GRN" "$C_OFF"

if [ "$DRY_RUN" != "1" ] && [ "${#FAILED[@]}" -eq 0 ]; then
    cat <<EOF

Next steps:
  1. exec zsh                     start a shell with the new config
  2. nvim  then  :Copilot auth    one-time GitHub Copilot login
  3. claude                       one-time Claude Code login
$( [ "$LSP_SERVERS" = "1" ] || echo "  4. ./install.sh --only editor --lsp-servers   install language servers (skipped)" )

  Machine-specific settings and secrets go in ~/.zshrc.local (never committed).
EOF
fi

[ "${#FAILED[@]}" -eq 0 ]
