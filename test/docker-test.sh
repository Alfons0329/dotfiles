#!/usr/bin/env bash
# test/docker-test.sh - build the Ubuntu 22.04 test image end to end.
#
# The build itself is the test: install.sh and verify.sh both run as build
# steps, so a non-zero exit anywhere fails the build.
#
#   ./test/docker-test.sh              build, then report
#   ./test/docker-test.sh --shell      build, then drop into the container
#   ./test/docker-test.sh --with-lsp   also install language servers
#   ./test/docker-test.sh --powerline  install bullet-train instead of starship
#
# --with-lsp matters because install.sh now installs language servers by
# default; the routine build turns them off to stay quick, so without this flag
# nothing exercises the path a real machine actually takes.
#
# --powerline matters for the same reason: the default build never passes it,
# so without this flag the bullet-train branch in verify.sh's zsh checks would
# never run on any platform this test suite actually covers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${IMAGE:-dotfiles-test}"
SHELL_AFTER=0
WITH_LSP=0
POWERLINE=0

for arg in "$@"; do
    case "$arg" in
        --shell)     SHELL_AFTER=1 ;;
        --with-lsp)  WITH_LSP=1 ;;
        --powerline) POWERLINE=1 ;;
        *) echo "Unknown option: $arg  (--shell, --with-lsp, --powerline)" >&2; exit 1 ;;
    esac
done

# Composed from booleans, not overwritten in place, so any combination of
# flags (e.g. --with-lsp --powerline together) survives regardless of order.
INSTALL_FLAGS="--yes --minimal"
[ "$WITH_LSP" = "1" ] || INSTALL_FLAGS="$INSTALL_FLAGS --no-lsp-servers"
[ "$POWERLINE" = "1" ] && INSTALL_FLAGS="$INSTALL_FLAGS --powerline"

cd "$ROOT"

echo "==> Building $IMAGE from a bare ubuntu:22.04 ..."
echo "    install flags: $INSTALL_FLAGS"
docker build --progress=plain \
    --build-arg INSTALL_FLAGS="$INSTALL_FLAGS" \
    -t "$IMAGE" -f test/Dockerfile .

echo
echo "==> Build succeeded: install.sh and verify.sh both passed."

if [ "$SHELL_AFTER" = "1" ]; then
    if [ "$POWERLINE" = "1" ]; then
        echo "==> Starting an interactive shell (expect a bullet-train zsh prompt)."
    else
        echo "==> Starting an interactive shell (expect a starship zsh prompt)."
    fi
    # -e TERM because `docker run -t` otherwise hardcodes TERM=xterm inside the
    # container - not the host's TERM, and not overridable from the outside
    # environment - and xterm's terminfo declares colors#8. tmux then flattens
    # everything Neovim sends onto the terminal's 8-colour ANSI palette, which
    # is what made this container's colours look broken from Ghostty. .zshrc
    # repairs it for interactive shells; this makes it right from PID 1, so a
    # `sh -c` in here behaves the same as a login.
    exec docker run --rm -it -e TERM=xterm-256color "$IMAGE"
fi

echo
echo "==> Confirming an interactive login lands in zsh ..."
# `docker run` uses the image CMD; check the shell that a login actually gets.
shell_name="$(docker run --rm "$IMAGE" zsh -lc 'echo $ZSH_NAME')"
echo "    login shell reports: ${shell_name:-<empty>}"
[ "$shell_name" = "zsh" ] || { echo "    unexpected shell" >&2; exit 1; }

echo
echo "==> Confirming the shell exports a UTF-8 locale ..."
# tmux draws '_' instead of every powerline separator when the client locale is
# not UTF-8, and that is invisible to any check that only looks at config files.
locale_name="$(docker run --rm "$IMAGE" zsh -ic 'echo $LANG' 2>/dev/null | tr -d '\r')"
echo "    LANG reports: ${locale_name:-<empty>}"
case "$locale_name" in
    *UTF-8|*utf8) ;;
    *) echo "    LANG is not UTF-8; tmux will render tofu" >&2; exit 1 ;;
esac

echo
echo "All checks passed. Explore it with:  docker run --rm -it $IMAGE"
