#!/usr/bin/env bash
# modules/30-editor.sh - Neovim from a pinned official release, plus the Lua
# config tree and a standalone .vimrc for plain vim.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

# Pinned rather than "latest" on purpose.
#
# Neovim's release binaries are built against whatever glibc their CI image
# ships. Probing a real ubuntu:22.04 container (glibc 2.35) showed:
#   v0.10.4            fails - requires GLIBC_2.38
#   v0.11.0 .. v0.12.4 run clean
# so the usable floor on 22.04 is v0.11.0, which also happens to be blink.cmp's
# minimum. Override with NVIM_VERSION=... (accepts a tag or "latest") after
# checking the target machine's glibc.
: "${NVIM_VERSION:=v0.12.4}"
NVIM_MIN_MINOR=11

nvim_asset_arch() {
    case "$(uname -m)" in
        x86_64)        echo "x86_64" ;;
        aarch64|arm64) echo "arm64"  ;;
        *) die "No Neovim release build for architecture $(uname -m)." ;;
    esac
}

install_neovim_linux() {
    local arch tarball url tmp extracted target
    arch="$(nvim_asset_arch)"
    tarball="nvim-linux-${arch}.tar.gz"

    if [ "$NVIM_VERSION" = "latest" ]; then
        url="https://github.com/neovim/neovim/releases/latest/download/${tarball}"
    else
        url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${tarball}"
    fi

    # Already installed at the pinned version? Nothing to do.
    if have nvim && [ "$NVIM_VERSION" != "latest" ]; then
        local current
        current="v$(nvim --version 2>/dev/null | head -1 | sed 's/^NVIM v//')"
        if [ "$current" = "$NVIM_VERSION" ]; then
            skip "Neovim $NVIM_VERSION already installed"
            return 0
        fi
    fi

    log "Installing Neovim $NVIM_VERSION ($arch)..."
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064  # expand $tmp now, not at trap time
    trap "rm -rf '$tmp'" RETURN

    fetch "$url" "$tmp/$tarball" || die "Could not download $url"

    if [ "$DRY_RUN" = "1" ]; then
        run tar -xzf "$tmp/$tarball" -C "$tmp"
        run "$SUDO" mv "$tmp/nvim-linux-$arch" /opt/
        run "$SUDO" ln -sf "/opt/nvim-linux-$arch/bin/nvim" /usr/local/bin/nvim
        return 0
    fi

    tar -xzf "$tmp/$tarball" -C "$tmp"
    extracted="$tmp/nvim-linux-${arch}"
    [ -d "$extracted" ] || die "Unexpected archive layout in $tarball"

    target="/opt/nvim-linux-${arch}"
    as_root rm -rf "$target"
    as_root mv "$extracted" /opt/
    as_root ln -sf "$target/bin/nvim" /usr/local/bin/nvim

    # A binary that unpacks but won't run is the failure mode this pin exists to
    # prevent (glibc too old). Fail loudly: silently falling back to the distro
    # package would install a Neovim too old to load this config at all, and the
    # user would discover that as a wall of Lua errors instead of one message.
    if ! /usr/local/bin/nvim --version >/dev/null 2>&1; then
        local err
        err="$(/usr/local/bin/nvim --version 2>&1 | head -3 || true)"
        die "Neovim $NVIM_VERSION does not run on this system:
    $err

  This is almost always a glibc mismatch. Your glibc:
    $(ldd --version 2>/dev/null | head -1)
  Pick an older release and retry, e.g.:
    NVIM_VERSION=v0.11.0 ./install.sh --only editor
  (v0.11.0 is the floor: blink.cmp requires Neovim >= 0.11.)"
    fi

    log "Installed $(nvim --version | head -1)"
}

install_neovim() {
    if is_macos; then
        # Handled by packages/brew.txt; just confirm it landed.
        have nvim && { skip "Neovim installed via Homebrew"; return 0; }
        [ "$DRY_RUN" = "1" ] && return 0
        warn "Neovim not found after the packages module; trying brew directly."
        run brew install neovim
        return 0
    fi
    install_neovim_linux
}

check_neovim_version() {
    [ "$DRY_RUN" = "1" ] && return 0
    have nvim || { warn "nvim not on PATH; skipping version check."; return 0; }

    local minor
    minor="$(nvim --version | head -1 | sed -n 's/^NVIM v[0-9]*\.\([0-9]*\).*/\1/p')"
    if [ -n "$minor" ] && [ "$minor" -lt "$NVIM_MIN_MINOR" ]; then
        die "Neovim 0.$minor is too old; this config needs >= 0.$NVIM_MIN_MINOR (blink.cmp)."
    fi
}

deploy_configs() {
    # The whole nvim directory is one symlink, so files added to the repo later
    # appear without re-running the installer. link() moves any pre-existing
    # ~/.config/nvim aside first, which is what clears out an old init.vim (it
    # would otherwise take precedence over init.lua and resurrect the previous
    # configuration).
    link "$HOME_SRC/.config/nvim" "$HOME/.config/nvim"

    # Plain vim's config: separate file, no relationship to the above.
    link "$HOME_SRC/.vimrc" "$HOME/.vimrc"
}

sync_plugins() {
    [ "$DRY_RUN" = "1" ] && { run nvim --headless "+Lazy! sync" +qa; return 0; }
    have nvim || { warn "nvim missing; skipping plugin sync."; return 0; }

    log "Installing Neovim plugins..."
    if nvim --headless "+Lazy! sync" +qa 2>&1 | tail -5; then
        log "Plugins installed."
    else
        warn "Plugin sync reported errors. Open nvim and run :Lazy to inspect."
    fi
}

# Report what treesitter finished installing, without waiting for it.
#
# Parsers are NOT compiled synchronously here, and that is deliberate. The
# plugin's own `:TSUpdate` build step dispatches async jobs and returns, so nvim
# exits with most parsers still downloading - a probe of a built container found
# 4 of 17 present. The obvious fix, `:TSInstallSync <every language>`, was tried
# and is far worse: these parsers are enormous generated C files (typescript's
# parser.c is 17.5 MB, tsx's is comparable, bash's is 9.9 MB) and compiling all
# of them serially at -O2 took over 27 minutes, with no output the whole time.
# That is not an acceptable step in a script whose entire promise is "run this
# once and the machine is ready".
#
# So the config keeps `auto_install`, and any parser that did not make it
# compiles the first time you open that filetype - a few seconds, once, in the
# background, from the same GitHub the installer already reached. This function
# just says which ones are already done so the outcome is not a surprise.
report_treesitter_parsers() {
    [ "$DRY_RUN" = "1" ] && return 0
    have nvim || return 0

    local parser_dir count
    parser_dir="$HOME/.local/share/nvim/lazy/nvim-treesitter/parser"
    count="$(find "$parser_dir" -name '*.so' 2>/dev/null | wc -l | tr -d ' ')"

    log "Treesitter: ${count:-0} parsers compiled so far."
    step "the rest build on first use of each filetype (auto_install)"
}

# Language servers install by default - without them nothing in the editor
# completes, jumps to a definition, or renames a symbol, which is most of the
# point. They are still the largest and most network-dependent step, so a
# failure only warns: a mason download that will not complete must never be the
# reason a machine setup fails. Skip the whole step with --no-lsp-servers.
install_lsp_servers() {
    if [ "$LSP_SERVERS" != "1" ]; then
        skip "--no-lsp-servers: skipping language servers"
        return 0
    fi

    local servers="lua-language-server basedpyright typescript-language-server bash-language-server json-lsp gopls"
    log "Installing language servers via mason: $servers"

    if [ "$DRY_RUN" = "1" ]; then
        run nvim --headless "+MasonInstall $servers" +qa
        return 0
    fi

    # shellcheck disable=SC2086  # word splitting is intended here
    nvim --headless "+MasonInstall $servers" +qa 2>&1 | tail -10 \
        || warn "Some language servers failed to install; run :Mason in nvim to retry."
}

main() {
    install_neovim
    check_neovim_version
    deploy_configs
    sync_plugins
    report_treesitter_parsers
    install_lsp_servers
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
