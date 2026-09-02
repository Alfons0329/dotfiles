# Running a staged agent workflow on herdr

How to move a multi-stage Claude Code workflow — the kind where a ticket walks
through `spec → impl → verify → pr-create → pr-review → kb-update`, one fresh
session per stage — from tmux windows onto [herdr](https://herdr.dev), without
changing the workflow itself.

[herdr](https://herdr.dev) is a terminal multiplexer that knows what a coding
agent is. Every pane running a recognised agent CLI carries a state —
`working`, `blocked`, `done`, `idle` — and that state shows in a sidebar across
every workspace, whether or not you are looking at the pane. It also exposes
its own panes over a CLI and a local socket, so a script (or an agent) can read
a pane, wait on a state, or open a new one.

`modules/52-herdr.sh` installs it. See [INSTALL.md](INSTALL.md).

## What this does not change

Read this section before the rest of it, because the point of the exercise is
that almost nothing changes.

- **tmux is untouched.** It stays installed, `.tmux.conf.local` stays
  symlinked, tmux-resurrect stays wired, and `test/verify.sh` still asserts all
  of it. herdr is a second multiplexer that you enter by typing `herdr`. Two
  multiplexers can coexist because neither is a login shell and neither is a
  default.
- **The workflow's own files are not modified.** Nothing here asks the skill,
  the prompts, or the artifacts to know that herdr exists.
- **The prefix is still `Ctrl+B`** — herdr's default, and tmux's default on
  this machine (`.tmux.conf.local` leaves gpakosz's `C-a` swap commented out).
  Splits and tabs answer to the same muscle memory in both.
- **The artifacts are still the interface.** Everything a stage needs to hand
  to the next stage is a file under `~/progress/<ticket-id>/` that got
  committed. herdr does not add a second channel, and this document argues that
  it must not.

Going back is one command: `herdr server stop`, then open tmux. The only state
that matters is on disk.

## The mapping

The habit this replaces is: one tmux **session** per epic, one **window** per
stage of the loop, `claude` running in each.

| Today, in tmux | On herdr | Holds |
| --- | --- | --- |
| session per epic | **workspace** per epic | the tabs and panes for one epic |
| window per stage | **tab** per stage | one stage of one ticket |
| pane running `claude` | **pane** | a terminal — plus an agent state |
| — | **session** | a whole runtime namespace, above workspaces |

The one word that changes meaning is **session**, and it changes twice over, so
it is worth being pedantic once:

- A **herdr session** is a server namespace with its own socket — one level
  *above* workspaces, not below. You almost never need a second one. Selected
  with `herdr --session <name>` or `$HERDR_SESSION`.
- A **Claude Code session** is a conversation. This is the one the workflow's
  "one stage, one fresh session" rule is about, and it maps to a **pane**, not
  to a herdr session.
- A **tmux session** is the old per-epic container, which is now a workspace.

So: *epic → workspace, stage → tab, conversation → pane.*

## Day one

```sh
herdr                    # attach the default session; opens a workspace if none exists
claude                   # in a pane; herdr detects it and starts reporting state
```

| Key | Action |
| --- | --- |
| `prefix v` | split right |
| `prefix -` | split down |
| `prefix c` | new tab |
| `prefix n` / `prefix p` | next / previous tab |
| `prefix q` | detach — **agents keep running** |
| `prefix ?` | the full binding list |

`prefix q` is the one to internalise. The server owns the panes; the client is
just a view onto it. Detaching, closing the terminal, or shutting the laptop
lid leaves every agent running, and `herdr` reattaches to exactly what you
left. That is the same promise tmux makes, with one addition: with
`resume_agents_on_restore = true` (set in the seeded config), an agent gets
reattached to its *conversation* after a server restart, not just to a dead
shell.

## Laying out an epic

Suppose an epic with four tickets, artifacts already laid out the usual way:

```
~/progress/epic-1-upload/
├── epic-ac-tracker.md
├── yt-11/
├── yt-12/
├── yt-13/
└── yt-14/
```

Interactively that is `prefix c` four times. From a script — worth having,
because the layout is identical every epic:

```sh
#!/usr/bin/env sh
# ~/.local/bin/epic-open  <epic-dir>  <ticket-id>...
epic="$1"; shift
ws=$(herdr workspace create --label "$(basename "$epic")" --cwd "$epic" \
     | python3 -c 'import json,sys;print(json.load(sys.stdin)["result"]["workspace"]["workspace_id"])')

for ticket in "$@"; do
    herdr tab create --workspace "$ws" --label "$ticket" --cwd "$epic/$ticket" --no-focus >/dev/null
done
herdr workspace focus "$ws"
```

```sh
epic-open ~/progress/epic-1-upload yt-11 yt-12 yt-13 yt-14
```

Every subcommand prints JSON on stdout, so IDs (`w1`, `w1:t2`, `w1:p3`) are
easy to thread from one call to the next. `herdr workspace list`,
`herdr tab list`, `herdr pane list` enumerate what exists.

Two panes per stage tab is a good default: the agent on the left, a plain shell
on the right for `git log`, `tail`, and the test run you want to watch without
interrupting the agent.

```sh
herdr pane split w1:p1 --direction right --ratio 0.35 --cwd ~/code/target-repo
```

## The part that actually pays for itself

With four tickets in flight, the question you ask thirty times a day is *which
of these is waiting on me?* In tmux the answer requires visiting every window.
Here:

```sh
herdr agent list
```

…and the sidebar answers it continuously without attaching at all: `blocked`
means an agent is sitting on a permission prompt or a question, `working` means
it is running, `done` means it finished and you have not looked yet.

That distinction between `blocked` and `working` is the whole reason to bother.
A stage that stopped ten minutes ago on "may I run this command?" is
indistinguishable, in tmux, from one that is still thinking.

Block until something needs you, rather than polling:

```sh
herdr agent wait w1:t2 --until blocked --until done --timeout 900000
herdr notification show "yt-12 impl" --body "needs you" --sound request
```

## The boundary you must not cross

herdr can drive its own panes. That capability is one command away from
dismantling the thing that makes a staged workflow trustworthy, so be explicit
about where the line is.

The workflow rests on three rules:

1. **One stage, one fresh session.** The session that ran `impl` must not run
   `verify` — it already knows what it expects to pass, and would be grading
   its own homework.
2. **Nothing fires the next stage but you.** The stage boundary is a checkpoint
   you can redirect at. An agent that can start the next stage has removed the
   checkpoint.
3. **Only committed files cross a boundary.** Not env vars, not a scratch
   buffer, not text piped between panes.

Which makes the split clean:

| Fine — observation and staging | Not fine — it fires the stage |
| --- | --- |
| `herdr agent list` | `herdr agent prompt <pane> "/loop-eng verify yt-12"` |
| `herdr agent wait --until blocked` | `herdr agent prompt … --wait --until idle` chained to another prompt |
| `herdr pane read <pane>` | anything that ends in `send-keys <pane> Enter` on an agent |
| `herdr pane wait-output --match …` | passing a stage's output into the next pane's prompt |
| `herdr notification show` | |
| `herdr pane send-text <pane> "…"` | |

The last row is the useful trick and the one worth checking carefully.
`herdr pane send-text` **types the text without submitting it** — verified
against herdr 0.8.2 by sending a command into a pane and reading the pane back:
the line sits at the prompt, unexecuted, until something sends `Enter`. So this
is safe:

```sh
# Open a fresh pane for the next stage and pre-type the command into it.
# The pane waits at the prompt. You read it, and press Enter — or don't.
pane=$(herdr pane split w1:p1 --direction down --cwd ~/code/target-repo \
       | python3 -c 'import json,sys;print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr pane send-text "$pane" 'claude'
```

It removes the typing, not the decision. `herdr agent prompt` and
`herdr pane send-keys … Enter` remove the decision, which is the whole point of
having one.

**Do not install this as a Claude Code hook.** A `Stop` hook that opens the
next stage's pane and prompts it turns the pipeline into an unattended loop
whose `verify` stage is grading its own `impl`. A `Stop` hook that only
*notifies* — which is what `modules/50-claude.sh` already installs — is exactly
right.

## One pane per stage, closed when the stage ends

The mechanical version of rule 1: when a stage reports and stops, close its
pane. Do not reuse it.

```sh
herdr pane close w1:p3      # spec is done; its conversation ends here
```

Then split a new pane for `impl` and start a new `claude` in it. The
conversation boundary and the pane boundary should be the same boundary — that
way "is this a fresh session?" is answerable by looking, instead of by
remembering.

`resume_agents_on_restore = true` does not violate this. It resumes *the same*
stage's conversation in *the same* pane after a server restart, which is a
recovery from a crash, not a stage transition.

## Tickets in flight, without them fighting

Several tickets from one epic being worked at once means several branches of
one repo being worked at once, and one working tree cannot hold them. herdr
wraps `git worktree`:

```sh
herdr worktree create --cwd ~/code/target-repo --branch yt-12-upload-retry --base main --label yt-12
herdr worktree list --cwd ~/code/target-repo
```

That opens a workspace on its own checkout, so `impl` on `yt-12` and `verify`
on `yt-11` stop stepping on each other's working tree. It also keeps every
stage of one ticket on one branch, which is what `pr-create` expects to find.

## Running it on the build server

The same reason this repo installs identically on Ubuntu and macOS:

```sh
# on the build box
herdr server

# from the MacBook
herdr --remote build-box
```

The agents run where the code, the toolchain and the network are; the client is
a view. Close the lid, reattach from somewhere else, and the panes are as you
left them. This is strictly better than the `ssh` + `tmux attach` version,
because the client is a thin protocol client rather than a terminal inside a
terminal — no nested prefix, no `TERM` negotiation across two multiplexers.

If you do end up nested anyway (a herdr client inside a tmux pane), the shared
`Ctrl+B` prefix becomes a problem: the outer multiplexer eats it first. Change
`keys.prefix` in `~/.config/herdr/config.toml`, then `herdr server
reload-config`. Do not change it pre-emptively — the shared prefix is worth
more than the nested case costs.

## Configuration

`~/.config/herdr/config.toml` is **seeded once** by `modules/52-herdr.sh` from
`home/.config/herdr/config.toml.example`, and never overwritten after that. It
is a real file, not a symlink into this repo, so edit it freely.

That is a deliberate departure from how everything else here works (`~/.zshrc`,
`~/.tmux.conf.local` and the Ghostty config are all tracked symlinks with a
separate gitignored override file). herdr's config has no `include` directive,
so there is nowhere for an override file to be layered from — and a tracked
symlink would mean every per-machine tweak dirties the dotfiles checkout and
gets destroyed by the next `git pull`.

The cost: changing `./install.sh --theme` later does not rewrite an existing
herdr config. Set `theme.name` yourself; `herdr --default-config` lists the
built-ins.

```sh
herdr server reload-config    # apply edits without restarting the server
```

## See also

- [INSTALL.md](INSTALL.md) — the module, the manifests, the test suite
- [TERMINAL.md](TERMINAL.md) — tmux keys, truecolor, fonts, themes
- [herdr.dev/docs](https://herdr.dev/docs/) — upstream; the CLI reference and
  socket API pages are the ones worth bookmarking
