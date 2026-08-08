#!/usr/bin/env bash
# modules/10-shell.sh - zsh, oh-my-zsh, bullet-train theme, plugins, .zshrc.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM_DIR="$ZSH_DIR/custom"

install_oh_my_zsh() {
    if [ -d "$ZSH_DIR" ]; then
        skip "oh-my-zsh already installed"
    else
        log "Installing oh-my-zsh..."
        # --unattended: don't run zsh at the end, don't try to chsh (we handle
        # the shell change ourselves, further down).
        run_sh "sh -c \"\$(curl $CURL_OPTS https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" '' --unattended --keep-zshrc"
    fi

    run mkdir -p "$ZSH_CUSTOM_DIR/themes" "$ZSH_CUSTOM_DIR/plugins"
}

install_theme() {
    local theme="$ZSH_CUSTOM_DIR/themes/bullet-train.zsh-theme"
    if [ -f "$theme" ]; then
        skip "bullet-train theme present"
        return
    fi
    log "Installing bullet-train theme..."
    fetch "https://raw.githubusercontent.com/caiogondim/bullet-train.zsh/master/bullet-train.zsh-theme" \
          "$theme"
}

install_zsh_plugins() {
    log "Installing zsh plugins..."
    git_get https://github.com/zsh-users/zsh-autosuggestions.git \
        "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
    git_get https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
}

deploy_zshrc() {
    link "$HOME_SRC/.zshrc" "$HOME/.zshrc"

    # Seed the machine-local override file once. Never overwrite it: it holds
    # secrets, and clobbering it on a re-run would be destructive.
    if [ -f "$HOME/.zshrc.local" ]; then
        skip "$HOME/.zshrc.local exists (left untouched)"
    else
        log "Seeding ~/.zshrc.local from template..."
        run cp "$HOME_SRC/.zshrc.local.example" "$HOME/.zshrc.local"
    fi

    # Homebrew's PATH setup has to be established before .zshrc's own PATH
    # block runs, and its location differs between Apple Silicon and Intel.
    if is_macos; then
        local brew_bin=""
        [ -x /opt/homebrew/bin/brew ] && brew_bin=/opt/homebrew/bin/brew
        [ -x /usr/local/bin/brew ]    && brew_bin=/usr/local/bin/brew

        if [ -n "$brew_bin" ]; then
            local zprofile="$HOME/.zprofile"
            if [ -f "$zprofile" ] && grep -q 'brew shellenv' "$zprofile" 2>/dev/null; then
                skip "brew shellenv already in ~/.zprofile"
            else
                log "Adding brew shellenv to ~/.zprofile..."
                run_sh "printf '\n# Homebrew\neval \"\$(%s shellenv)\"\n' '$brew_bin' >> '$zprofile'"
            fi
        elif [ "$DRY_RUN" != "1" ]; then
            warn "brew not found; skipping shellenv wiring."
        fi
    fi
}

# ------------------------------------------------------------------
# Make zsh the login shell.
#
# chsh fails in a lot of realistic situations: containers, LDAP-backed
# accounts, restricted shells. The .bashrc handoff is the fallback that makes
# `docker run` (and a locked-down build box) still land in zsh.
# ------------------------------------------------------------------
set_default_shell() {
    local zsh_path
    zsh_path="$(command -v zsh || true)"
    [ -n "$zsh_path" ] || { warn "zsh not on PATH; skipping shell change."; return; }

    if [ "${SHELL:-}" = "$zsh_path" ]; then
        skip "login shell is already $zsh_path"
    else
        log "Setting login shell to $zsh_path..."

        # A shell must be listed in /etc/shells before chsh will accept it.
        if [ -f /etc/shells ] && ! grep -qxF "$zsh_path" /etc/shells; then
            run_sh "echo '$zsh_path' | ${SUDO:+$SUDO }tee -a /etc/shells >/dev/null"
        fi

        if [ "$DRY_RUN" = "1" ]; then
            run chsh -s "$zsh_path"
        else
            chsh -s "$zsh_path" 2>/dev/null \
                || ${SUDO:+$SUDO} chsh -s "$zsh_path" "$(whoami)" 2>/dev/null \
                || warn "Could not change the login shell; relying on the .bashrc handoff."
        fi
    fi

    add_bashrc_handoff "$zsh_path"
}

add_bashrc_handoff() {
    local zsh_path="$1"
    local bashrc="$HOME/.bashrc"

    if [ -f "$bashrc" ] && grep -q 'exec zsh' "$bashrc" 2>/dev/null; then
        skip "bash -> zsh handoff already present"
        return
    fi

    log "Adding bash -> zsh handoff to ~/.bashrc..."
    if [ "$DRY_RUN" = "1" ]; then
        run_sh "cat >> '$bashrc' <<'EOF' (bash->zsh handoff)"
        return
    fi

    cat >> "$bashrc" <<EOF

# Added by dotfiles/install.sh: if the login shell could not be changed (common
# in containers and on managed accounts), hand off to zsh for interactive use.
if [ -t 1 ] && [ -z "\$ZSH_VERSION" ] && [ -x "$zsh_path" ]; then
    exec "$zsh_path" -l
fi
EOF
}

main() {
    install_oh_my_zsh
    install_theme
    install_zsh_plugins
    deploy_zshrc
    set_default_shell
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
