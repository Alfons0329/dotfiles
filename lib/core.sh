#!/usr/bin/env bash
# lib/core.sh - shared helpers for install.sh and every modules/*.sh
#
# Sourced, never executed. Defines functions and a handful of globals; nothing
# here touches the system at source time.

# ------------------------------------------------------------------
# Output
# ------------------------------------------------------------------
if [ -t 1 ]; then
    C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[1;33m'
    C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_OFF=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_OFF=""
fi

log()   { printf '%s==>%s %s\n' "$C_GRN" "$C_OFF" "$*"; }
step()  { printf '%s  ->%s %s\n' "$C_BLU" "$C_OFF" "$*"; }
warn()  { printf '%s[warn]%s %s\n' "$C_YEL" "$C_OFF" "$*" >&2; }
die()   { printf '%s[error]%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }
skip()  { printf '%s  ~~ %s%s\n' "$C_DIM" "$*" "$C_OFF"; }

# ------------------------------------------------------------------
# confirm - ask a yes/no question, defaulting to no.
#
# Returns non-zero unless the answer is an explicit yes, so it is safe to guard
# expensive or invasive work with. Never blocks: with --yes, in a dry run, or
# when stdin is not a terminal (a Docker build layer, CI), it declines rather
# than waiting for input that will never arrive.
# ------------------------------------------------------------------
confirm() {
    local prompt="$1" reply

    if [ "$DRY_RUN" = "1" ]; then
        skip "would ask: $prompt"
        return 1
    fi
    if [ "$ASSUME_YES" = "1" ] || [ ! -t 0 ]; then
        skip "not interactive; declining: $prompt"
        return 1
    fi

    printf '%s  ?? %s [y/N] %s' "$C_YEL" "$prompt" "$C_OFF"
    read -r reply
    case "$reply" in
        [yY] | [yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# ------------------------------------------------------------------
# Globals (install.sh overrides these from its flags)
# ------------------------------------------------------------------
: "${DRY_RUN:=0}"        # 1 = print commands, change nothing
: "${MINIMAL:=0}"        # 1 = headless server, skip desktop module
: "${ASSUME_YES:=0}"     # 1 = never prompt
: "${LSP_SERVERS:=1}"    # 1 = install language servers via mason (--no-lsp-servers)
: "${GHOSTTY_BUILD:=0}"  # 1 = build the patched Ghostty from source (macOS only)
: "${INSECURE:=0}"       # 1 = disable TLS verification (corporate MITM proxy)
: "${POWERLINE:=0}"      # 1 = use the bullet-train zsh theme instead of starship
: "${FORCE_PKG_MGR:=}"   # override OS detection, for dry-run inspection

CURL_OPTS="-fsSL"
GIT_SSL_ENV=""

# ------------------------------------------------------------------
# run - the single choke point for anything that mutates the system.
#
# Every install/copy/symlink call goes through this, which is what makes
# --dry-run trustworthy rather than decorative.
# ------------------------------------------------------------------
run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '%s      $ %s%s\n' "$C_DIM" "$*" "$C_OFF"
        return 0
    fi
    "$@"
}

# Same, but for a string evaluated by the shell (pipes, redirects, globs).
run_sh() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '%s      $ %s%s\n' "$C_DIM" "$*" "$C_OFF"
        return 0
    fi
    # shellcheck disable=SC2294  # the string form is the point: callers pass
    # pipelines and redirects that must be interpreted by the shell.
    eval "$@"
}

# ------------------------------------------------------------------
# Privilege escalation
#
# Containers run as root with no sudo installed; build machines run as a
# normal user with sudo. Resolve once, use $SUDO everywhere.
# ------------------------------------------------------------------
detect_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
    elif command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        die "This script needs root or sudo, and neither is available."
    fi
    export SUDO
}

# Wrapper so callers read naturally and $SUDO="" doesn't expand to an empty arg.
as_root() {
    if [ -n "${SUDO:-}" ]; then
        run "$SUDO" "$@"
    else
        run "$@"
    fi
}

# ------------------------------------------------------------------
# OS / package manager detection
# ------------------------------------------------------------------
detect_os() {
    if [ -n "$FORCE_PKG_MGR" ]; then
        PKG_MGR="$FORCE_PKG_MGR"
        OS_NAME="forced:$FORCE_PKG_MGR"
        log "Package manager forced to '$PKG_MGR'"
        export PKG_MGR OS_NAME
        return
    fi

    case "$(uname -s)" in
        Darwin)
            PKG_MGR="brew"
            OS_NAME="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
            ;;
        Linux)
            if command -v apt-get >/dev/null 2>&1; then
                PKG_MGR="apt"
                OS_NAME="$( (. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") || echo Linux)"
            else
                die "Unsupported Linux: this setup targets Debian/Ubuntu (apt) only."
            fi
            ;;
        *)
            die "Unsupported OS: $(uname -s)"
            ;;
    esac
    log "Detected $OS_NAME (pkg manager: $PKG_MGR)"
    export PKG_MGR OS_NAME
}

is_macos() { [ "$PKG_MGR" = "brew" ]; }
is_linux() { [ "$PKG_MGR" = "apt" ]; }

# ------------------------------------------------------------------
# TLS relaxation for corporate MITM proxies
# ------------------------------------------------------------------
apply_insecure() {
    [ "$INSECURE" = "1" ] || return 0
    CURL_OPTS="-fsSLk"
    GIT_SSL_ENV="GIT_SSL_NO_VERIFY=true"
    warn "--insecure: TLS certificate verification is DISABLED."
    warn "Only use this on a network you trust (e.g. behind a corporate proxy)."
}

# ------------------------------------------------------------------
# Filesystem helpers
# ------------------------------------------------------------------
_timestamp() { date +%Y%m%d%H%M%S; }

# link <src> <dst>
# Symlink src -> dst. If dst exists and is not already the right symlink, move
# it aside with a timestamp first. Never silently destroys anything.
link() {
    local src="$1" dst="$2"

    [ -e "$src" ] || die "link: source does not exist: $src"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        skip "$dst -> already linked"
        return 0
    fi

    run mkdir -p "$(dirname "$dst")"

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        local backup
        backup="$dst.bak.$(_timestamp)"
        warn "Backing up existing $dst -> $backup"
        run mv "$dst" "$backup"
    fi

    step "link $dst -> $src"
    run ln -sfn "$src" "$dst"
}

# git_get <repo> <dest> [branch]
# Shallow clone, or fast-forward an existing checkout. Idempotent.
git_get() {
    local repo="$1" dest="$2" branch="${3:-}"

    if [ -d "$dest/.git" ]; then
        step "update $(basename "$dest")"
        if [ "$DRY_RUN" = "1" ]; then
            run_sh "env $GIT_SSL_ENV git -C '$dest' pull --rebase --quiet"
        else
            env ${GIT_SSL_ENV:+"$GIT_SSL_ENV"} git -C "$dest" pull --rebase --quiet \
                || warn "Could not update $dest (continuing with existing checkout)."
        fi
        return 0
    fi

    step "clone $repo"
    run mkdir -p "$(dirname "$dest")"
    if [ -n "$branch" ]; then
        run_sh "env $GIT_SSL_ENV git clone --depth=1 --branch '$branch' '$repo' '$dest'"
    else
        run_sh "env $GIT_SSL_ENV git clone --depth=1 '$repo' '$dest'"
    fi
}

# fetch <url> <dest>
fetch() {
    run_sh "curl $CURL_OPTS '$1' -o '$2'"
}

have() { command -v "$1" >/dev/null 2>&1; }

# read_lines <array_name>  -- reads stdin into the named array, skipping blanks.
#
# macOS ships bash 3.2, which has neither `mapfile` nor `readarray`. Since this
# script's whole job is bootstrapping a machine that has nothing installed yet,
# it cannot require a newer bash than the OS provides.
#
#   read_lines pkgs < <(read_manifest packages/apt.txt)
read_lines() {
    local __name="$1" __line
    eval "$__name=()"
    while IFS= read -r __line || [ -n "$__line" ]; do
        [ -n "$__line" ] || continue
        eval "$__name+=(\"\$__line\")"
    done
}

# Where this repo lives, resolved from lib/core.sh's own location.
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_SRC="$DOTFILES_ROOT/home"
export DOTFILES_ROOT HOME_SRC
