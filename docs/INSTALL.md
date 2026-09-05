# What gets installed, and how to verify it

The reference for the installer's moving parts: the modules it runs, the
package manifests, the version pins, and the test suite that proves it on a
bare machine. For the one-command quickstart see the [README](../README.md);
for the keys see [NEOVIM.md](NEOVIM.md) and [TERMINAL.md](TERMINAL.md).

## Modules

`install.sh` discovers `modules/NN-*.sh` in sorted order. Each is also a
standalone script with its own `main()`.

| Module | What it does |
| --- | --- |
| `packages` | System packages from `packages/*.txt`, locale |
| `shell` | zsh, oh-my-zsh, starship prompt (or bullet-train with `--powerline`), plugins, login shell |
| `tmux` | oh-my-tmux + tmux-resurrect |
| `editor` | Neovim + its Lua config, a separate `.vimrc` for plain vim, and nvim set as the default editor for git/sudoedit/crontab |
| `tools` | fzf with key bindings, fd, Node.js, gh, gws |
| `claude` | Claude Code, ccstatusline, completion notifications |
| `claude-output-styles` | Claude Code output styles (`~/.claude/output-styles`) |
| `herdr` | herdr, an agent-aware multiplexer installed alongside tmux, plus its Claude Code integration |
| `codegraph` | codegraph, wired into Claude Code as a global MCP server. Does not index anything — that is `codegraph init`, per repo |
| `desktop` | macOS only: terminal, fonts, system monitor, iTerm2 profile |
| `ghostty` | macOS only: opt-in patched Ghostty build — asks first |

Run one module, or skip some:

```sh
./install.sh --only editor
./install.sh --skip claude,tmux
```

## Package manifests

`packages/apt.txt` (Ubuntu/Debian) and `packages/brew.txt` (macOS), one
package per line, `#` comments. Two naming traps are handled there and in
`modules/40-tools.sh`:

- **`fd`** — the fast find that snacks.picker's explorer search calls. brew's
  `fd` formula installs the binary directly; apt's is `fd-find`, which ships
  the binary as `fdfind` (Debian renamed it to avoid clashing with fdclone),
  so `install_fd()` symlinks it to `~/.local/bin/fd`. Without it the explorer's
  search box errors with `no search file 'fd'`.
- **fzf** — deliberately *not* in `apt.txt`: apt ships 0.29, which predates
  `fzf --zsh`, so `modules/40-tools.sh` installs it from git instead.
- **neovim** — deliberately *not* in `apt.txt`: 22.04 ships 0.6.1, far too old
  for the Lua config, so `modules/30-editor.sh` installs a pinned release.
- **gh** — deliberately *not* in `apt.txt`: 22.04's apt `gh` is the universe
  archive's old snapshot, so `install_gh()` adds GitHub's own apt repo
  instead and installs from there. macOS gets it from `brew.txt` directly.
- **gws** — not in either manifest. [`googleworkspace/cli`](https://github.com/googleworkspace/cli)
  has a brew formula too, but `install_gws()` installs it via `npm install -g
  @googleworkspace/cli` on both platforms so macOS and Linux take the exact
  same path — same reasoning as `ccstatusline` in `modules/50-claude.sh`.

## Default editor everywhere

`~/.zshrc` exports `$EDITOR`/`$VISUAL` as nvim, but that only reaches tools
launched from an interactive zsh. `modules/30-editor.sh`'s
`configure_default_editor()` closes the rest: `git config --global
core.editor nvim` (git's own precedence is `GIT_EDITOR` > `core.editor` >
`$VISUAL` > `$EDITOR` > `vi`, so this wins regardless of which shell invoked
git), and on Linux, `update-alternatives --set editor nvim` — what Debian's
`sensible-editor` falls back to for `crontab -e` and `sudoedit` when neither
env var is set, defaulting to nano otherwise.

## herdr, and why its config is not a symlink

`modules/52-herdr.sh` is numbered after `50-claude.sh` rather than next to
`20-tmux.sh`, even though [herdr](https://herdr.dev) is a multiplexer:
`herdr integration install claude` needs Claude Code on the box already, and
module order is the only dependency mechanism this installer has. Nothing in
the module touches tmux — herdr is installed *alongside* it and is entered by
typing `herdr`. The workflow it is meant to serve is
[herdr-loop-eng-tutorial.md](herdr-loop-eng-tutorial.md).

Not in either package manifest: macOS gets `brew install herdr`
(homebrew-core), Linux gets `herdr.dev/install.sh`, which is POSIX `sh`, needs
only `curl` and `awk`, checks the download against a SHA-256 from the release
manifest, and installs to `~/.local/bin` — already first on `$PATH`. No version
pin, unlike Neovim: there is no known version constraint here, and pinning
would put installs and `herdr update` on different manifests.

`~/.config/herdr/config.toml` is **seeded once** from
`home/.config/herdr/config.toml.example` and never overwritten — the
`~/.zshrc.local` pattern, not the symlink pattern used for `.tmux.conf.local`
and the Ghostty config. herdr's config has no `include` directive, so a
gitignored override file has nowhere to be layered from, and a tracked symlink
would mean every per-machine tweak dirties this checkout and dies on the next
`git pull`. The cost is that a later `--theme` change does not rewrite an
existing config; the module says so rather than clobbering it.

The Claude Code integration writes a `SessionStart` hook into
`~/.claude/settings.json`, which `modules/50-claude.sh` also writes (the
Stop-hook notifier). Verified at herdr 0.8.2 that it merges rather than
rewrites, leaving the notifier intact. `test/verify.sh`'s "Stop hook wired"
check is the guard for that: if a future herdr release starts rewriting the
file, notifications stop working with no other symptom, and that check is what
notices.

## Neovim version pin

`NVIM_VERSION` is pinned rather than tracking `latest`, because Neovim's
release binaries are linked against whatever glibc their CI image happens to
ship. Probing a real `ubuntu:22.04` container (glibc 2.35) gave:

| Release | On glibc 2.35 |
| --- | --- |
| `v0.10.4` | Fails — requires `GLIBC_2.38` |
| `v0.11.0` … `v0.12.4` | Runs |

So the floor on Ubuntu 22.04 is `v0.11.0`, which is also blink.cmp's minimum.
The default is `v0.12.4`. If the pinned build will not run, the installer stops
with the glibc mismatch spelled out rather than falling back to the distro
package — failing loudly beats a wall of Lua errors.

```sh
NVIM_VERSION=v0.11.0 ./install.sh --only editor   # older glibc
NVIM_VERSION=latest  ./install.sh --only editor   # newest, at your own risk
```

Language servers install by default — without them nothing completes, jumps to
a definition, or renames a symbol, which is most of the point. They are still
the largest and most network-dependent step, so a failure only warns rather
than failing the run:

```sh
./install.sh --no-lsp-servers   # skip them (~300-600 MB)
```

`nvim-treesitter` is pinned to its `master` branch. The default branch is now
`main`, a rewrite that no longer ships the `nvim-treesitter.configs` module
this config drives — an unpinned clone throws on every file open and leaves you
with no syntax highlighting at all. `master` also keeps `auto_install`, so a
language that is not in the list still highlights itself the first time you
open one.

**Parsers finish installing lazily, and that is deliberate.** `:TSUpdate` runs
at install time but is asynchronous, so nvim exits with most parsers still
building; the first time you open, say, a Python file, its parser compiles in
the background and highlighting appears a moment later. Forcing them all to
build up front was tried and is much worse — these are multi-megabyte generated
C files (`typescript`'s `parser.c` is 17.5 MB, `bash`'s is 9.9 MB) and
compiling the set serially took over 27 minutes with no output. That does not
belong in a script whose promise is that you run it once.

## Verifying

`test/verify.sh` asserts behaviour rather than presence — it checks that
`Ctrl+R` is actually bound to `fzf-history-widget`, that lualine really owns
the statusline, that the shell exports a UTF-8 locale, that treesitter attaches
a highlighter to a real buffer, and that no old framework has crept back in:

```sh
./test/verify.sh        # against the current machine
./test/shellcheck.sh    # lint every script
./install.sh --dry-run  # print everything that would happen
```

One check earns its place more than the rest. Every other Neovim assertion runs
`nvim --headless +qa`, which never reads a buffer — so nothing lazy-loaded on
`BufReadPre` ever runs, and a config that crashed on every single file open
once passed the whole suite. There is now a check that opens a real file and
demands silence.

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
