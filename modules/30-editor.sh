#!/usr/bin/env bash
# modules/30-editor.sh - Neovim from a pinned official release, plus the Lua
# config tree and a standalone .vimrc for plain vim.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

# Pinned rather than "latest" on purpose, and specifically NOT 0.12.
#
# Neovim's release binaries are built against whatever glibc their CI image
# ships. Probing a real ubuntu:22.04 container (glibc 2.35) showed:
#   v0.10.4            fails - requires GLIBC_2.38
#   v0.11.0 .. v0.12.4 run clean
# so the glibc floor on 22.04 is v0.11.0, which also happens to be blink.cmp's
# minimum. But 0.12 changed the treesitter query-predicate API so `match[id]`
# returns a list of nodes instead of a single node, and nvim-treesitter's
# `master` branch (pinned deliberately - see the treesitter plugin spec in
# lua/plugins/editor.lua - `main` deleted the module this config needs) was
# never updated for it: reproduced by hand, 100% - any bash heredoc or a
# markdown fenced code block crashes the decoration provider on open with
# "attempt to call method 'range' (a nil value)" in query_predicates.lua,
# which then leaves that buffer with no syntax highlighting for the rest of
# the session. Upstream closed both reports "not planned"
# (neovim/neovim#39032, nvim-treesitter/nvim-treesitter#8636) since active
# nvim-treesitter development moved to `main`. Staying on the last 0.11.x
# release sidesteps the incompatibility entirely instead of patching vendored
# plugin code. Override with NVIM_VERSION=... (accepts a tag or "latest")
# after checking the target machine's glibc.
: "${NVIM_VERSION:=v0.11.7}"
NVIM_MIN_MINOR=11

nvim_asset_arch() {
    case "$(uname -m)" in
        x86_64)        echo "x86_64" ;;
        aarch64|arm64) echo "arm64"  ;;
        *) die "No Neovim release build for architecture $(uname -m)." ;;
    esac
}

# Both platforms install the same pinned release tarball, not a package
# manager. On macOS this used to be `brew install neovim` (still listed in
# packages/brew.txt until the fix that added this comment), which pulls
# whatever Homebrew currently calls stable - that floated onto 0.12.4 and hit
# the exact query-predicate crash the NVIM_VERSION pin above exists to avoid.
# A version pin that only one platform honours is not a pin.
install_neovim() {
    local os_prefix arch tarball url tmp extracted target
    os_prefix="macos"; is_macos || os_prefix="linux"
    arch="$(nvim_asset_arch)"
    tarball="nvim-${os_prefix}-${arch}.tar.gz"

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

    log "Installing Neovim $NVIM_VERSION ($os_prefix/$arch)..."
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064  # expand $tmp now, not at trap time
    trap "rm -rf '$tmp'" RETURN

    fetch "$url" "$tmp/$tarball" || die "Could not download $url"

    if [ "$DRY_RUN" = "1" ]; then
        run tar -xzf "$tmp/$tarball" -C "$tmp"
        run "$SUDO" mkdir -p /opt
        run "$SUDO" mv "$tmp/nvim-${os_prefix}-$arch" /opt/
        run "$SUDO" ln -sf "/opt/nvim-${os_prefix}-$arch/bin/nvim" /usr/local/bin/nvim
        return 0
    fi

    tar -xzf "$tmp/$tarball" -C "$tmp"
    extracted="$tmp/nvim-${os_prefix}-${arch}"
    [ -d "$extracted" ] || die "Unexpected archive layout in $tarball"

    target="/opt/nvim-${os_prefix}-${arch}"
    as_root mkdir -p /opt
    as_root rm -rf "$target"
    as_root mv "$extracted" /opt/
    as_root ln -sf "$target/bin/nvim" /usr/local/bin/nvim

    # A binary that unpacks but won't run is the failure mode this pin exists to
    # prevent (glibc too old on Linux). Fail loudly: silently falling back to a
    # package manager's version would install a Neovim this config was not
    # tested against, and the user would discover that as a wall of Lua errors
    # instead of one message.
    if ! /usr/local/bin/nvim --version >/dev/null 2>&1; then
        local err
        err="$(/usr/local/bin/nvim --version 2>&1 | head -3 || true)"
        die "Neovim $NVIM_VERSION does not run on this system:
    $err
$(is_macos || echo "
  This is almost always a glibc mismatch. Your glibc:
    $(ldd --version 2>/dev/null | head -1)")
  Pick a different release and retry, e.g.:
    NVIM_VERSION=v0.11.0 ./install.sh --only editor
  (v0.11.0 is the floor: blink.cmp requires Neovim >= 0.11.)"
    fi

    log "Installed $(nvim --version | head -1)"
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

# Give the still-missing parsers a head start in the background, detached from
# this script, so they are more likely to be done before anyone actually opens
# nvim. Without this, whichever parser is missing for the FIRST file you open
# gets compiled twice at once: nvim-treesitter's ensure_installed runs once for
# the whole configured list at plugin setup, and its auto_install hook
# independently, unconditionally tries to install the current buffer's own
# language too - the two race on the same temp directory (reproduced by hand:
# "mkdir: cannot create directory 'tree-sitter-bash-tmp': File exists", every
# time, opening any not-yet-compiled filetype). The parser still ends up
# correct once the dust settles, but if that race lands mid-redraw it can throw
# from Neovim's decoration provider and leave the buffer with no highlighting
# for the rest of that session - which looks exactly like a broken colorscheme
# and is what motivated this. This does not close the race (nvim-treesitter's
# own logic, not ours), it just makes it far less likely to be hit at all by
# giving the compile a few minutes' head start before a human gets to it.
warm_treesitter_parsers() {
    [ "$DRY_RUN" = "1" ] && return 0
    have nvim || return 0

    log "Warming remaining treesitter parsers in the background..."
    nohup nvim --headless \
        "+lua require('nvim-treesitter.install').ensure_installed_sync(vim.g.dotfiles_ts_parsers)" \
        +qa >/tmp/dotfiles-treesitter-warm.log 2>&1 &
    disown
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
    warm_treesitter_parsers
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
