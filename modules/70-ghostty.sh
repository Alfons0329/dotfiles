#!/usr/bin/env bash
# modules/70-ghostty.sh - build Ghostty from source with the bracketed-paste fix.
#
# macOS only, and opt-in: this is a half-hour source build that also wants a
# specific Xcode, so it never runs unless you pass --ghostty-build or answer yes
# to the prompt. Everything else in this repo works without it.
#
# WHAT IT FIXES
#   In bracketed paste mode, Ghostty passes pasted newlines through as LF, where
#   Terminal.app converts them to CR. The practical effect: paste two commands
#   into a shell and they land in the edit buffer as one line instead of running
#   as two. The fix adds a `clipboard-paste-bracketed-safe-newline` option that
#   applies LF->CR in bracketed mode as well.
#
# WHERE THE PATCH COMES FROM
#   It is not upstream. Ghostty ships `clipboard-paste-bracketed-safe`, which is
#   a different, paste-protection option; the real fix lives in a public fork:
#
#     https://github.com/kitknox/ghostty
#     branch fix/bracketed-paste-newline-compat, commit fc4c5289d
#     (see ghostty-org/ghostty discussion #9592)
#
#   So this module builds public open-source code from a public fork.
set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/core.sh"
fi

GHOSTTY_REPO="https://github.com/kitknox/ghostty"
GHOSTTY_BRANCH="fix/bracketed-paste-newline-compat"
GHOSTTY_COMMIT="fc4c5289d"          # the commit that adds the config option
MAX_XCODE_VERSION="26.3"            # upstream issue #11991; see the build script
ZIG_VERSION="0.15.2"                # build.zig.zon: .minimum_zig_version

CACHE_DIR="$HOME/.cache/dotfiles"
GHOSTTY_SRC="$CACHE_DIR/ghostty"
ZIG_DIR="$CACHE_DIR/zig-$ZIG_VERSION"

# ------------------------------------------------------------------
# Xcode
#
# Apple gates Xcode downloads behind an authenticated developer login, so no
# script can fetch it unattended. `xcodes` gets as close as Apple permits: it
# prompts once for an Apple ID, then downloads, expands and installs.
# ------------------------------------------------------------------
version_le() {
    [ "$1" = "$2" ] && return 0
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ]
}

active_xcode_version() {
    xcodebuild -version 2>/dev/null | awk '/^Xcode/ {print $2}'
}

ensure_xcode() {
    local current
    current="$(active_xcode_version)"

    if [ -n "$current" ] && version_le "$current" "$MAX_XCODE_VERSION" \
       && xcode-select --print-path 2>/dev/null | grep -q Xcode; then
        skip "Xcode $current is already selected and compatible"
        return 0
    fi

    if [ -n "$current" ]; then
        warn "Active Xcode is $current; Ghostty needs <= $MAX_XCODE_VERSION (upstream #11991)."
    else
        warn "No full Xcode selected (Command Line Tools cannot build the app)."
    fi

    local target="/Applications/Xcode-$MAX_XCODE_VERSION.app"
    if [ ! -d "$target" ] && [ ! -d "/Applications/Xcode_$MAX_XCODE_VERSION.app" ]; then
        log "Installing Xcode $MAX_XCODE_VERSION via xcodes (asks for your Apple ID)..."
        have xcodes || run brew install xcodesorg/made/xcodes
        run xcodes install "$MAX_XCODE_VERSION" \
            || die "xcodes could not install Xcode $MAX_XCODE_VERSION. Download it manually from
  https://developer.apple.com/download/all/?q=Xcode%20$MAX_XCODE_VERSION
then re-run this module."
    fi

    [ -d "$target" ] || target="/Applications/Xcode_$MAX_XCODE_VERSION.app"
    if [ ! -d "$target" ]; then
        # A dry run never installed anything, so the app is legitimately absent.
        [ "$DRY_RUN" = "1" ] || die "Expected Xcode $MAX_XCODE_VERSION at $target after install."
    fi

    log "Selecting $target"
    run sudo xcode-select --switch "$target/Contents/Developer"
    run sudo xcodebuild -license accept
    run xcodebuild -runFirstLaunch
}

# ------------------------------------------------------------------
# Zig
#
# Pinned to the exact version in build.zig.zon rather than `brew install zig`,
# whose version moves. The asset name has changed shape across zig releases, so
# read the URL out of the official index instead of constructing it.
# ------------------------------------------------------------------
ensure_zig() {
    if [ -x "$ZIG_DIR/zig" ]; then
        skip "zig $ZIG_VERSION already unpacked"
        export PATH="$ZIG_DIR:$PATH"
        return 0
    fi

    local arch tarball index url
    case "$(uname -m)" in
        arm64|aarch64) arch="aarch64" ;;
        x86_64)        arch="x86_64" ;;
        *)             die "Unsupported architecture for zig: $(uname -m)" ;;
    esac

    log "Resolving zig $ZIG_VERSION for macos-$arch..."
    run mkdir -p "$CACHE_DIR"

    if [ "$DRY_RUN" = "1" ]; then
        fetch "https://ziglang.org/download/index.json" "$CACHE_DIR/zig-index.json"
        run tar -xf "$CACHE_DIR/zig-$ZIG_VERSION.tar.xz" -C "$CACHE_DIR"
        export PATH="$ZIG_DIR:$PATH"
        return 0
    fi

    index="$CACHE_DIR/zig-index.json"
    fetch "https://ziglang.org/download/index.json" "$index"

    url="$(ZIG_VERSION="$ZIG_VERSION" ARCH="$arch" python3 -c '
import json, os, sys
data = json.load(sys.stdin)
rel = data.get(os.environ["ZIG_VERSION"])
if not rel:
    sys.exit("zig %s is not in the download index" % os.environ["ZIG_VERSION"])
# Key naming has varied between releases: try both orderings.
for key in ("%s-macos" % os.environ["ARCH"], "macos-%s" % os.environ["ARCH"]):
    if key in rel:
        print(rel[key]["tarball"])
        break
else:
    sys.exit("no macos build for %s in the index" % os.environ["ARCH"])
' <"$index")" || die "Could not resolve a zig $ZIG_VERSION download URL."

    tarball="$CACHE_DIR/$(basename "$url")"
    step "downloading $url"
    fetch "$url" "$tarball"
    run tar -xf "$tarball" -C "$CACHE_DIR"

    # The archive unpacks to a versioned directory; normalise the name so the
    # PATH entry above is stable.
    local extracted
    extracted="$(find "$CACHE_DIR" -maxdepth 1 -type d -name "zig-*$ZIG_VERSION*" ! -name "$(basename "$ZIG_DIR")" | head -1)"
    [ -n "$extracted" ] || die "zig archive did not unpack as expected."
    run rm -rf "$ZIG_DIR"
    run mv "$extracted" "$ZIG_DIR"
    run rm -f "$tarball"

    export PATH="$ZIG_DIR:$PATH"
    step "zig $( "$ZIG_DIR/zig" version 2>/dev/null || echo "$ZIG_VERSION" )"
}

# ------------------------------------------------------------------
# Source, build, install
# ------------------------------------------------------------------
fetch_source() {
    git_get "$GHOSTTY_REPO" "$GHOSTTY_SRC" "$GHOSTTY_BRANCH"

    [ "$DRY_RUN" = "1" ] && return 0

    # git_get clones --depth=1, so the history that would contain $GHOSTTY_COMMIT
    # is not there to search. Assert on the thing that actually matters instead:
    # that the config option the patch introduces is present in the source.
    grep -rq 'clipboard-paste-bracketed-safe-newline' "$GHOSTTY_SRC/src/config/Config.zig" \
        || die "The checkout of $GHOSTTY_BRANCH does not contain the paste fix
(expected clipboard-paste-bracketed-safe-newline from commit $GHOSTTY_COMMIT in
src/config/Config.zig). The branch may have moved; nothing was built."
}

build_and_install() {
    # Mandatory after any Xcode switch: a cached archive linked by the previous
    # toolchain reproduces the #11991 link failure even once the right Xcode is
    # selected, and the failure message gives no hint that caching is the cause.
    step "clearing zig caches"
    run rm -rf "$HOME/.cache/zig" "$GHOSTTY_SRC/.zig-cache"

    log "Building Ghostty (this takes a while on the first run)..."
    run env GHOSTTY_SRC="$GHOSTTY_SRC" BUILD_BRANCH="$GHOSTTY_BRANCH" \
        "$DOTFILES_ROOT/scripts/build-ghostty-macos.sh"

    log "Installing to /Applications/Ghostty.app"
    run osascript -e 'quit app "Ghostty"' || true
    run rm -rf /Applications/Ghostty.app
    run cp -R "$GHOSTTY_SRC/zig-out/Ghostty.app" /Applications/Ghostty.app
}

# The option only exists in the patched build, and Ghostty complains about keys
# it does not recognise - so it cannot live in the tracked config, which has to
# stay valid on a stock install. The tracked config ends with
# `config-file = ?ghostty-local.conf`, an optional include; this writes it.
enable_paste_fix() {
    local local_conf="$HOME/.config/ghostty/ghostty-local.conf"

    if [ "$DRY_RUN" = "1" ]; then
        step "would write clipboard-paste-bracketed-safe-newline to $local_conf"
        return 0
    fi

    mkdir -p "$(dirname "$local_conf")"
    if grep -q '^clipboard-paste-bracketed-safe-newline' "$local_conf" 2>/dev/null; then
        skip "paste fix already enabled in $local_conf"
        return 0
    fi

    step "enabling clipboard-paste-bracketed-safe-newline in $local_conf"
    cat >>"$local_conf" <<'EOF'
# Written by modules/70-ghostty.sh. Requires the patched Ghostty build; a stock
# build does not know this key. Untracked and machine-local by design.
clipboard-paste-bracketed-safe-newline = true
EOF
}

main() {
    if ! is_macos; then
        skip "patched Ghostty build is macOS only"
        return 0
    fi
    if [ "$MINIMAL" = "1" ]; then
        skip "--minimal: skipping Ghostty build"
        return 0
    fi

    if [ "$GHOSTTY_BUILD" != "1" ]; then
        confirm "Build the patched Ghostty from source? (needs Xcode <= $MAX_XCODE_VERSION, ~30 min)" \
            || { skip "skipping Ghostty build (enable with --ghostty-build)"; return 0; }
    fi

    ensure_xcode
    ensure_zig
    fetch_source
    build_and_install
    enable_paste_fix

    log "Done. Restart Ghostty to pick up the new build and config."
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_os; detect_sudo; apply_insecure; main
fi
