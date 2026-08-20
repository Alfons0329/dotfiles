#!/usr/bin/env bash
# test/verify.sh - assert that install.sh actually produced a working
# environment. Exits non-zero on the first category of failure, so it can be a
# Docker build step.
#
# Checks behaviour, not just presence: a `command -v fzf` that passes while
# Ctrl+R does nothing is exactly the bug this is meant to catch.

PASS=0
FAIL=0
FAILED_CHECKS=()

if [ -t 1 ]; then
    G=$'\033[0;32m'; R=$'\033[0;31m'; Y=$'\033[1;33m'; D=$'\033[2m'; N=$'\033[0m'
else
    G=""; R=""; Y=""; D=""; N=""
fi

IS_MACOS=false
[ "$(uname -s)" = "Darwin" ] && IS_MACOS=true

check() {
    local desc="$1" cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        printf '  %s[pass]%s %s\n' "$G" "$N" "$desc"
        PASS=$((PASS + 1))
    else
        printf '  %s[FAIL]%s %s\n' "$R" "$N" "$desc"
        FAIL=$((FAIL + 1))
        FAILED_CHECKS+=("$desc")
    fi
}

section() { printf '\n%s== %s ==%s\n' "$Y" "$1" "$N"; }

# ------------------------------------------------------------------
section "Core tools"
# ------------------------------------------------------------------
check "zsh"                  "command -v zsh"
check "git"                  "command -v git"
check "tmux"                 "command -v tmux"
check "curl"                 "command -v curl"
check "wget"                 "command -v wget"
check "jq"                   "command -v jq"
check "tig"                  "command -v tig"
check "vim"                  "command -v vim"
check "bat (or batcat shim)" "command -v bat || command -v batcat"
check "node >= 18"           '[ "$(node --version | sed "s/^v\([0-9]*\).*/\1/")" -ge 18 ]'

# ------------------------------------------------------------------
section "Search tools"
# ------------------------------------------------------------------
check "ag (the_silver_searcher)" "command -v ag && ag --version"
check "rg (ripgrep)"             "command -v rg && rg --version"
check "fd (or fdfind shim)"      "command -v fd || command -v fdfind"
check "fzf on PATH"              "command -v fzf || [ -x $HOME/.fzf/bin/fzf ]"

# apt's fzf is 0.29 and lacks features the config relies on. Assert we got a
# modern build, not merely "a" build.
check "fzf >= 0.40" '
    v=$( (command -v fzf >/dev/null && fzf --version || '"$HOME"'/.fzf/bin/fzf --version) 2>/dev/null | awk "{print \$1}" )
    maj=${v%%.*}; rest=${v#*.}; min=${rest%%.*}
    [ "$maj" -gt 0 ] || [ "$min" -ge 40 ]'

# The real proof that Ctrl+R works. ~/.fzf.zsh existing is necessary but not
# sufficient; the widget has to actually be bound in an interactive zsh.
check "fzf.zsh written to \$HOME" "[ -f $HOME/.fzf.zsh ]"
check "Ctrl+R -> fzf-history-widget" \
      "zsh -ic 'bindkey \"^R\"' 2>/dev/null | grep -q fzf-history-widget"
check "Ctrl+T -> fzf-file-widget" \
      "zsh -ic 'bindkey \"^T\"' 2>/dev/null | grep -q fzf-file-widget"

# ------------------------------------------------------------------
section "zsh"
# ------------------------------------------------------------------
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
check "oh-my-zsh installed"        "[ -d $HOME/.oh-my-zsh ]"
check "zsh-autosuggestions"        "[ -d $ZSH_CUSTOM/plugins/zsh-autosuggestions ]"
check "zsh-syntax-highlighting"    "[ -d $ZSH_CUSTOM/plugins/zsh-syntax-highlighting ]"
check ".zshrc is a symlink"        "[ -L $HOME/.zshrc ]"
check ".zshrc.local seeded"        "[ -f $HOME/.zshrc.local ]"
check "interactive zsh starts cleanly" "zsh -ic exit"

# Which prompt is expected depends on --powerline, recorded by
# modules/10-shell.sh in ~/.zsh_theme_mode - branch on that rather than
# hardcoding one theme, so this check is honest about whichever install.sh was
# actually run.
if [ -f "$HOME/.zsh_theme_mode" ] && grep -q 'DOTFILES_PROMPT="bullet-train"' "$HOME/.zsh_theme_mode"; then
    check "bullet-train theme"    "[ -f $ZSH_CUSTOM/themes/bullet-train.zsh-theme ]"
    check "theme is bullet-train" "zsh -ic 'echo \$ZSH_THEME' 2>/dev/null | grep -q bullet-train"
else
    check "starship installed"       "command -v starship || [ -x $HOME/.local/bin/starship ]"
    check "starship owns the prompt" "zsh -ic 'type starship' 2>/dev/null | grep -q starship"
fi
check "prompt renders" \
      "zsh -ic 'echo \$PROMPT' 2>/dev/null | grep -q ."

# tmux replaces every multibyte character with '_' when the client locale is not
# UTF-8, which is what turned the powerline separators in the status bar and the
# prompt into a row of underscores. update-locale alone does not fix it: it
# writes /etc/default/locale, which only PAM reads, so a container shell and
# plenty of SSH logins never see it. .zshrc sets LANG for exactly this reason.
check "interactive shell has a UTF-8 locale" \
      "zsh -ic 'echo \$LANG' 2>/dev/null | grep -qiE 'utf-?8'"
# Ctrl+S must reach the editor rather than being eaten as XOFF.
check "flow control disabled (Ctrl+S usable)" \
      "grep -q 'stty -ixon' $HOME/.zshrc"
# `docker exec -it` / `docker run -it` do not forward the host's environment,
# so a real terminal's COLORTERM never reaches a container shell on its own.
check "COLORTERM exported" \
      "zsh -ic 'echo \$COLORTERM' 2>/dev/null | grep -qi truecolor"

# TERM normalisation. Two separate real failures, one check each.
#
# Ghostty sets TERM=xterm-ghostty, an entry that ships only inside Ghostty.app -
# it is in neither Ubuntu 22.04's terminfo database nor this container's, so ssh
# and docker sessions opened from Ghostty land on a TERM nothing can look up.
# Any unknown value stands in for it here; naming xterm-ghostty specifically
# would pass on a machine that happened to have it and prove nothing.
check "unknown TERM falls back to a usable entry" \
      "TERM=not-a-real-terminal zsh -ic 'echo \$TERM' 2>/dev/null | tr -d '\\r' | grep -qx xterm-256color"
# And `docker run -t` hardcodes TERM=xterm regardless of the host's TERM -
# verified by experiment. xterm's terminfo declares colors#8, which is what
# collapsed a 24-bit Neovim into the terminal's 8-colour ANSI palette.
check "docker's bare TERM=xterm is upgraded" \
      "TERM=xterm zsh -ic 'echo \$TERM' 2>/dev/null | tr -d '\\r' | grep -qx xterm-256color"

# ------------------------------------------------------------------
section "tmux"
# ------------------------------------------------------------------
check "oh-my-tmux cloned"       "[ -d $HOME/.tmux ]"
check ".tmux.conf symlinked"    "[ -L $HOME/.tmux.conf ]"
check ".tmux.conf.local linked" "[ -L $HOME/.tmux.conf.local ]"
check "tmux-resurrect"          "[ -d $HOME/.tmux/plugins/tmux-resurrect ]"
check "mouse mode on"           "grep -q '^set -g mouse on' $HOME/.tmux.conf.local"
check "vi copy mode"            "grep -q '^setw -g mode-keys vi' $HOME/.tmux.conf.local"
check "MouseDragEnd unbound"    "grep -q 'unbind -T copy-mode-vi MouseDragEnd1Pane' $HOME/.tmux.conf.local"
check "bracketed paste passthrough" "grep -q 'smBP' $HOME/.tmux.conf.local"
check "tmux config parses"      "tmux -f $HOME/.tmux.conf new-session -d -s verify && tmux kill-session -t verify"

# Status bar: session on the left, clock and user on the right, and none of the
# things that were removed. The wttr.in check matters most - that was a shell-out
# firing on every status refresh, which hangs the redraw behind a proxy.
check "24-bit colour enabled"   "grep -q '^tmux_conf_theme_24b_colour=true' $HOME/.tmux.conf.local"
# The line above only proves the setting exists in the file - it passed the
# whole time this was broken. oh-my-tmux's own 24-bit logic (_apply_24b) runs
# as a backgrounded startup job and was verified, by hand in this container, to
# not reliably pick up tmux_conf_theme_24b_colour in time: terminal-overrides
# never gained the Tc entry on a fresh session, 5/5 tries. So this asserts the
# actual behaviour a real session depends on - that a freshly started tmux
# server declares truecolor support for 256-colour terminal types - not just
# that the line requesting it is present.
check "tmux truecolor actually applied to a live session" \
      "tmux new-session -d -s verify_24b && tmux show -g terminal-overrides | grep -Eq '256col.*:Tc' && tmux kill-session -t verify_24b"
# The check above still only covers terminals whose TERM contains "256col".
# That pattern matches xterm-256color and nothing else in play: not
# xterm-ghostty, not the bare "xterm" docker hands out. Declaring RGB for "*"
# is what makes truecolor independent of what the terminal calls itself, and
# that is the fix for the same tmux session looking right from iTerm2 and
# 8-colour from Ghostty. terminal-features needs tmux >= 3.2 (22.04 ships 3.2a).
check "tmux declares RGB for any terminal name" \
      "tmux new-session -d -s verify_rgb && tmux show -g terminal-features | grep -q '[*]:RGB' && tmux kill-session -t verify_rgb"
# ~/.tmux.conf.user is the machine-local override hook, and whether it wins is
# purely a question of oh-my-tmux's ordering. Sourcing it from .tmux.conf.local
# looked obviously correct and was wrong: _apply_configuration() runs afterwards
# and overwrites every style option, so a user file setting bg=#040506 lost to
# the theme. It is loaded from a session-created hook instead. Assert the
# outcome against a live server rather than grepping for the hook line - the
# grep would have passed just as happily with the broken version.
#
# Runs in a subshell: check() eval's this string in the current shell, so a bare
# `exit` would take verify.sh down with it rather than failing one check.
check "machine-local tmux.conf.user overrides win over the theme" \
      "$(cat <<'TMUXUSER'
      (
        _bak=""
        if [ -e "$HOME/.tmux.conf.user" ]; then
            _bak="$HOME/.tmux.conf.user.verify-bak"
            mv "$HOME/.tmux.conf.user" "$_bak"
        fi
        printf 'set -g status-style "fg=#010203,bg=#040506"\n' > "$HOME/.tmux.conf.user"
        tmux -f "$HOME/.tmux.conf" new-session -d -s verify_user
        sleep 2
        _got="$(tmux show -gv status-style 2>/dev/null)"
        tmux kill-session -t verify_user 2>/dev/null
        rm -f "$HOME/.tmux.conf.user"
        [ -n "$_bak" ] && mv "$_bak" "$HOME/.tmux.conf.user"
        case "$_got" in *040506*) exit 0 ;; *) exit 1 ;; esac
      )
TMUXUSER
)"
check "status left is the session name only" \
      "grep -q '^tmux_conf_theme_status_left=.*#S' $HOME/.tmux.conf.local && ! grep -q '^tmux_conf_theme_status_left=.*uptime' $HOME/.tmux.conf.local"
check "status right has clock + user" \
      "grep -E '^tmux_conf_theme_status_right=' $HOME/.tmux.conf.local | grep -q '%R' && grep -E '^tmux_conf_theme_status_right=' $HOME/.tmux.conf.local | grep -q 'username'"
# Anchored to the assignment, not the file: the comment above it explains why
# the wttr.in shell-out was removed, and a whole-file grep cannot tell the
# explanation apart from the thing being explained.
check "no shell-out in the status bar" \
      "! grep -E '^tmux_conf_theme_status_(left|right)=' $HOME/.tmux.conf.local | grep -q '#('"

# ------------------------------------------------------------------
section "Neovim"
# ------------------------------------------------------------------
check "nvim installed"        "command -v nvim"
check "nvim >= 0.11"          '[ "$(nvim --version | head -1 | sed "s/^NVIM v[0-9]*\.\([0-9]*\).*/\1/")" -ge 11 ]'
check "config dir symlinked"  "[ -L $HOME/.config/nvim ]"
check "init.lua present"      "[ -f $HOME/.config/nvim/init.lua ]"
check "lazy.nvim bootstrapped" "[ -d $HOME/.local/share/nvim/lazy/lazy.nvim ]"

# The colorscheme is chosen by install.sh --theme and recorded in
# ~/.dotfiles_theme (default tokyonight). Resolve the plugin + colorscheme
# name this machine expects, so the checks below stay honest for any theme
# instead of passing for the wrong reason when someone switches.
DOTFILES_THEME="tokyonight"
# shellcheck source=/dev/null  # the theme marker is a runtime file, absent at lint time
[ -f "$HOME/.dotfiles_theme" ] && source "$HOME/.dotfiles_theme"
case "$DOTFILES_THEME" in
    tokyonight) CS_PLUGIN="tokyonight.nvim";   CS_NAME="tokyonight" ;;
    kanagawa)   CS_PLUGIN="kanagawa.nvim";     CS_NAME="kanagawa"   ;;
    ayu-dark)   CS_PLUGIN="neovim-ayu";        CS_NAME="ayu"        ;;
    *)          CS_PLUGIN="tokyonight.nvim";   CS_NAME="tokyonight" ;;
esac

for plugin in snacks.nvim lualine.nvim bufferline.nvim \
              nvim-autopairs gitsigns.nvim nvim-treesitter nvim-lspconfig \
              blink.cmp mason.nvim copilot.lua; do
    check "plugin: $plugin" "[ -d $HOME/.local/share/nvim/lazy/$plugin ]"
done
check "plugin: $CS_PLUGIN (theme)" "[ -d $HOME/.local/share/nvim/lazy/$CS_PLUGIN ]"

# snacks replaced these four. Assert they are gone rather than merely unused, so
# a stale lazy directory cannot quietly reintroduce a second file tree or a
# second fuzzy finder competing for the same keys.
for gone in telescope.nvim telescope-fzf-native.nvim nvim-tree.lua indent-blankline.nvim; do
    check "replaced by snacks: $gone" "[ ! -d $HOME/.local/share/nvim/lazy/$gone ]"
done

check "nvim starts with no errors" \
      "[ -z \"\$(nvim --headless '+qa' 2>&1)\" ]"

# The check whose absence let a crash-on-every-file-open ship: everything above
# uses `--headless +qa`, which never reads a buffer, so no plugin lazy-loaded on
# BufReadPre/BufReadPost ever runs. Open a real file and demand silence.
check "nvim opens a real file with no errors" \
      "[ -z \"\$(nvim --headless -c 'edit $HOME/.config/nvim/init.lua' -c qa 2>&1)\" ]"

# nvim-treesitter's default branch is now `main`, a rewrite with no
# `nvim-treesitter.configs`; the config drives that module, so an unpinned clone
# throws and silently leaves you with no treesitter highlighting at all.
check "treesitter pinned to master" \
      "[ \"\$(git -C $HOME/.local/share/nvim/lazy/nvim-treesitter rev-parse --abbrev-ref HEAD)\" = master ]"
check "treesitter highlights a real buffer" \
      "nvim --headless -c 'edit $HOME/.config/nvim/init.lua' -c 'lua io.write(tostring(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil))' -c qa 2>&1 | grep -q true"

# Deliberately NOT asserting that every parser is compiled: `:TSUpdate` is
# async, and forcing it synchronous costs 27 minutes because these are multi-
# megabyte generated C files. What has to hold is that the mechanism which
# fetches the rest on demand is switched on.
check "treesitter auto_install enabled" \
      "grep -q 'auto_install = true' $HOME/.config/nvim/lua/plugins/editor.lua"

# lazy-loads on VeryLazy, which does not fire under --headless; force it so the
# assertion is deterministic rather than a race.
check "lualine owns the statusline" \
      "nvim --headless -c 'lua require(\"lazy\").load({plugins={\"lualine.nvim\"}}); io.write(vim.o.statusline or \"\")' -c qa 2>&1 | grep -q lualine"
# This file once shipped `section_separators = { left = "", right = "" }`
# directly beneath a comment describing them as powerline separators - the
# glyphs had been lost and the statusline rendered as flat rectangles. Grepping
# ui.lua could not catch that: the word "Powerline" is right there in the
# comment, which is failure mode 2 in CLAUDE.md.
#
# So render the thing and look at the output. Two details that are not
# obvious: the buffer must be a real file (a headless nvim with no buffer
# renders nothing useful), and vim.o.statusline is only ever
# "%#lualine_transparent#" under --headless because lualine treats an
# unfocused window as transparent - measured. lualine.statusline(true) asks it
# for the focused rendering directly. \238\130\176 is U+E0B0 in UTF-8, written
# as decimal escapes because bash 3.2 (what macOS ships) has no \u in $'...'.
check "lualine renders powerline separators" \
      "nvim --headless -c 'edit $HOME/.config/nvim/init.lua' -c 'lua require(\"lazy\").load({plugins={\"lualine.nvim\"}}); local s=vim.api.nvim_eval_statusline(require(\"lualine\").statusline(true),{winid=0}).str; io.write(tostring(s:find(\"\\238\\130\\176\",1,true)~=nil))' -c qa 2>&1 | grep -q true"
check "colorscheme is $CS_NAME" \
      "nvim --headless -c 'lua io.write(vim.g.colors_name or \"\")' -c qa 2>&1 | grep -q '$CS_NAME'"
# "I cannot see the cursorline" was a real complaint; assert it has a background.
check "cursorline is visible" \
      "nvim --headless -c 'lua io.write(tostring(vim.api.nvim_get_hl(0,{name=\"CursorLine\"}).bg))' -c qa 2>&1 | grep -qv '^nil$'"

# ------------------------------------------------------------------
section "VSCode-style bindings"
# ------------------------------------------------------------------
check "F12 -> definition"     "nvim --headless -c 'lua io.write(vim.fn.maparg(\"<F12>\",\"n\"))' -c qa 2>&1 | grep -q ."
check "F2 -> rename"          "nvim --headless -c 'lua io.write(vim.fn.maparg(\"<F2>\",\"n\"))' -c qa 2>&1 | grep -q ."
check "Ctrl+S -> save"        "nvim --headless -c 'lua io.write(vim.fn.maparg(\"<C-s>\",\"n\"))' -c qa 2>&1 | grep -q write"
check "Ctrl+B -> side pane"   "nvim --headless -c 'lua io.write(vim.fn.maparg(\"<C-b>\",\"n\"))' -c qa 2>&1 | grep -q ."
check "Alt+Shift+F -> project search" \
      "nvim --headless -c 'lua io.write(vim.fn.maparg(\"<M-F>\",\"n\"))' -c qa 2>&1 | grep -q ."
check "Ctrl+P -> find files"  "nvim --headless -c 'lua io.write(vim.fn.maparg(\"<C-p>\",\"n\"))' -c qa 2>&1 | grep -q ."
# The snacks modules the config actually depends on, rather than just the
# directory being present.
check "snacks picker + explorer live" \
      "nvim --headless -c 'lua io.write(tostring(Snacks ~= nil and Snacks.picker ~= nil and Snacks.explorer ~= nil))' -c qa 2>&1 | grep -q true"
check "snacks grep_word available (word-under-cursor search)" \
      "nvim --headless -c 'lua io.write(type(Snacks.picker.grep_word))' -c qa 2>&1 | grep -q function"
# Regression guard: in normal mode <Tab> IS <C-i>, so mapping it would silently
# break jumplist-forward. Editor tabs use Ctrl+PageDown / Ctrl+Tab instead.
check "bare Tab left unmapped (jumplist intact)" \
      "[ -z \"\$(nvim --headless -c 'lua io.write(vim.fn.maparg(\"<Tab>\",\"n\"))' -c qa 2>&1)\" ]"

# ------------------------------------------------------------------
section "Plain vim is independent of Neovim"
# ------------------------------------------------------------------
# The previous setup had nvim source ~/.vimrc through a VimScript framework,
# which is what let two statusline plugins and two colorschemes coexist and
# fight. These assertions exist so that regression cannot return unnoticed.
check ".vimrc is a symlink"          "[ -L $HOME/.vimrc ]"
check "no ~/.vim_runtime framework"  "[ ! -d $HOME/.vim_runtime ]"
check "no ~/.config/nvim/init.vim"   "[ ! -f $HOME/.config/nvim/init.vim ]"
# Ask Neovim what it actually loaded, rather than grepping the config for the
# string "vimrc" - the config *mentions* ~/.vimrc in a comment explaining why it
# deliberately does not load it, and a text search cannot tell those apart.
check "nvim does not load ~/.vimrc" \
      "! nvim --headless -c 'lua io.write(vim.fn.execute(\"scriptnames\"))' -c qa 2>&1 | grep -q '\.vimrc'"
check "no lightline installed"       "[ ! -d $HOME/.local/share/nvim/lazy/lightline.vim ]"
check "no vim-airline installed"     "[ ! -d $HOME/.local/share/nvim/lazy/vim-airline ]"
check "no coc.nvim installed"        "[ ! -d $HOME/.local/share/nvim/lazy/coc.nvim ]"
check "vim runs with its own config" "vim -es -u $HOME/.vimrc +qa"

# ------------------------------------------------------------------
section "Claude Code"
# ------------------------------------------------------------------
check "claude installed"        "command -v claude || [ -x $HOME/.local/bin/claude ]"
check "notifier script"         "[ -x $HOME/.local/bin/claude-notify.sh ]"
check "settings.json is valid"  "python3 -c 'import json;json.load(open(\"$HOME/.claude/settings.json\"))'"
check "statusLine configured"   "grep -q ccstatusline $HOME/.claude/settings.json"
check "Stop hook wired"         "grep -q claude-notify $HOME/.claude/settings.json"
check "eli5 output style linked"      "[ -L $HOME/.claude/output-styles/eli5.md ]"
check "eli5 output style frontmatter" "head -5 $HOME/.claude/output-styles/eli5.md | grep -qx 'name: ELI5'"

# ------------------------------------------------------------------
if $IS_MACOS; then
section "macOS extras"
check "homebrew"          "command -v brew"
check "ghostty app"       "[ -d /Applications/Ghostty.app ]"
check "ghostty config"    "[ -L $HOME/.config/ghostty/config ]"
check "powerline font"    "brew list --cask font-roboto-mono-for-powerline"
fi

# ------------------------------------------------------------------
section "No secrets in tracked config"
# ------------------------------------------------------------------
# ~/.zshrc is a tracked, world-readable file in a public repo. Anything
# resembling a credential in it is a defect; credentials belong in
# ~/.zshrc.local, which is gitignored.
check "no exported tokens/secrets/keys in .zshrc" \
      "! grep -qEi 'export[[:space:]]+[A-Z_]*(TOKEN|SECRET|PASSWORD|APIKEY|API_KEY)[[:space:]]*=' $HOME/.zshrc"
check ".zshrc sources ~/.zshrc.local" \
      "grep -q 'zshrc.local' $HOME/.zshrc"

# ------------------------------------------------------------------
printf '\n%s======================================%s\n' "$Y" "$N"
printf '  %s%d passed%s, %s%d failed%s\n' "$G" "$PASS" "$N" "$R" "$FAIL" "$N"
printf '%s======================================%s\n' "$Y" "$N"

if [ "$FAIL" -gt 0 ]; then
    printf '\n%sFailed checks:%s\n' "$R" "$N"
    printf '  - %s\n' "${FAILED_CHECKS[@]}"
    exit 1
fi
exit 0
