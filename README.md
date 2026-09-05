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

## Documentation

The README is the starting point; each subsystem has its own page:

| Doc | Covers |
| --- | --- |
| **[docs/NEOVIM.md](docs/NEOVIM.md)** | Editor keys as a VSCode→Neovim map, and the tmux-safe subset (`gd`/`<C-o>`, `<M-1..9>`, `<C-n>` sidebar) |
| **[docs/TERMINAL.md](docs/TERMINAL.md)** | Ghostty, iTerm2, tmux keys, fonts, locale, truecolor, themes |
| **[docs/INSTALL.md](docs/INSTALL.md)** | Modules, package manifests, version pins, the test suite |
| **[docs/herdr-tmux-analogy.md](docs/herdr-tmux-analogy.md)** | herdr's model for a tmux user: workspace/tab/pane, agent state, and an ordinary day's workflow |
| **[docs/herdr-shortcut.md](docs/herdr-shortcut.md)** | herdr keys as a diff against oh-my-tmux — the seven that differ, and why the prefix can look dead |
| **[docs/herdr-loop-eng-tutorial.md](docs/herdr-loop-eng-tutorial.md)** | Running a staged, one-session-per-stage agent workflow on herdr instead of tmux windows |

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
| `NVIM_VERSION` | `v0.12.4` | Neovim release tag, or `latest`. See [docs/INSTALL.md](docs/INSTALL.md). |
| `DOTFILES_THEME` | `tokyonight` | Colorscheme for Neovim + Ghostty: `tokyonight`, `kanagawa`, or `ayu-dark`. |
| `DRY_RUN` | `0` | Same as `--dry-run`. |

Modules run in this order, and each is also a standalone script:

| Module | What it does |
| --- | --- |
| `packages` | System packages from `packages/*.txt`, locale |
| `shell` | zsh, oh-my-zsh, starship prompt (or bullet-train with `--powerline`), plugins, login shell |
| `tmux` | oh-my-tmux + tmux-resurrect |
| `editor` | Neovim + its Lua config, a separate `.vimrc` for plain vim, and nvim set as the default editor for git/sudoedit/crontab |
| `tools` | fzf with key bindings, fd, Node.js, gh, gws |
| `claude` | Claude Code, ccstatusline, completion notifications |
| `claude-output-styles` | Claude Code output styles (`~/.claude/output-styles`) |
| `herdr` | herdr, an agent-aware multiplexer installed alongside tmux, not instead of it |
| `desktop` | macOS only: terminal, fonts, system monitor, iTerm2 profile |
| `ghostty` | macOS only: opt-in patched Ghostty build — asks first |

## What gets installed

**Shell** — [zsh](https://www.zsh.org/) with
[oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh),
[starship](https://starship.rs) as the prompt (`--powerline` swaps in the
[bullet-train](https://github.com/caiogondim/bullet-train.zsh) theme instead),
[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) and
[zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting).

**Terminal multiplexer** — [oh-my-tmux](https://github.com/gpakosz/.tmux) with
[tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) (`prefix
Ctrl-s` saves a session, `prefix Ctrl-r` restores it). Full key reference in
[docs/TERMINAL.md](docs/TERMINAL.md).

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
[fd](https://github.com/sharkdp/fd),
[bat](https://github.com/sharkdp/bat), [jq](https://jqlang.github.io/jq/),
[tig](https://jonas.github.io/tig/), Node.js,
[gh](https://cli.github.com/) (GitHub CLI),
[gws](https://github.com/googleworkspace/cli) (Google Workspace CLI).

**AI tooling** — [Claude Code](https://claude.com/claude-code),
[ccstatusline](https://www.npmjs.com/package/ccstatusline), and a Stop-hook
notifier that announces when a turn finishes (Notification Center on macOS,
`notify-send` on a Linux desktop, OSC 9 to the terminal from a VM or over SSH).

Plus [herdr](https://herdr.dev), a multiplexer that tracks whether each agent
pane is working, blocked or done and shows that in a sidebar — the thing tmux
cannot tell you when four agents are running at once. It is installed
*alongside* tmux and changes nothing about it; you opt in by typing `herdr`.
[docs/herdr-loop-eng-tutorial.md](docs/herdr-loop-eng-tutorial.md) covers
running a staged workflow on it.

## Key bindings — the daily five

The full map, with VSCode equivalents and the tmux-safe subset, is
[docs/NEOVIM.md](docs/NEOVIM.md). Leader is `Space`. These five cover most of
a day:

| Key | Action |
| --- | --- |
| `<leader>ff` / `<C-p>` | Find files |
| `<leader>fg` | Grep the project |
| `gd` then `<C-o>` | Jump to a definition, then pop back |
| `<S-l>` / `<S-h>` or `<M-1..9>` | Next / prev editor tab, or jump to tab N |
| `<C-n>` | Toggle the sidebar (works in tmux, unlike `<C-b>`) |

fzf's shell integration is the other half of daily keys:

| Key | Action |
| --- | --- |
| `Ctrl+R` | Fuzzy-search shell history |
| `Ctrl+T` | Insert a file path at the cursor (previewed with `bat`) |
| `Alt+C` | `cd` into a subdirectory |

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

## After installing

1. `exec zsh`
2. `nvim`, then `:Copilot auth` — one-time GitHub login
3. `claude` — one-time Claude Code login

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
