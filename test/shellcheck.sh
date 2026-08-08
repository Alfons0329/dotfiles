#!/usr/bin/env bash
# test/shellcheck.sh - lint every shell script in the repo.
#
# Runs shellcheck natively if installed, otherwise falls back to the official
# container image so this works on a machine with nothing set up yet.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# Built with a read loop rather than mapfile: macOS ships bash 3.2, which has
# neither mapfile nor readarray.
SCRIPTS=()
while IFS= read -r f; do
    SCRIPTS+=("$f")
done < <(
    {
        find . -name '*.sh' -not -path './.git/*' -not -path './ref/*'
        echo ./install.sh
    } | sort -u
)

echo "Linting ${#SCRIPTS[@]} scripts..."

# SC1091: sourced files aren't followed across the repo boundary.
# SC2034: colour variables in lib/core.sh are used by files that source it.
EXCLUDE="SC1091,SC2034"

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck --shell=bash --severity=warning --exclude="$EXCLUDE" "${SCRIPTS[@]}"
elif command -v docker >/dev/null 2>&1; then
    echo "(shellcheck not installed; using the koalaman/shellcheck container)"
    docker run --rm -v "$ROOT:/mnt" -w /mnt koalaman/shellcheck:stable \
        --shell=bash --severity=warning --exclude="$EXCLUDE" "${SCRIPTS[@]}"
else
    echo "Neither shellcheck nor docker is available; cannot lint." >&2
    exit 127
fi

status=$?
if [ "$status" -eq 0 ]; then
    echo "shellcheck: clean"
fi
exit "$status"
