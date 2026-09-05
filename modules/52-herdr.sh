#!/usr/bin/env bash
# modules/52-herdr.sh - herdr, a terminal multiplexer that tracks agent state.
#
# Numbered after 50-claude.sh rather than next to 20-tmux.sh, even though herdr
# is a multiplexer: `herdr integration install claude` needs Claude Code on the
# box already, and module order is the only dependency mechanism this installer
# has.
#
# herdr does not replace tmux and nothing here touches it. tmux stays installed
# and configured; herdr is a second multiplexer you opt into by typing `herdr`.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

HERDR_CONFIG_DIR="$HOME/.config/herdr"
HERDR_CONFIG="$HERDR_CONFIG_DIR/config.toml"

install_herdr() {
    if have herdr; then
        skip "herdr already installed ($(herdr --version 2>/dev/null || echo version unknown))"
        return 0
    fi

    log "Installing herdr..."
    if is_macos && have brew; then
        run brew install herdr && return 0
        warn "Homebrew install failed; trying the official installer."
    fi

    # The official installer is a POSIX sh script needing only curl and awk. It
    # resolves herdr.dev/latest.json, verifies the download against the SHA-256
    # in that manifest, and installs to ${HERDR_INSTALL_DIR:-$HOME/.local/bin} -
    # which ~/.zshrc already puts first on $PATH. No version pin: unlike the
    # Neovim pin, which exists because specific releases will not run on
    # 22.04's glibc, there is no known version constraint here, and pinning
    # would put installs and `herdr update` on different manifests.
    if ! run_sh "curl $CURL_OPTS https://herdr.dev/install.sh | sh"; then
        warn "herdr install failed; skipping the rest of this module."
        return 1
    fi

    # The installer's target directory is on $PATH for a *login* shell, via
    # ~/.zshrc - not for this one. Without this, install_claude_integration
    # below cannot find the binary it just installed and silently skips, which
    # is exactly what happened on the first Docker build: the container came
    # out with herdr installed and no Claude integration, and the test suite
    # was happy because the check it would have failed depends on the
    # integration having run at all. Same idiom as 40-tools.sh for fzf.
    export PATH="$HOME/.local/bin:$PATH"
}

# ------------------------------------------------------------------
# Seed ~/.config/herdr/config.toml once, then never touch it again.
#
# This is the ~/.zshrc.local pattern (modules/10-shell.sh), not the symlink
# pattern used for .tmux.conf.local and the Ghostty config. The reason is in
# config.toml.example: herdr has no include directive, so a machine-local
# override file has nowhere to be layered from, and a tracked symlink would
# mean every per-machine tweak dirties this checkout and dies on the next pull.
# ------------------------------------------------------------------
seed_config() {
    local template="$HOME_SRC/.config/herdr/config.toml.example"

    if [ -f "$HERDR_CONFIG" ]; then
        skip "$HERDR_CONFIG exists (left untouched)"
        return 0
    fi

    log "Seeding $HERDR_CONFIG from template..."
    run mkdir -p "$HERDR_CONFIG_DIR"
    run cp "$template" "$HERDR_CONFIG"
    apply_theme
}

# Map --theme onto a herdr built-in. `herdr --default-config` lists them:
# catppuccin, terminal, tokyo-night, dracula, nord, gruvbox, one-dark,
# solarized, kanagawa, rose-pine, vesper. Two of this repo's three themes are
# in there under a different spelling; ayu-dark is not, and gets left on
# herdr's default rather than approximated with a near-miss palette - the same
# call 60-desktop.sh makes for Ghostty.
#
# This runs from seed_config only, so a later `--theme` change does not rewrite
# an existing config. That is the cost of the seed-once model, and saying so is
# better than clobbering a file the user has since edited.
apply_theme() {
    [ -n "${DOTFILES_THEME:-}" ] || return 0

    local theme_name
    case "$DOTFILES_THEME" in
        tokyonight) theme_name="tokyo-night" ;;
        kanagawa)   theme_name="kanagawa" ;;
        *)
            warn "herdr has no built-in '$DOTFILES_THEME' theme; leaving tokyo-night."
            warn "  Set theme.name yourself in $HERDR_CONFIG ('herdr --default-config' lists the built-ins)."
            return 0
            ;;
    esac

    step "herdr theme -> $theme_name"
    # The template ships tokyo-night, so only a different name needs writing.
    [ "$theme_name" = "tokyo-night" ] && return 0

    if [ "$DRY_RUN" = "1" ]; then
        run_sh "sed -i.bak 's/^name = .*/name = \"$theme_name\"/' $HERDR_CONFIG"
        return 0
    fi
    # BSD and GNU sed disagree on -i with no argument; give both a suffix and
    # delete the backup, which is the only form that works on macOS and Linux.
    sed -i.dotfiles-bak "s/^name = .*/name = \"$theme_name\"/" "$HERDR_CONFIG"
    rm -f "$HERDR_CONFIG.dotfiles-bak"
}

# ------------------------------------------------------------------
# Claude Code integration.
#
# Without it herdr classifies Claude Code panes by screen-scraping the bottom
# of the buffer; with it, Claude's own lifecycle hooks report working/blocked/
# idle and the sidebar becomes authoritative. That sidebar is the entire reason
# this module exists, so the integration is not optional here.
#
# It writes hooks into ~/.claude/settings.json, which modules/50-claude.sh also
# writes (the Stop-hook completion notifier). Verified by diffing that file
# either side of this call: herdr merges into the existing JSON and leaves the
# notifier's Stop entry in place. test/verify.sh asserts the notifier survived,
# so a future herdr release that starts rewriting the file fails the build
# instead of silently killing notifications.
# ------------------------------------------------------------------
install_claude_integration() {
    # Guarded on DRY_RUN because a dry run never actually installed anything -
    # install_herdr only printed the curl line - so a bare `have` here reports a
    # missing binary on every dry run against a machine that does not yet have
    # herdr, and makes a working module look broken. Outside a dry run the check
    # is real, and is what catches a genuinely failed install.
    if [ "$DRY_RUN" != "1" ] && ! have herdr; then
        warn "herdr not found; skipping the Claude Code integration."
        return 0
    fi

    if ! have claude; then
        warn "Claude Code not found; skipping the herdr integration."
        warn "  Run './install.sh --only claude,herdr' once it is installed."
        return 0
    fi

    # Anchor on "current", not on "installed". `herdr integration status`
    # prints one line per agent and the *absent* state reads
    # "claude: not installed" - so a grep for "installed" matches the case it
    # was written to exclude, and the install silently never runs. The
    # installed state reads "claude: current (v8)"; an out-of-date hook reports
    # something else and should fall through to a reinstall.
    if [ "$DRY_RUN" != "1" ] && herdr integration status 2>/dev/null | grep -q '^claude: current'; then
        skip "herdr Claude Code integration already installed"
        return 0
    fi

    log "Installing the herdr Claude Code integration..."
    run herdr integration install claude \
        || warn "herdr integration install claude failed; the sidebar will fall back to screen detection."
}

main() {
    install_herdr || return 0
    seed_config
    install_claude_integration
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
