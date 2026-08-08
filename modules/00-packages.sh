#!/usr/bin/env bash
# modules/00-packages.sh - Homebrew bootstrap, locale, and system packages.
#
# Package lists live in packages/*.txt rather than inline arrays, so adding a
# tool is a one-line data change and the README can be generated from the same
# source of truth.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

# Read a manifest into stdout: strip comments, blank lines, trailing whitespace.
read_manifest() {
    local file="$1"
    [ -f "$file" ] || die "Missing package manifest: $file"
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$file" | grep -v '^$'
}

# ------------------------------------------------------------------
# Homebrew (macOS)
# ------------------------------------------------------------------
install_homebrew() {
    if have brew; then
        log "Homebrew present; updating."
        run brew update --quiet || warn "brew update failed; continuing."
        return
    fi

    log "Installing Homebrew..."
    run_sh "/bin/bash -c \"\$(curl $CURL_OPTS https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

    # Put brew on PATH for the remainder of this run (10-shell.sh appends the
    # permanent shellenv line to .zshrc).
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    elif [ "$DRY_RUN" != "1" ]; then
        die "Homebrew installed but no brew binary found in the expected locations."
    fi
}

# ------------------------------------------------------------------
# Locale (Linux only; macOS is UTF-8 already)
# ------------------------------------------------------------------
setup_locale() {
    is_linux || return 0

    if locale 2>/dev/null | grep -q 'en_US.UTF-8'; then
        skip "locale already en_US.UTF-8"
        return 0
    fi

    log "Configuring en_US.UTF-8 locale..."
    as_root locale-gen en_US.UTF-8
    as_root update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
}

# ------------------------------------------------------------------
# Packages
# ------------------------------------------------------------------
install_apt_packages() {
    local pkgs
    read_lines pkgs < <(read_manifest "$DOTFILES_ROOT/packages/apt.txt")

    log "Installing ${#pkgs[@]} apt packages..."
    as_root apt-get update -q
    # Set DEBIAN_FRONTEND via `env` rather than a shell prefix: sudo scrubs the
    # environment by default, so `DEBIAN_FRONTEND=x sudo apt-get ...` silently
    # loses the variable and tzdata opens an interactive prompt.
    as_root env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends "${pkgs[@]}"
}

install_brew_packages() {
    local pkgs
    read_lines pkgs < <(read_manifest "$DOTFILES_ROOT/packages/brew.txt")

    log "Installing ${#pkgs[@]} Homebrew formulae..."
    # One at a time: a single unavailable formula shouldn't abort the rest.
    local p
    for p in "${pkgs[@]}"; do
        if [ "$DRY_RUN" != "1" ] && brew list --formula "$p" >/dev/null 2>&1; then
            skip "$p already installed"
            continue
        fi
        run brew install "$p" || warn "brew install $p failed; continuing."
    done
}

# ------------------------------------------------------------------
# bat: Debian ships the binary as `batcat` because of a name clash.
#
# ref-style `alias bat="batcat"` in .zshrc breaks on macOS and is invisible to
# anything that isn't an interactive zsh. A shim on PATH fixes it everywhere.
# ------------------------------------------------------------------
setup_bat_shim() {
    is_linux || return 0
    have batcat || return 0
    have bat && return 0

    log "Linking batcat -> bat in ~/.local/bin"
    run mkdir -p "$HOME/.local/bin"
    run ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
}

main() {
    if is_macos; then
        install_homebrew
        install_brew_packages
    else
        # Packages first: setup_locale needs locale-gen, which arrives with the
        # `locales` package listed in the manifest.
        install_apt_packages
        setup_locale
        setup_bat_shim
    fi
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
