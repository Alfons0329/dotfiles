# dotfiles

One command turns a bare machine into my working environment. Same script on a
headless Ubuntu build server and on a MacBook.

```sh
git clone https://github.com/<user>/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

It is idempotent — re-run it any time to pick up changes. Anything it would
overwrite in `$HOME` is moved to `<file>.bak.<timestamp>` first.

| OS | Status | Notes |
| --- | --- | --- |
| Ubuntu 22.04+ | Supported | Verified on every commit by a Docker build from a bare image |
| Debian | Supported | Same apt path as Ubuntu |
| macOS (Apple Silicon & Intel) | Supported | Installs Homebrew if missing |

Headless servers need no flags: with no `DISPLAY`, `--minimal` turns itself on
and the GUI modules are skipped.

## Options

```
--dry-run, -n        Print every command that would run. Changes nothing.
--minimal            Skip the desktop module (fonts, terminal, GUI apps).
--only <modules>     Run only these, comma-separated. e.g. --only editor
--skip <modules>     Run everything except these.
--no-lsp-servers     Skip language servers (they install by default).
--ghostty-build      macOS: build the patched Ghostty without being asked.
--insecure, -k       Disable TLS verification, for TLS-inspecting proxies.
--powerline          Use the bullet-train zsh theme instead of starship.
--theme <name>       Editor + terminal colorscheme: tokyonight (default), kanagawa, or ayu-dark. Applies the same name to Neovim and Ghostty.
--yes, -y            Never prompt.
--help, -h
```

| Env var | Default | Purpose |
| --- | --- | --- |
| `NVIM_VERSION` | `v0.12.4` | Neovim release tag, or `latest`. See [Neovim](#neovim). |
| `DOTFILES_THEME` | `tokyonight` | Colorscheme for Neovim + Ghostty: `tokyonight`, `kanagawa`, or `ayu-dark`. |
| `DRY_RUN` | `0` | Same as `--dry-run`. |

Modules run in this order, and each is also a standalone script:

| Module | What it does |
| --- | --- |
| `packages` | System packages from `packages/*.txt`, locale |
| `shell` | zsh, oh-my-zsh, starship prompt (or bullet-train with `--powerline`), plugins, login shell |
| `tmux` | oh-my-tmux + tmux-resurrect |
| `editor` | Neovim + its Lua config; a separate `.vimrc` for plain vim |
| `tools` | fzf with key bindings, Node.js |
| `claude` | Claude Code, ccstatusline, completion notifications |
| `desktop` | macOS only: terminal, fonts, system monitor, iTerm2 profile |
| `ghostty` | macOS only: opt-in patched Ghostty build — [asks first](#patched-ghostty-macos) |

## What gets installed

**Shell** — [zsh](https://www.zsh.org/) with
[oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh),
[starship](https://starship.rs) as the prompt (`--powerline` swaps in the
[bullet-train](https://github.com/caiogondim/bullet-train.zsh) theme instead),
[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) and
[zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting).

**Terminal multiplexer** — [oh-my-tmux](https://github.com/gpakosz/.tmux) with
[tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) (`prefix
Ctrl-s` saves a session, `prefix Ctrl-r` restores it).

**Editor** — [Neovim](https://neovim.io/) with
[lazy.nvim](https://github.com/folke/lazy.nvim),
[snacks.nvim](https://github.com/folke/snacks.nvim) (fuzzy picker, file
explorer, indent guides, terminal, lazygit, symbol highlighting),
[tokyonight](https://github.com/folke/tokyonight.nvim),
[lualine](https://github.com/nvim-lualine/lualine.nvim),
[bufferline](https://github.com/akinsho/bufferline.nvim),
[gitsigns](https://github.com/lewis6991/gitsigns.nvim),
[nvim-autopairs](https://github.com/windwp/nvim-autopairs),
[treesitter](https://github.com/nvim-treesitter/nvim-treesitter), native LSP via
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) +
[mason](https://github.com/williamboman/mason.nvim), completion via
[blink.cmp](https://github.com/saghen/blink.cmp), and
[copilot.lua](https://github.com/zbirenbaum/copilot.lua).

One plugin does a lot of that work: snacks replaces what used to be telescope,
plenary, telescope-fzf-native and nvim-tree. That is worth it here for a reason
beyond tidiness — `telescope-fzf-native` compiles C at install time, so dropping
it removes a build step from a setup that has to work on a fresh box behind a
corporate proxy.

**Command line** — [fzf](https://github.com/junegunn/fzf),
[ripgrep](https://github.com/BurntSushi/ripgrep),
[the_silver_searcher](https://github.com/ggreer/the_silver_searcher) (`ag`),
[bat](https://github.com/sharkdp/bat), [jq](https://jqlang.github.io/jq/),
[tig](https://jonas.github.io/tig/), Node.js.

**AI tooling** — [Claude Code](https://claude.com/claude-code),
[ccstatusline](https://www.npmjs.com/package/ccstatusline), and a Stop-hook
notifier that announces when a turn finishes (Notification Center on macOS,
`notify-send` on a Linux desktop, OSC 9 to the terminal from a VM or over SSH).

## Key bindings

fzf's shell integration, which is the reason `--all` matters more than the
binary itself:

| Key | Action |
| --- | --- |
| `Ctrl+R` | Fuzzy-search shell history |
| `Ctrl+T` | Insert a file path at the cursor (previewed with `bat`) |
| `Alt+C` | `cd` into a subdirectory |

`Ctrl+T` uses `rg --files` so it respects `.gitignore`.

In Neovim. Leader is `Space`, and the right-hand column is the VSCode key the
binding is imitating:

| Key | Action | VSCode |
| --- | --- | --- |
| `<leader>ff` / `Ctrl+P` | Find files | `Ctrl+P` |
| `<leader>fg` | Grep the project | `Ctrl+Shift+F` |
| `Alt+Shift+F` | Grep the word under the cursor, or the selection | select, then `Ctrl+Shift+F` |
| `<leader>fr` | Recent files | Open Recent |
| `<leader>fb` | Open buffers | `Ctrl+Tab` |
| `<leader>gl` | Git log | GitLens history |
| `<leader>gg` | Lazygit | — |
| `Ctrl+B` / `Ctrl+N` | Toggle the side pane | `Ctrl+B` |
| `Ctrl+\` | Toggle a terminal | ``Ctrl+` `` |
| `F12` / `Shift+F12` | Definition / references | `F12` / `Shift+F12` |
| `gd` `gy` `gi` `gr` `K` | Definition / type / implementation / references / hover | — |
| `F2` | Rename symbol | `F2` |
| `Ctrl+.` | Code action | `Ctrl+.` |
| `Ctrl+S` | Save | `Ctrl+S` |
| `Ctrl+/` | Toggle comment | `Ctrl+/` |
| `Ctrl+PageDown` / `Ctrl+Tab` | Next editor tab | `Ctrl+Tab` |
| `Alt+1` … `Alt+9` | Jump to editor tab N | `Ctrl+1` … `Ctrl+9` |
| `]]` / `[[` | Next / previous use of the symbol under the cursor | `F2`-style highlight |
| `Tab` `Shift+Tab` `Enter` | Cycle and accept completions | same |
| `Ctrl+J` | Accept a Copilot suggestion | `Tab` |

The side pane opens automatically at startup, like VSCode's explorer, with focus
left in the file.

### Why these keys and not the literal VSCode ones

A terminal cannot transmit every chord an editor GUI can, and picking the wrong
one breaks something silently rather than loudly:

- **`Cmd+Shift+F` works on the Mac anyway.** macOS never delivers a `Cmd` chord
  to a terminal program, so both terminal emulators are configured to translate
  it into `Alt+Shift+F` — [a `keybind` line](home/.config/ghostty/config) in
  Ghostty, a key mapping in the iTerm2 profile. One Neovim mapping then serves
  the Mac and the Linux box, and `Alt+Shift+F` keeps working over SSH inside
  tmux where no `Cmd` key exists.
- **Bare `Tab` is not remapped.** In normal mode `<Tab>` *is* `<C-i>` — the same
  byte — so binding it to editor-tab cycling would quietly kill jumplist-forward.
  `Ctrl+Tab` is bound and does work in Ghostty, but only under the kitty keyboard
  protocol, which tmux 3.2a does not pass through; `Ctrl+PageDown` is the pair
  that always works.
- **`Ctrl+Shift+P` / `Ctrl+Shift+F` are not bound**, because without that same
  protocol they are indistinguishable from `Ctrl+P` / `Ctrl+F` and would shadow
  them.
- **`Ctrl+S` needs `stty -ixon`**, which `.zshrc` sets. Otherwise the terminal
  eats it as XOFF and freezes the display until `Ctrl+Q`.
- **`Ctrl+B` gives up full-page-back** for the sidebar. `Ctrl+U` remains as the
  half-page equivalent.

## What lands in `$HOME`

Everything is a symlink back into this repo, so `git pull` updates your live
config:

```
~/.zshrc                -> home/.zshrc
~/.tmux.conf            -> ~/.tmux/.tmux.conf        (upstream oh-my-tmux)
~/.tmux.conf.local      -> home/.tmux.conf.local
~/.vimrc                -> home/.vimrc
~/.config/nvim/         -> home/.config/nvim/
~/.config/ghostty/config-> home/.config/ghostty/config

# macOS only, and only when iTerm2 is already installed:
~/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json
```

`~/.vimrc` and `~/.config/nvim/` are **completely independent**. Neovim does not
source `~/.vimrc`, and nothing in the Lua config refers to it. That separation
is deliberate: sharing a config between the two is how you end up with two
statusline plugins writing to `&statusline` from competing autocmds, so the
statusline changes style every time you save. One owner per concern.

## Secrets and machine-local settings

`~/.zshrc.local` is sourced last by `~/.zshrc`, is **gitignored**, and is seeded
once from `home/.zshrc.local.example`. Re-running the installer never touches it.

Everything machine-specific goes there and nowhere else:

- API tokens and credentials
- employer-specific hosts, profiles, project paths
- aliases that only make sense on one machine

The tracked `.zshrc` is a public file. If you are about to add a secret to it,
that is the signal to put it in `~/.zshrc.local` instead. `test/verify.sh`
enforces this by failing if anything resembling an exported credential appears
in `~/.zshrc`.

The other three tools follow the same pattern. Each file is optional, absent by
default, gitignored, loaded last, and never touched by the installer:

| Tool | File | Holds |
|---|---|---|
| zsh | `~/.zshrc.local` | shell config, secrets |
| tmux | `~/.tmux.conf.user` | tmux commands, e.g. `set -g status-style ...` |
| Neovim | `~/.config/nvim/lua/config/local.lua` | any Lua, e.g. `vim.cmd.colorscheme(...)` |
| Ghostty | `~/.config/ghostty/ghostty-local.conf` | Ghostty settings, e.g. `theme = Catppuccin Mocha` |

Use these to deviate on one machine rather than editing a tracked file — the
tracked ones are symlinks into this repo, so editing them dirties your checkout
and gets overwritten on the next pull.

Two caveats worth knowing:

- `~/.tmux.conf.user` takes tmux **commands**, not oh-my-tmux's
  `tmux_conf_theme_*` variables. Those are read out of `.tmux.conf.local`
  specifically, so setting one anywhere else does nothing.
- Neovim's `local.lua` is the one file that lives *inside* the repo
  (`~/.config/nvim` is a single symlink to `home/.config/nvim`). It is
  gitignored, but it will show up in that directory rather than in `$HOME`.

## Neovim

`NVIM_VERSION` is pinned rather than tracking `latest`, because Neovim's release
binaries are linked against whatever glibc their CI image happens to ship.
Probing a real `ubuntu:22.04` container (glibc 2.35) gave:

| Release | On glibc 2.35 |
| --- | --- |
| `v0.10.4` | Fails — requires `GLIBC_2.38` |
| `v0.11.0` … `v0.12.4` | Runs |

So the floor on Ubuntu 22.04 is `v0.11.0`, which is also blink.cmp's minimum.
The default is `v0.12.4`. If the pinned build will not run, the installer stops
with the glibc mismatch spelled out rather than falling back to the distro
package — apt on 22.04 ships Neovim 0.6.1, far too old to load this config, and
failing loudly beats a wall of Lua errors.

```sh
NVIM_VERSION=v0.11.0 ./install.sh --only editor   # older glibc
NVIM_VERSION=latest  ./install.sh --only editor   # newest, at your own risk
```

Language servers install by default — without them nothing completes, jumps to a
definition, or renames a symbol, which is most of the point. They are still the
largest and most network-dependent step, so a failure only warns rather than
failing the run:

```sh
./install.sh --no-lsp-servers   # skip them (~300-600 MB)
```

`nvim-treesitter` is pinned to its `master` branch. The default branch is now
`main`, a rewrite that no longer ships the `nvim-treesitter.configs` module this
config drives — an unpinned clone throws on every file open and leaves you with
no syntax highlighting at all. `master` also keeps `auto_install`, so a language
that is not in the list still highlights itself the first time you open one.

**Parsers finish installing lazily, and that is deliberate.** `:TSUpdate` runs
at install time but is asynchronous, so nvim exits with most parsers still
building; the first time you open, say, a Python file, its parser compiles in
the background and highlighting appears a moment later. Forcing them all to
build up front was tried and is much worse — these are multi-megabyte generated
C files (`typescript`'s `parser.c` is 17.5 MB, `bash`'s is 9.9 MB) and
compiling the set serially took over 27 minutes with no output. That does not
belong in a script whose promise is that you run it once.

## Terminals

The powerline glyphs in the tmux status bar (and, with `--powerline`, the
bullet-train zsh prompt) need **two** things, and both failure modes look
identical — a row of boxes or underscores. starship, the default prompt, uses
the same Nerd Font glyph set as the tmux/lualine icons below, so it needs no
separate font and no `--powerline`-only cask:

1. **A patched font in the terminal emulator** — the machine you sit at, not the
   box you SSH into. `font-roboto-mono-nerd-font` is installed on macOS and set
   as the default in both the Ghostty config and the iTerm2 profile. It is the
   Nerd Font build rather than the plain Powerline one because Neovim's
   statusline and file tree also draw devicons, which the Powerline build does
   not carry — Ghostty hides that by falling back to another installed font for
   a missing glyph, iTerm2 does not and draws `[?]` boxes.
2. **A UTF-8 locale in the shell that starts tmux.** tmux substitutes `_` for
   every multibyte character when `LANG`/`LC_ALL` is unset or `POSIX`, and
   `update-locale` alone does not fix it: that writes `/etc/default/locale`,
   which only PAM reads, so a container shell and plenty of SSH logins never see
   it. `.zshrc` sets `LANG` for exactly this reason.

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
  `colors#8`, so everything collapses onto the terminal's 8-colour ANSI palette.

`.zshrc` repairs both: an unresolvable `$TERM`, or a bare `xterm`, is upgraded
to `xterm-256color`. `home/.tmux.conf.local` then declares truecolor with
`set -as terminal-features ",*:RGB"` — by capability, not by terminal *name*.
An earlier version used `terminal-overrides ",*256col*:Tc"`, which can only ever
match a terminal whose `$TERM` contains `256col`; that matched `xterm-256color`
and nothing else in play, which is exactly why the two terminals disagreed. The
`Tc` line stays for tmux < 3.2, which has no `terminal-features`.

Both are declared directly rather than through oh-my-tmux's own
`tmux_conf_theme_24b_colour` auto-detection: that logic runs as a backgrounded
startup job and was confirmed, by hand in the Docker test container, to not
reliably see the setting in time — 5/5 tries, even after a 2 second wait.
Separately, `.zshrc` exports `COLORTERM=truecolor` unconditionally, because
`docker exec -it` / `docker run -it` do not forward host environment variables
the way a real terminal or SSH session does.

Both terminals are themed to match Neovim, so `ls`, `git` and `grep` output no
longer clash with the editor in the same window. The theme is chosen by
`install.sh --theme tokyonight|kanagawa|ayu-dark` (default `tokyonight`) and
applies the same name to both editors: Neovim loads the matching colorscheme
plugin, and Ghostty uses its built-in theme of that name (`TokyoNight Night`,
`Kanagawa Wave`, or `Ayu`). The iTerm2 dynamic profile still spells the
tokyonight palette out per channel, since iTerm2 has no theme concept. To use
something else on one machine, see the override files above.

The tmux status bar reads: session name on the left, the window list in the
middle, and the clock plus the current user on the right — `#{root}` appends a
blinking `!` so a root shell is obvious.

### Patched Ghostty (macOS)

Optional, and the installer asks before doing anything. In bracketed paste mode
Ghostty passes pasted newlines through as LF where Terminal.app converts them to
CR, so pasting two commands into a shell lands them in the edit buffer as one
line instead of running as two. The fix adds a
`clipboard-paste-bracketed-safe-newline` option, and it is **not upstream** —
Ghostty's own `clipboard-paste-bracketed-safe` is a different, paste-protection
option. It lives in a public fork, [`kitknox/ghostty`](https://github.com/kitknox/ghostty),
branch `fix/bracketed-paste-newline-compat` (see
[discussion #9592](https://github.com/ghostty-org/ghostty/discussions/9592)).

```sh
./install.sh --only ghostty --ghostty-build
```

It installs Xcode 26.3 via [`xcodes`](https://github.com/XcodesOrg/xcodes) —
Apple gates the download behind a developer login, so it asks for an Apple ID
once and nothing more automatic is possible. The version pin exists because
Ghostty fails to link with anything newer (upstream issue #11991). Zig is pinned
to the exact `minimum_zig_version` from `build.zig.zon` rather than whatever
`brew install zig` currently is.

The resulting option only exists in the patched build, so it is written to
`~/.config/ghostty/ghostty-local.conf` — an optional include, untracked and
gitignored — rather than the tracked config, which has to stay valid on a stock
Ghostty.

## After installing

1. `exec zsh`
2. `nvim`, then `:Copilot auth` — one-time GitHub login
3. `claude` — one-time Claude Code login

## Verifying

`test/verify.sh` asserts behaviour rather than presence — it checks that
`Ctrl+R` is actually bound to `fzf-history-widget`, that lualine really owns the
statusline, that the shell exports a UTF-8 locale, that treesitter attaches a
highlighter to a real buffer, and that no old framework has crept back in:

```sh
./test/verify.sh        # against the current machine
./test/shellcheck.sh    # lint every script
./install.sh --dry-run  # print everything that would happen
```

One check earns its place more than the rest. Every other Neovim assertion runs
`nvim --headless +qa`, which never reads a buffer — so nothing lazy-loaded on
`BufReadPre` ever runs, and a config that crashed on every single file open once
passed the whole suite. There is now a check that opens a real file and demands
silence.

The Ubuntu path is proven end to end by a Docker build from a bare image. The
base image gets `sudo` and a normal user account and nothing else — every tool
and config has to come from `install.sh`, or the build fails:

```sh
./test/docker-test.sh            # build + verify
./test/docker-test.sh --with-lsp # same, plus language servers
./test/docker-test.sh --shell    # then drop into the container
```

The routine build passes `--no-lsp-servers` to stay quick; `--with-lsp`
exercises the path a real machine takes. macOS-only work — the iTerm2 profile
and the Ghostty build — is covered by `--dry-run` and `shellcheck` only.

## Credits

Built on the work of [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh),
[starship](https://starship.rs),
[bullet-train.zsh](https://github.com/caiogondim/bullet-train.zsh),
[oh-my-tmux](https://github.com/gpakosz/.tmux),
[tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect),
[lazy.nvim](https://github.com/folke/lazy.nvim),
[snacks.nvim](https://github.com/folke/snacks.nvim),
[tokyonight](https://github.com/folke/tokyonight.nvim), and the Neovim plugin
authors listed above.

The optional Ghostty build uses the bracketed-paste fix from
[kitknox/ghostty](https://github.com/kitknox/ghostty), a public fork of
[ghostty](https://github.com/ghostty-org/ghostty).
