#!/bin/bash
#
# Build Ghostty.app on macOS, guarding the two things that actually go wrong:
# building the wrong branch, and building with an Xcode that cannot link it.
#
# Runs either from inside a Ghostty checkout, or from anywhere with GHOSTTY_SRC
# pointing at one - which is how modules/70-ghostty.sh invokes it.
#
#   GHOSTTY_SRC=~/.cache/dotfiles/ghostty \
#   BUILD_BRANCH=fix/bracketed-paste-newline-compat ./build-ghostty-macos.sh
#
set -euo pipefail

REPO_DIR="${GHOSTTY_SRC:-$(cd "$(dirname "$0")" && pwd)}"
cd "$REPO_DIR"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
# Ghostty fails to link with Xcode > 26.3 (upstream issue #11991): the macOS
# libghostty archive ends up incomplete / misaligned and the xcodebuild link
# step dies with undefined ghostty_app_* / _GImGui symbols. The documented fix
# is to build with Xcode <= 26.3. This is the toolchain only — it does NOT
# affect which source/branch you build, so your feature branch is unaffected.
MAX_XCODE_VERSION="26.3"
EXPECTED_BRANCH="${BUILD_BRANCH:-main}"

# ---------------------------------------------------------------------------
# 1. Branch check
# ---------------------------------------------------------------------------
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ERROR: expected branch '$EXPECTED_BRANCH', currently on '$CURRENT_BRANCH'"
  echo "  Switch with: git checkout $EXPECTED_BRANCH"
  echo "  Or override : BUILD_BRANCH=$CURRENT_BRANCH $0"
  exit 1
fi
echo "==> Branch: $CURRENT_BRANCH ($(git rev-parse --short HEAD))"

# ---------------------------------------------------------------------------
# 2. Xcode compatibility check
# ---------------------------------------------------------------------------
# Return 0 if $1 <= $2 using version sort (treats 26.3 < 26.5 correctly).
version_le() {
  [ "$1" = "$2" ] && return 0
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ]
}

DEVELOPER_DIR_PATH=$(xcode-select --print-path 2>/dev/null || true)
if [ -z "$DEVELOPER_DIR_PATH" ]; then
  echo "ERROR: no Xcode/CLT selected. Install Xcode and run:"
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

# Must be a full Xcode, not the Command Line Tools (CLT can't build the app).
if ! printf '%s' "$DEVELOPER_DIR_PATH" | grep -q "Xcode"; then
  echo "ERROR: active developer dir is Command Line Tools, not a full Xcode:"
  echo "  $DEVELOPER_DIR_PATH"
  echo "  Switch to Xcode, e.g.:"
  echo "  sudo xcode-select --switch /Applications/Xcode_26.3.app/Contents/Developer"
  exit 1
fi

XCODE_VERSION=$(xcodebuild -version 2>/dev/null | awk '/^Xcode/ {print $2}')
if [ -z "$XCODE_VERSION" ]; then
  echo "ERROR: could not determine Xcode version from 'xcodebuild -version'"
  exit 1
fi

if ! version_le "$XCODE_VERSION" "$MAX_XCODE_VERSION"; then
  echo "ERROR: Xcode $XCODE_VERSION is incompatible (must be <= $MAX_XCODE_VERSION)."
  echo "  Active: $DEVELOPER_DIR_PATH"
  echo "  Ghostty fails to link with Xcode > $MAX_XCODE_VERSION (upstream #11991)."
  echo ""
  echo "  Fix: install Xcode $MAX_XCODE_VERSION from"
  echo "       https://developer.apple.com/download/all/?q=Xcode%20$MAX_XCODE_VERSION"
  echo "  then point the toolchain at it:"
  echo "       sudo xcode-select --switch /Applications/Xcode_$MAX_XCODE_VERSION.app/Contents/Developer"
  echo "       rm -rf ~/.cache/zig $REPO_DIR/.zig-cache"
  echo ""
  echo "  (Detected Xcode apps:)"
  for app in /Applications/Xcode*.app; do
    [ -d "$app" ] || continue
    v=$("$app/Contents/Developer/usr/bin/xcodebuild" -version 2>/dev/null | awk '/^Xcode/ {print $2}')
    echo "       $app  ->  Xcode ${v:-?}"
  done
  exit 1
fi
echo "==> Xcode: $XCODE_VERSION (compatible, <= $MAX_XCODE_VERSION) at $DEVELOPER_DIR_PATH"

# ---------------------------------------------------------------------------
# 3. Build
# ---------------------------------------------------------------------------
# With a compatible Xcode, the upstream build just works — zig builds
# libghostty + the xcframework AND drives xcodebuild to produce the .app.
# No archive patching needed.
echo "==> Building (zig build -Doptimize=ReleaseFast)..."
zig build -Doptimize=ReleaseFast

echo ""
echo "==> Done. App: $REPO_DIR/zig-out/Ghostty.app"
