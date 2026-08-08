# ~/.zshrc - managed by github.com/<user>/dotfiles
#
# This file is a symlink into the dotfiles repo and is overwritten on update.
# Machine-specific settings, work aliases and anything secret belong in
# ~/.zshrc.local, which is sourced at the very end and is never committed.

# -------------------------------------------------------------------
# Locale - must come first
# -------------------------------------------------------------------
# tmux only draws multibyte characters when the client's locale says UTF-8;
# otherwise it substitutes '_' for each one, which turns every powerline
# separator in the prompt and the status bar into a row of underscores. A
# container or a bare SSH session frequently starts with LANG unset -
# /etc/default/locale is only read by PAM - so set it here rather than assume.
if [[ -z ${LC_ALL:-} && ( -z ${LANG:-} || ${LANG} == (C|POSIX) ) ]]; then
    if locale -a 2>/dev/null | grep -qi '^en_US\.utf-\?8$'; then
        export LANG=en_US.UTF-8
    else
        export LANG=C.UTF-8
    fi
fi

# Disable XON/XOFF flow control. A terminal traps Ctrl+S as "stop output" and
# freezes the display until Ctrl+Q; turning it off is what lets Ctrl+S reach the
# program in the foreground, which is how the Neovim save mapping works.
[[ -t 0 ]] && stty -ixon 2>/dev/null

export ZSH="$HOME/.oh-my-zsh"

# bullet-train lives in $ZSH_CUSTOM/themes and needs a powerline-patched font
# (Roboto Mono for Powerline is installed by the desktop module on macOS).
ZSH_THEME="bullet-train"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

# Compute the git prompt off the main thread; without this, prompt redraw in a
# large repo blocks every keystroke.
zstyle ':omz:alpha:lib:git' async-prompt yes

source "$ZSH/oh-my-zsh.sh"

# -------------------------------------------------------------------
# PATH
# -------------------------------------------------------------------
# ~/.local/bin holds shims created by the installer (e.g. bat -> batcat on
# Debian, where the binary is named batcat to avoid a package clash).
path=(
    "$HOME/.local/bin"
    "$HOME/bin"
    "$HOME/.fzf/bin"        # git-installed fzf must win over any older apt copy
    "$HOME/.cargo/bin"
    "$HOME/go/bin"
    /usr/local/go/bin
    $path
)
# Drop entries that don't exist on this machine, and de-duplicate.
path=(${^path}(N-/))
typeset -U path

export GOPATH="$HOME/go"

# -------------------------------------------------------------------
# Editor
# -------------------------------------------------------------------
if (( $+commands[nvim] )); then
    export EDITOR=nvim
    export VISUAL=nvim
    alias vi=nvim
else
    export EDITOR=vim
    export VISUAL=vim
fi

# -------------------------------------------------------------------
# fzf - fuzzy finder
#
#   Ctrl+R  search shell history
#   Ctrl+T  insert a file path into the current command line
#   Alt+C   cd into a subdirectory
#
# These bindings come from ~/.fzf.zsh, written by `fzf --install --all`.
# -------------------------------------------------------------------
[ -f "$HOME/.fzf.zsh" ] && source "$HOME/.fzf.zsh"

if (( $+commands[rg] )); then
    # Respect .gitignore and skip .git when listing files for Ctrl+T.
    export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git/*"'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'

# Preview file contents while picking with Ctrl+T.
if (( $+commands[bat] )); then
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
fi

# -------------------------------------------------------------------
# Aliases
# -------------------------------------------------------------------
alias gs-='git switch -'
alias gstt='git status --untracked=no'
alias gap='git add -p'
alias gcp='git checkout -p'
alias gri='git rebase -i'
alias grc='git rebase --continue'
alias gpp='git log --pretty=format:"%h%x09%an%x09%ad%x09%s"'

# Search: ag for interactive greps, rg where speed matters most.
alias agi='ag -i'

(( $+commands[thefuck] )) && eval "$(thefuck --alias)"

# -------------------------------------------------------------------
# Machine-local overrides. Keep tokens, credentials and employer-specific
# aliases here - this file is gitignored and never leaves the machine.
# See .zshrc.local.example in the dotfiles repo for the template.
# -------------------------------------------------------------------
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
