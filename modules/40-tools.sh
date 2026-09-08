#!/usr/bin/env bash
# modules/40-tools.sh - fzf (with shell key bindings), Node.js, gh, gws.
#
# ag and ripgrep come from the package manifests; this module handles the
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
    # --key-bindings --completion: write ~/.fzf.zsh, which is the whole point.
    #
    # ZDOTDIR is what actually keeps the installer away from ~/.zshrc - a
    # tracked symlink into this repo that already sources ~/.fzf.zsh itself.
    # The installer resolves its zsh target as ${ZDOTDIR:-~}/.zshrc, so
    # pointing ZDOTDIR at a scratch directory makes the tracked file
    # unreachable rather than merely asked-about. ~/.fzf.zsh is unaffected: its
    # path comes from $HOME, not ZDOTDIR.
    #
    # --no-update-rc alone does NOT hold, and it fails by way of this repo's
    # own rule 2 (don't grep a file for a string that also appears in its own
    # comments) aimed back at us. Before appending, the installer greps .zshrc
    # for the literal `~/.fzf.zsh`. The real source line here spells it
    # "$HOME/.fzf.zsh", so the only thing that matches is the *comment* above
    # it. Its "these matches all seem to be commented - continue anyway?"
    # branch then reassigns update=1, overriding --no-update-rc, and asks; ask()
    # defaults REPLY to "y", so under install.sh - non-interactive, stdin at
    # EOF - the answer is always yes. Every run appended another
    # `[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh` to the tracked .zshrc, which
    # surfaced only as a dirty git status nobody could account for.
    local zdot
    zdot="$(mktemp -d)"
    # shellcheck disable=SC2064  # expand $zdot now, not at trap time
    trap "rm -rf '$zdot'" RETURN

    run env ZDOTDIR="$zdot" "$installer" \
        --key-bindings --completion --no-update-rc --no-bash --no-fish

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

# ------------------------------------------------------------------
# GitHub CLI (gh)
#
# Ubuntu 22.04 does carry a `gh` package, but it's the universe archive's
# snapshot and lags upstream releases; GitHub's own apt repo tracks current
# releases and is what upstream recommends, so this adds it the same way
# NodeSource is added for Node.js above. macOS gets it from packages/brew.txt.
# ------------------------------------------------------------------
install_gh() {
    if have gh; then
        skip "gh already installed"
        return 0
    fi

    is_macos && return 0  # installed from packages/brew.txt

    log "Installing GitHub CLI from its official apt repo..."
    local tmp
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN

    if ! fetch "https://cli.github.com/packages/githubcli-archive-keyring.gpg" "$tmp/githubcli-archive-keyring.gpg"; then
        warn "Could not fetch the GitHub CLI signing key; skipping gh."
        return 0
    fi

    as_root mkdir -p -m 755 /etc/apt/keyrings
    as_root install -o root -g root -m 644 \
        "$tmp/githubcli-archive-keyring.gpg" /etc/apt/keyrings/githubcli-archive-keyring.gpg
    run_sh "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | $SUDO tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
    as_root apt-get update
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y gh \
        || warn "apt install of gh failed."
}

# ------------------------------------------------------------------
# Google Workspace CLI (gws)
#
# https://github.com/googleworkspace/cli - Drive/Gmail/Calendar/Sheets/Docs/
# Chat/Admin from one binary. Installed via npm rather than the brew formula
# that also exists, so macOS and Linux take the exact same path - same
# reasoning as ccstatusline in modules/50-claude.sh. Needs install_nodejs to
# have already run.
# ------------------------------------------------------------------
install_gws() {
    if have gws; then
        skip "gws already installed"
        return 0
    fi
    if ! have npm; then
        warn "npm not found; skipping gws."
        return 0
    fi
    log "Installing gws (Google Workspace CLI)..."
    # On Linux, Node comes from NodeSource's apt package, whose global prefix
    # (/usr/lib/node_modules) is root-owned - `npm install -g` as the normal
    # user fails EACCES (verified). Homebrew's Node on macOS is user-owned,
    # so sudo there would instead leave root-owned files in a brew-managed
    # directory, which is its own kind of broken.
    if is_macos; then
        run npm install -g @googleworkspace/cli || warn "npm install of gws failed."
    else
        as_root npm install -g @googleworkspace/cli || warn "npm install of gws failed."
    fi
}

main() {
    install_fzf
    install_fd
    install_nodejs
    install_gh
    install_gws
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
