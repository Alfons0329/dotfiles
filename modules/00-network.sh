#!/usr/bin/env bash
# modules/00-network.sh - Cloudflare WARP as a local proxy, macOS only.
#
# On a HiNet 1 Gbps line, GitHub's CDN (ghcr.io bottles, release assets) ran at
# 30-190 KB/s while speed.cloudflare.com ran at 55 MB/s: the line is fine, the
# peering to GitHub is not. Through WARP the same ghcr.io blob came down at
# 2.1 MB/s and a release asset at 9.4 MB/s; `brew fetch --force ripgrep` went
# from 64 s to 1 s.
#
# Named 00-network so it sorts before 00-packages: the point is to have the
# proxy up *before* Homebrew's own installer clones from GitHub, not after. That
# is also why WARP comes from Cloudflare's .pkg rather than the cask - there is
# no brew yet. install.sh's warp_env then exports HTTPS_PROXY for every module
# that follows.
#
# Proxy mode, not the full tunnel: only processes that opt in (via HTTPS_PROXY)
# go through Cloudflare, so local and already-well-peered traffic is untouched.
#
# Skip with `./install.sh --skip network`.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

WARP_PKG_URL="https://downloads.cloudflareclient.com/v1/download/macos/ga"
WARP_CLI="/usr/local/bin/warp-cli"

install_warp() {
    if [ -x "$WARP_CLI" ]; then
        skip "Cloudflare WARP already installed"
        return 0
    fi

    log "Installing Cloudflare WARP..."
    local pkg="${TMPDIR:-/tmp}/cloudflare-warp.pkg"
    fetch "$WARP_PKG_URL" "$pkg" || { warn "WARP download failed."; return 1; }
    as_root installer -pkg "$pkg" -target / || { warn "WARP install failed."; return 1; }
    run rm -f "$pkg"
}

# The pkg starts the warp-svc daemon via launchd, but not synchronously: a
# warp-cli call straight after `installer` returns can still find no daemon.
wait_for() {
    local what="$1" tries=30
    shift
    [ "$DRY_RUN" = "1" ] && return 0
    while ! "$@" >/dev/null 2>&1; do
        tries=$((tries - 1))
        [ "$tries" -gt 0 ] || { warn "Timed out waiting for $what."; return 1; }
        sleep 1
    done
}

proxy_up() { (exec 3<>"/dev/tcp/127.0.0.1/$WARP_PROXY_PORT") 2>/dev/null; }

configure_warp() {
    wait_for "the WARP daemon" "$WARP_CLI" status || return 1

    # An existing registration means someone already set this machine up -
    # possibly in full-tunnel mode on purpose. Leave its mode alone.
    if [ "$DRY_RUN" != "1" ] && "$WARP_CLI" registration show >/dev/null 2>&1; then
        skip "WARP already registered; leaving its mode alone"
        if "$WARP_CLI" settings 2>/dev/null | grep -q 'Mode: WarpProxy'; then
            run "$WARP_CLI" connect
        fi
    else
        # --accept-tos: running install.sh is the consent; there is no TTY-free
        # way to register otherwise, and the GUI onboarding is not needed.
        step "register WARP, proxy mode on 127.0.0.1:$WARP_PROXY_PORT"
        run "$WARP_CLI" --accept-tos registration new
        run "$WARP_CLI" --accept-tos mode proxy
        run "$WARP_CLI" --accept-tos proxy port "$WARP_PROXY_PORT"
        run "$WARP_CLI" --accept-tos connect
    fi

    wait_for "the WARP proxy on :$WARP_PROXY_PORT" proxy_up || return 1
    log "WARP proxy up on 127.0.0.1:$WARP_PROXY_PORT"
}

main() {
    if ! is_macos; then
        skip "WARP proxy is macOS only"
        return 0
    fi
    # Never fatal: a failure here only means downloads stay on the slow route.
    install_warp || return 0
    configure_warp || warn "WARP not connected; continuing without the proxy."
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
