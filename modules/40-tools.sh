#!/usr/bin/env bash
# modules/40-tools.sh - fzf (with shell key bindings), Node.js.
#
# ag and ripgrep come from the package manifests; this module handles the two
# tools that need more than an install line.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

# ------------------------------------------------------------------
# fzf
#
# `install --all` is the important part: it writes ~/.fzf.zsh, which is what
# binds
#   Ctrl+R  fuzzy history search
#   Ctrl+T  insert a file path at the cursor
#   Alt+C   cd into a subdirectory
# Installing the binary alone gives you none of those.
# ------------------------------------------------------------------
install_fzf() {
    local installer

    if is_macos; then
        # brew ships a current fzf (the formula is in packages/brew.txt); only
        # its shell-integration script needs running.
        if ! have brew; then
            warn "brew missing; skipping fzf shell integration."
            return 0
        fi
        installer="$(brew --prefix)/opt/fzf/install"
        if [ ! -x "$installer" ] && [ "$DRY_RUN" != "1" ]; then
            warn "fzf integration script not found at $installer; skipping."
            return 0
        fi
    else
        # Ubuntu 22.04's apt fzf is 0.29, which predates `fzf --zsh` and several
        # option names used below. Install from git so Linux and macOS run
        # comparable versions.
        log "Installing fzf from git (apt's build is too old)..."
        git_get https://github.com/junegunn/fzf.git "$HOME/.fzf"
        installer="$HOME/.fzf/install"
    fi

    log "Configuring fzf shell integration (Ctrl+R / Ctrl+T / Alt+C)..."
    # --no-bash/--no-fish: zsh is the shell this setup configures.
    # --key-bindings --completion --no-update-rc: write ~/.fzf.zsh but leave
    #   ~/.zshrc alone, since .zshrc is a tracked symlink that already sources it.
    run "$installer" --key-bindings --completion --no-update-rc --no-bash --no-fish

    is_linux && export PATH="$HOME/.fzf/bin:$PATH"
    return 0
}

# ------------------------------------------------------------------
# fd
#
# Listed in the package manifests (brew.txt / apt.txt), so the package
# install puts the binary on PATH. The only extra step is on Debian/Ubuntu,
# where the `fd-find` package ships the binary as `fdfind` (Debian's collision
# avoidance with fdclone). snacks.picker's explorer search calls `fd`, so
# symlink the renamed binary into ~/.local/bin - the same user-local dir the
# starship installer uses, which is already on PATH.
# ------------------------------------------------------------------
install_fd() {
    is_macos && return 0  # brew's `fd` formula installs the `fd` binary directly

    if have fd; then
        skip "fd already on PATH"
        return 0
    fi

    if ! have fdfind; then
        warn "fdfind not found (apt fd-find not installed?); skipping fd symlink."
        return 0
    fi

    mkdir -p "$HOME/.local/bin"
    run ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    log "Symlinked fdfind -> ~/.local/bin/fd for snacks.picker."
    return 0
}

# ------------------------------------------------------------------
# Node.js
#
# Needed by ccstatusline, the Claude Code npm fallback, and several language
# servers. Ubuntu 22.04's own nodejs is 12.x, too old for all of them.
# ------------------------------------------------------------------
install_nodejs() {
    if have node; then
        local major
        major="$(node --version 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/')"
        if [ -n "$major" ] && [ "$major" -ge 18 ]; then
            skip "Node.js $(node --version) already installed"
            return 0
        fi
        warn "Node.js $(node --version) is older than v18; installing a current release."
    fi

    if is_macos; then
        run brew install node
        return 0
    fi

    log "Installing Node.js from NodeSource..."
    local tmp
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN

    if ! fetch "https://deb.nodesource.com/setup_22.x" "$tmp/nodesource.sh"; then
        warn "Could not fetch the NodeSource setup script; falling back to apt's nodejs."
        as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm \
            || warn "apt nodejs install failed."
        return 0
    fi

    as_root bash "$tmp/nodesource.sh"
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
}

main() {
    install_fzf
    install_fd
    install_nodejs
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
