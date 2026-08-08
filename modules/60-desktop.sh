#!/usr/bin/env bash
# modules/60-desktop.sh - GUI-only setup: terminal emulator, fonts, monitors.
#
# Skipped entirely under --minimal, which install.sh turns on automatically on
# a Linux box with no DISPLAY. A headless build server has no use for any of
# this.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

install_casks() {
    is_macos || return 0
    have brew || { warn "brew not found; skipping casks."; return 0; }

    local casks
    read_lines casks < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' \
        "$DOTFILES_ROOT/packages/brew-cask.txt" | grep -v '^$')

    log "Installing ${#casks[@]} Homebrew casks..."
    local c
    for c in "${casks[@]}"; do
        if [ "$DRY_RUN" != "1" ] && brew list --cask "$c" >/dev/null 2>&1; then
            skip "$c already installed"
            continue
        fi
        run brew install --cask "$c" || warn "brew install --cask $c failed; continuing."
    done
}

# Ghostty reads the XDG path on every platform, so the config deploys the same
# way everywhere even though the app itself is installed only on macOS.
deploy_ghostty_config() {
    link "$HOME_SRC/.config/ghostty/config" "$HOME/.config/ghostty/config"
}

# iTerm2. Configured only when it is already installed - this is a Ghostty-first
# setup, and a dotfiles run should not drag in a second terminal emulator.
#
# The profile is deployed as an iTerm2 Dynamic Profile rather than by editing
# com.googlecode.iterm2.plist: it is iTerm2's own supported declarative
# mechanism, it hot-reloads, and it keeps the whole profile in version control.
# It carries the powerline font, the same palette as the Ghostty config,
# Option-sends-Esc+ (needed for every Alt chord in Neovim), and the Cmd+Shift+F
# key mapping that feeds the project-search binding.
ITERM_PROFILE_GUID="2F5C1A90-3B7E-4D62-9C48-A1E6F0B2D735"

deploy_iterm_profile() {
    is_macos || return 0

    if [ ! -d /Applications/iTerm.app ] && [ "$DRY_RUN" != "1" ]; then
        skip "iTerm2 not installed; skipping its profile"
        return 0
    fi

    local rel="Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json"
    link "$HOME_SRC/$rel" "$HOME/$rel"

    set_iterm_default_profile
}

# Point iTerm2 at the profile above. This one step cannot be declarative: the
# existing default profile's GUID is a per-machine UUID, so there is nothing to
# match on except by writing our own fixed GUID into the preference.
set_iterm_default_profile() {
    # iTerm2 rewrites its entire plist when it quits, so a write made while it
    # is running is silently discarded.
    if [ "$DRY_RUN" != "1" ] && pgrep -x iTerm2 >/dev/null 2>&1; then
        warn "iTerm2 is running; not changing the default profile."
        warn "  Quit iTerm2 and re-run, or pick 'dotfiles' in Preferences > Profiles."
        return 0
    fi

    step "iTerm2: default profile -> dotfiles"
    run defaults write com.googlecode.iterm2 "Default Bookmark Guid" \
        -string "$ITERM_PROFILE_GUID"

    [ "$DRY_RUN" = "1" ] && return 0

    # Read it back. If iTerm2 declines a dynamic profile as the default, at
    # least make the font - the part that must not fail - stick on whatever
    # profile is actually default.
    local current
    current="$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null || true)"
    [ "$current" = "$ITERM_PROFILE_GUID" ] && return 0

    warn "iTerm2 kept its own default profile; setting the font on that instead."
    local plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    [ -f "$plist" ] || return 0
    /usr/libexec/PlistBuddy \
        -c "Set :'New Bookmarks':0:'Normal Font' RobotoMonoForPowerline-Regular 14" \
        "$plist" 2>/dev/null \
        || warn "Could not set the iTerm2 font; do it in Preferences > Profiles > Text."
}

main() {
    if [ "$MINIMAL" = "1" ]; then
        skip "--minimal: skipping desktop setup"
        return 0
    fi

    if ! is_macos; then
        skip "desktop module currently only covers macOS"
        return 0
    fi

    install_casks
    deploy_ghostty_config
    deploy_iterm_profile
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
