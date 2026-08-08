#!/usr/bin/env bash
# modules/20-tmux.sh - oh-my-tmux (gpakosz/.tmux) + tmux-resurrect.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

install_oh_my_tmux() {
    log "Setting up oh-my-tmux..."
    git_get https://github.com/gpakosz/.tmux.git "$HOME/.tmux"

    # ~/.tmux.conf is upstream's file and must track the repo verbatim;
    # ~/.tmux.conf.local is the sanctioned override point and is ours.
    link "$HOME/.tmux/.tmux.conf" "$HOME/.tmux.conf"
    link "$HOME_SRC/.tmux.conf.local" "$HOME/.tmux.conf.local"
}

install_resurrect() {
    log "Installing tmux-resurrect..."
    git_get https://github.com/tmux-plugins/tmux-resurrect.git \
        "$HOME/.tmux/plugins/tmux-resurrect"
}

main() {
    install_oh_my_tmux
    install_resurrect

    # Reload a running server so the new config applies without a restart.
    if [ "$DRY_RUN" != "1" ] && have tmux && tmux info &>/dev/null; then
        log "Reloading running tmux server..."
        tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
    fi
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
