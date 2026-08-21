# Terminal, tmux & fonts

Everything between the editor and your eyes: the terminal emulator, tmux, and
the font/locale/colour chain that makes glyphs and colours survive the trip from
a MacBook to a bare Linux build server.

## The two requirements that both look like "broken font"

The powerline glyphs in the tmux status bar (and, with `--powerline`, the
bullet-train zsh prompt) need **two** things, and both failure modes look
identical — a row of boxes or underscores. starship, the default prompt, uses
the same Nerd Font glyph set as the tmux/lualine icons, so it needs no separate
font and no `--powerline`-only cask:

1. **A patched font in the terminal emulator** — the machine you sit at, not
   the box you SSH into. `font-roboto-mono-nerd-font` is installed on macOS and
   set as the default in both the Ghostty config and the iTerm2 profile. It is
   the Nerd Font build rather than the plain Powerline one because Neovim's
   statusline and file tree also draw devicons, which the Powerline build does
   not carry — Ghostty hides that by falling back to another installed font for
   a missing glyph, iTerm2 does not and draws `[?]` boxes.
2. **A UTF-8 locale in the shell that starts tmux.** tmux substitutes `_` for
   every multibyte character when `LANG`/`LC_ALL` is unset or `POSIX`, and
   `update-locale` alone does not fix it: that writes `/etc/default/locale`,
   which only PAM reads, so a container shell and plenty of SSH logins never
   see it. `.zshrc` sets `LANG` for exactly this reason.

## Truecolor: why the same session looks different from two terminals

A third, separate failure mode looks different — not missing glyphs, but a
Neovim colorscheme rendering in harsh, saturated primary colours instead of its
real palette. The giveaway is that it is **terminal-dependent**: the same tmux
session looks right attached from one terminal and wrong from another.

Neovim always emits 24-bit colour (`termguicolors` is hard-set). The loss
happens in tmux, which down-quantises unless it believes the terminal it is
inside supports truecolor — and tmux decides that from the terminal's terminfo
entry, looked up by `$TERM`. Two things break that:

- **The terminal has no terminfo entry at all.** Ghostty sets
  `TERM=xterm-ghostty`, which ships only inside `Ghostty.app`. It is not in
  Ubuntu 22.04's database, so every SSH or `docker` session opened from Ghostty
  starts on a `$TERM` nothing downstream can resolve.
- **`docker run -t` hardcodes `TERM=xterm`**, regardless of the host's `$TERM`
  and not overridable from the outside environment. `xterm`'s terminfo declares
  `colors#8`, so everything collapses onto the terminal's 8-colour ANSI
  palette.

`.zshrc` repairs both: an unresolvable `$TERM`, or a bare `xterm`, is upgraded
to `xterm-256color`. `home/.tmux.conf.local` then declares truecolor with
`set -as terminal-features ",*:RGB"` — by capability, not by terminal *name*.
An earlier version used `terminal-overrides ",*256col*:Tc"`, which can only
ever match a terminal whose `$TERM` contains `256col`; that matched
`xterm-256color` and nothing else in play, which is exactly why the two
terminals disagreed. The `Tc` line stays for tmux < 3.2, which has no
`terminal-features`.

Both are declared directly rather than through oh-my-tmux's own
`tmux_conf_theme_24b_colour` auto-detection: that logic runs as a backgrounded
startup job and was confirmed, by hand in the Docker test container, to not
reliably see the setting in time — 5/5 tries, even after a 2 second wait.
Separately, `.zshrc` exports `COLORTERM=truecolor` unconditionally, because
`docker exec -it` / `docker run -it` do not forward host environment variables
the way a real terminal or SSH session does.

## Theme

Both terminals are themed to match Neovim, so `ls`, `git` and `grep` output no
longer clash with the editor in the same window. The theme is chosen by
`install.sh --theme tokyonight|kanagawa|ayu-dark` (default `tokyonight`) and
applies the same name to both editors: Neovim loads the matching colorscheme
plugin, and Ghostty uses its built-in theme of that name (`TokyoNight Night`,
`Kanagawa Wave`, or `Ayu`). The iTerm2 dynamic profile still spells the
tokyonight palette out per channel, since iTerm2 has no theme concept. To use
something else on one machine, see the override files below.

## tmux keys (oh-my-tmux)

The prefix is `<C-b>`. Below, `<prefix>` means press-and-release `Ctrl+B`,
then the next key. tmux is configured by `~/.tmux.conf.local` (this repo) on
top of [oh-my-tmux](https://github.com/gpakosz/.tmux).

| Keys | What it does |
| --- | --- |
| `<prefix> -` / `<prefix> _` | split pane below / right |
| `<prefix> h j k l` | move between panes |
| `<prefix> H J K L` | resize the pane |
| `<prefix> <C-h>` / `<prefix> <C-l>` | previous / next **tmux window** |
| `<prefix> Tab` | jump back to the last-active window |
| `<prefix> 0…9` | jump straight to window N |
| `<prefix> c` / `<prefix> C-c` | new window / new session |
| `<prefix> m` | toggle mouse mode (scrolling vs. selecting) |
| `<prefix> <C-s>` / `<prefix> <C-r>` | tmux-resurrect: save / restore session |
| `<C-l>` (no prefix) | clear the screen **and** tmux's scrollback history |

tmux's own default keytable also binds `<prefix> <C-Up/Down/Left/Right>` to
`resize-pane`, same as on Windows/Linux — but on macOS, `Ctrl+Left`/`Ctrl+Right`
is Mission Control's "Move left/right a space" (`System Settings → Keyboard →
Keyboard Shortcuts → Mission Control`), which intercepts the chord before it
ever reaches the terminal, so tmux never sees it. Either free the shortcut
there, or just use **`<prefix> H J K L`** above — a bare letter, so macOS has
nothing to intercept.

A note on `<C-l>`: oh-my-tmux binds it globally (no prefix) to also wipe the
pane's history, so it is slightly heavier than a bare shell clear.

These are **tmux** windows and panes — a layer above Neovim's tabs and splits.
`<C-Tab>` cycles tmux's own windows, which is why it never reaches Neovim's
tabs inside tmux; see [NEOVIM.md](NEOVIM.md) for the editor-side keys that do.

### Machine-local tmux overrides

`~/.tmux.conf.user` (gitignored, loaded last, never touched by the installer)
takes tmux **commands**, not oh-my-tmux's `tmux_conf_theme_*` variables — those
are read out of `.tmux.conf.local` specifically, so setting one anywhere else
does nothing. It is loaded from a `session-created`/`client-attached` hook
rather than sourced in place, because oh-my-tmux's `_apply_configuration()`
runs *after* this file and would otherwise overwrite anything it sets.

## Ghostty (macOS)

The tracked `home/.config/ghostty/config` sets the font, the theme,
`macos-option-as-alt = true` (which is what makes every Alt chord in Neovim
reachable, including the `<M-1..9>` tab jumps), and a keybind that translates
`Cmd+Shift+F` into `ESC F` (`<M-F>`) — because macOS never delivers a Cmd chord
to a terminal program, and that translation survives tmux over SSH.

Machine-local overrides go in `~/.config/ghostty/ghostty-local.conf`
(gitignored, loaded last via `config-file = ?ghostty-local.conf`).

### Patched Ghostty

Optional, and the installer asks before doing anything. In bracketed paste mode
Ghostty passes pasted newlines through as LF where Terminal.app converts them
to CR, so pasting two commands into a shell lands them in the edit buffer as
one line instead of running as two. The fix adds a
`clipboard-paste-bracketed-safe-newline` option, and it is **not upstream** —
Ghostty's own `clipboard-paste-bracketed-safe` is a different, paste-protection
option. It lives in a public fork,
[`kitknox/ghostty`](https://github.com/kitknox/ghostty), branch
`fix/bracketed-paste-newline-compat` (see
[discussion #9592](https://github.com/ghostty-org/ghostty/discussions/9592)).

```sh
./install.sh --only ghostty --ghostty-build
```

It installs Xcode 26.3 via [`xcodes`](https://github.com/XcodesOrg/xcodes) —
Apple gates the download behind a developer login, so it asks for an Apple ID
once and nothing more automatic is possible. The version pin exists because
Ghostty fails to link with anything newer (upstream issue #11991). Zig is
pinned to the exact `minimum_zig_version` from `build.zig.zon` rather than
whatever `brew install zig` currently is.

The resulting option only exists in the patched build, so it is written to
`~/.config/ghostty/ghostty-local.conf` — an optional include, untracked and
gitignored — rather than the tracked config, which has to stay valid on a stock
Ghostty.

## iTerm2 (macOS, only if already installed)

A dynamic profile is dropped into
`~/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json` with the
same font and the tokyonight palette spelled out per channel (iTerm2 has no
theme concept). Its `Cmd+Shift+F` keymap is encoded as `"0x46-0x120000"`, a
best reading of iTerm2's plist format — if it does not fire, bind it once in
the GUI and read the real key back out of
`~/Library/Preferences/com.googlecode.iterm2.plist`.

## The status bar

The tmux status bar reads: session name on the left, the window list in the
middle, and the clock plus the current user on the right — `#{root}` appends a
blinking `!` so a root shell is obvious.
