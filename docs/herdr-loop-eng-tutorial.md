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

This page assumes the model and the keys. For the model — workspace vs tab vs
the three meanings of "session" — see
[herdr-tmux-analogy.md](herdr-tmux-analogy.md); for the keys,
[herdr-shortcut.md](herdr-shortcut.md).

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
  this machine (`.tmux.conf.local` leaves gpakosz's `C-a` swap commented out),
  so you never have to remember which one you are attached to. Seven of the
  *second* keys do differ from oh-my-tmux; that list is in
  [herdr-shortcut.md](herdr-shortcut.md).
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

So: *epic → workspace, stage → tab, conversation → pane.*

"Session" means three different things across this stack, and getting them
confused is the one thing that will make the rest of this page read wrong. The
short version: this workflow's "one stage, one fresh **session**" rule is about
a *Claude Code* session — a conversation — which maps to a **pane**, not to a
herdr session. [herdr-tmux-analogy.md](herdr-tmux-analogy.md) disambiguates all
three properly.

## Day one

```sh
herdr                    # attach the default session; opens a workspace if none exists
claude                   # in a pane; herdr detects it and starts reporting state
```

| Key | Action |
| --- | --- |
| `<prefix> N` | new workspace — one per epic |
| `<prefix> c` | new tab — one per ticket or stage |
| `<prefix> v` / `<prefix> -` | split right / below |
| `<prefix> p` / `<prefix> n` | previous / next tab |
| `<prefix> b` | toggle the sidebar |
| `<prefix> q` | detach — **agents keep running** |
| `<prefix> ?` | the full binding list |

Those are herdr's stock bindings, and this repo does not remap any of them —
[herdr-shortcut.md](herdr-shortcut.md) explains why, and lists the seven that
differ from oh-my-tmux.

`<prefix> q` is the one to internalise. The server owns the panes; the client is
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

Build that by hand. It is a handful of keystrokes, and the same shape every
epic:

1. `<prefix> N` — new workspace, named for the epic (`epic-1-upload`).
2. `<prefix> c` once per ticket, renaming each with `<prefix> T` (`yt-11`,
   `yt-12`, …). In tmux terms you have just made a session with four windows.
3. In each tab, `<prefix> v` to split right, then `cd` to the ticket's directory
   and start `claude` on the left.

That last split is the layout worth making a habit: **agent on the left, plain
shell on the right** for `git log`, `tail`, and the test run you want to watch
without typing into the agent's pane and interrupting it.

Naming the tabs is not cosmetic. `<prefix> g` jumps to a tab by name, and the
sidebar labels agent states by tab, so an unnamed tab shows up as a state you
cannot attribute to a ticket.

If you would rather not repeat that by hand every epic, it scripts cleanly —
see [the appendix](#appendix-scripting-a-repeated-layout). Reach for it once the
same four-ticket layout is the third thing you have typed this week, not before.

## The part that actually pays for itself

With four tickets in flight, the question you ask thirty times a day is *which
of these is waiting on me?* In tmux the answer requires visiting every window.

Here it is already on screen. `<prefix> b` toggles the sidebar, which rolls up
every agent's state across every workspace whether or not you are attached to
the pane: `blocked` means it is sitting on a permission prompt or a question,
`working` means it is running, `done` means it finished and you have not looked
yet. (`herdr agent list` prints the same thing, if you want it in a shell.)

That distinction between `blocked` and `working` is the whole reason to bother.
A stage that stopped ten minutes ago on "may I run this command?" is
indistinguishable, in tmux, from one that is still thinking.

So the loop for the day is: glance at the sidebar, go to whatever is `blocked`
with `<prefix> g`, unblock it, come back. No polling, and no cycling through
tabs to find out nothing has changed.

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

`<prefix> x` closes the focused pane — spec is done, its conversation ends here.

Then `<prefix> v` for a new pane and start a new `claude` in it. The
conversation boundary and the pane boundary should be the same boundary — that
way "is this a fresh session?" is answerable by looking, instead of by
remembering.

`resume_agents_on_restore = true` does not violate this. It resumes *the same*
stage's conversation in *the same* pane after a server restart, which is a
recovery from a crash, not a stage transition.

## Tickets in flight, without them fighting

Several tickets from one epic being worked at once means several branches of
one repo being worked at once, and one working tree cannot hold them. herdr
wraps `git worktree`: `<prefix> G` prompts for a branch and opens a workspace on
a fresh checkout of it. The same thing non-interactively, when you are setting up
several at once:

```sh
herdr worktree create --cwd ~/code/target-repo --branch yt-12-upload-retry --base main --label yt-12
herdr worktree list --cwd ~/code/target-repo
```

Either way you get a workspace on its own checkout, so `impl` on `yt-12` and `verify`
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

## Appendix: scripting a repeated layout

Optional, and deliberately last. Everything above is done from the keyboard, and
that is the right default — you see what you are making. But the epic layout is
identical every time, and once you have typed it three times in a week it is
worth having as a command.

Every herdr subcommand prints JSON on stdout, so IDs (`w1`, `w1:t2`, `w1:p3`)
thread from one call to the next. `herdr workspace list`, `herdr tab list` and
`herdr pane list` enumerate what exists.

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

Note what it does **not** do: it opens panes and stops. It does not start
`claude` in them, and it does not prompt anything. That keeps it on the safe
side of the boundary above — it is staging, not firing.

The other thing worth scripting is waiting, when you are stepping away rather
than watching the sidebar:

```sh
herdr agent wait w1:t2 --until blocked --until done --timeout 900000
herdr notification show "yt-12 impl" --body "needs you" --sound request
```

That blocks until something needs you and then tells you. It still does not act
on the answer — you do.

## See also

- [herdr-tmux-analogy.md](herdr-tmux-analogy.md) — the model, and an ordinary
  day's workflow rather than an epic's
- [herdr-shortcut.md](herdr-shortcut.md) — the keys, and the three ways the
  prefix can look dead when it isn't
- [INSTALL.md](INSTALL.md) — the module, the manifests, the test suite
- [TERMINAL.md](TERMINAL.md) — tmux keys, truecolor, fonts, themes
- [herdr.dev/docs](https://herdr.dev/docs/) — upstream; the CLI reference and
  socket API pages are the ones worth bookmarking
