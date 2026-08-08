# Working in this repo

Personal dotfiles, **public**. One command (`./install.sh`) takes a bare Ubuntu
22.04 build server or a fresh MacBook to a full working environment.

The design rationale is in the code, not here: every non-obvious decision has a
comment next to it explaining the concrete failure that motivated it. Read those
before changing something that looks redundant — most of it is load-bearing.

## Never commit `ref/`

`ref/` is local-only scratch material that is not mine to publish. It is
gitignored, has **0 commits**, and must stay that way. Confirm with:

```sh
git log --all --oneline -- ref/    # must be empty
```

Nothing in it gets copied into this repo. Where it covers the same ground,
rewrite from a spec instead, and re-run the leak grep before publishing.

Secrets live in `~/.zshrc.local` (gitignored, sourced last, seeded once and
never overwritten). The tracked `.zshrc` is world-readable; `test/verify.sh`
fails if anything resembling an exported credential appears in it.

## Layout

```
install.sh          entrypoint; discovers modules/*.sh in sorted order
lib/core.sh         run(), link(), git_get(), fetch(), confirm(), SUDO shim
modules/NN-*.sh     one concern each, standalone-runnable, each has main()
packages/*.txt      package manifests, one per line
home/               mirrors $HOME; everything here gets symlinked
scripts/            standalone helpers (Ghostty source build)
test/               Dockerfile, verify.sh, docker-test.sh, shellcheck.sh
```

## Rules that bite

**bash 3.2.** macOS ships 3.2.57 and this script bootstraps machines that have
nothing installed, so it cannot require a newer bash. No `mapfile`/`readarray` —
use `read_lines` from `lib/core.sh`.

**Everything mutating goes through `run()`.** That is the only thing making
`--dry-run` trustworthy rather than decorative. A direct `mkdir`/`ln`/`curl`
silently breaks it.

**`sudo` scrubs the environment.** `DEBIAN_FRONTEND=x sudo apt-get` loses the
variable and opens an interactive prompt. Use `as_root env VAR=x cmd`.

**One owner per concern.** One statusline plugin, one colorscheme, one sign
column, one file tree. The whole Neovim config exists because two statusline
plugins fought over `&statusline` from competing autocmds.

## Writing checks in `test/verify.sh`

The suite is the pass/fail signal for the Docker build, so a check that passes
for the wrong reason is worse than no check. Three failures have actually
happened here:

1. **Assert behaviour, not presence.** `command -v fzf` passed while `Ctrl+R`
   did nothing. Assert `bindkey "^R"` maps to `fzf-history-widget`.
2. **Don't grep a file for a string that also appears in its own comments.** Two
   checks have failed this way — the comment explaining why `X` was removed
   matches a grep for `X`. Anchor to the assignment line, or ask the program.
3. **Any Neovim check must open a real file.** `nvim --headless +qa` never reads
   a buffer, so nothing lazy-loaded on `BufReadPre`/`BufReadPost` runs. A config
   that crashed on *every* file open once passed the entire suite.

Also: a pipeline reports the exit status of its **last** command. `cmd | tail -3`
returns `tail`'s success, not `cmd`'s.

## Verifying

```sh
./test/shellcheck.sh                        # must stay clean
DRY_RUN=1 ./install.sh                      # Linux path
DRY_RUN=1 FORCE_PKG_MGR=brew ./install.sh   # macOS path
./test/docker-test.sh                       # the real test: bare ubuntu:22.04
./test/docker-test.sh --with-lsp            # + language servers
```

The Docker build is the pass/fail signal: the base image gets only `sudo` and a
non-root user, so every tool must come from `install.sh`. Both dry-runs must run
under `/bin/bash` 3.2.

## Untested surface

macOS is covered by dry-run and shellcheck only — no VM. Specifically unverified:

- `modules/70-ghostty.sh` has never actually run (needs Xcode ≤ 26.3).
- The iTerm2 `Cmd+Shift+F` keymap encoding `"0x46-0x120000"` is a best reading of
  iTerm2's plist format. If it does not fire, bind it once in the GUI and read
  the real key back out of `~/Library/Preferences/com.googlecode.iterm2.plist`.
- Brew formula/cask names are only as good as the dry-run output.

Anything requiring an interactive login cannot be scripted: `:Copilot auth`,
`claude` first run, and Apple ID for the Xcode download.

## Conventions

Comments explain **why**, citing the concrete failure — not what the line does.
Match that. Keep prose in README.md task-oriented; keep the archaeology in code
comments next to the thing it justifies.
