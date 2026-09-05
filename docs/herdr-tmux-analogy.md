# herdr for a tmux user: what maps, and what doesn't

If you already run per-project tmux sessions with a window per concern, herdr's
model will feel familiar for about five minutes and then stop, because it has
one more level than tmux does and reuses tmux's vocabulary for a different
thing.

This page is the mental model for ordinary days — two or three agents, one or
two repos. For the staged `spec → impl → verify → pr` workflow across a whole
epic, see [herdr-loop-eng-tutorial.md](herdr-loop-eng-tutorial.md). For the keys
themselves, [herdr-shortcut.md](herdr-shortcut.md). For tmux's own keys,
[TERMINAL.md](TERMINAL.md).

## The division of labour

herdr does not replace tmux here and `modules/52-herdr.sh` does not touch it.
Both stay installed, both answer to `<C-b>`, and which one you are in is decided
by which command you typed:

- **herdr for agent work.** Anything where a Claude Code session is doing the
  typing and you are supervising several at once.
- **tmux for everything else.** Builds, log tailing, debugging, `ssh` to a box
  that does not have herdr on it — which is every box you do not own.

They are different tools for different jobs, not competitors. The rest of this
page is about why that split falls where it does.

## The extra level

tmux has three levels. herdr has four.

```
tmux     session  ──────────►  window  ────►  pane
herdr    session  ►  workspace  ►  tab  ────►  pane
```

| tmux | herdr | Holds |
| --- | --- | --- |
| session (per project) | **workspace** | one repo, task, or investigation |
| window | **tab** | one concern within it — agent, logs, review |
| pane | **pane** | a terminal process, plus an agent state |
| — | **session** | a whole server namespace, above workspaces |

So the translation for daily use is **tmux session → herdr workspace, tmux
window → herdr tab, pane → pane.** Your habits survive; only the nouns move.

## "Session" is the word that betrays you

It means three different things in this stack, and two of them are in play at
once:

- A **herdr session** is a server namespace with its own socket, sitting *above*
  workspaces. The nearest tmux analogue is a separate socket (`tmux -L other`),
  not a tmux session. You will almost certainly never need a second one; the
  default is called `herdr`.
- A **Claude Code session** is a conversation. This is the one that matters for
  agent work, and it maps to a **pane** — not to a herdr session.
- A **tmux session** is your old per-project container, which is now a
  *workspace*.

When something says "one session per stage", it means the Claude Code one: one
conversation, one pane.

## What tmux genuinely cannot do

Everything above is renaming. This is the part that is not.

Every pane running a recognised agent CLI carries a state, and herdr reports it
whether or not you are looking at that pane:

| State | Meaning |
| --- | --- |
| `working` | actively running |
| `blocked` | waiting on you — a permission prompt, a question |
| `done` | finished, and you have not looked yet |
| `idle` | finished or waiting, and you have looked |
| `unknown` | herdr cannot classify it confidently |

`<prefix> b` toggles the sidebar that rolls this up across every workspace, and
`herdr agent list` prints the same thing.

The distinction that pays for the whole tool is **`blocked` vs `working`**. In
tmux, an agent that stopped ten minutes ago on "may I run this command?" looks
exactly like one that is still thinking — the only way to tell is to visit the
window, and with four agents in flight you are visiting all four on a loop. Here
the answer is on screen continuously, without attaching.

This is also precisely why the split with tmux falls where it does: nothing
about a build or a log tail benefits from agent-state tracking, so those stay
where your muscle memory is deepest.

`modules/52-herdr.sh` installs the Claude Code integration for this. Without it
herdr guesses state by scraping the bottom of the pane; with it, Claude's own
lifecycle hooks report it and the sidebar becomes authoritative.

## A normal day

Not an epic — just work.

```sh
herdr                 # attach; opens a workspace if none exists
```

One **workspace per repo**, which is the same instinct as one tmux session per
repo. Inside it, one **tab per concern**:

| Tab | Holds |
| --- | --- |
| `agent` | `claude`, plus a plain shell split beside it for `git log` and test runs |
| `logs` | whatever you would otherwise be flipping windows to watch |
| `review` | the diff, once something is finished |

That agent-plus-shell split is the one layout worth making a habit —
`<prefix> v` — because it lets you inspect what an agent just did without typing
into its pane and interrupting it.

Then the loop for the rest of the day is: glance at the sidebar, go to whatever
is `blocked`, unblock it, come back. `<prefix> g` jumps by name, which beats
cycling with `<prefix> p` / `<prefix> n` once there is more than one workspace.

`<prefix> q` detaches and **agents keep running** — the server owns the panes and
the client is only a view. Closing the terminal or shutting the lid is safe, and
`herdr` reattaches to exactly what you left. Same promise tmux makes, plus one
addition: with `resume_agents_on_restore = true` (set in the seeded config) an
agent is reattached to its *conversation* after a server restart, not just left
as a dead shell.

## Where the analogy breaks

Things with no herdr equivalent, listed so you stop hunting for the key:

| tmux | herdr |
| --- | --- |
| copy-mode, search-in-scrollback, paste buffers | no bindings for any of them — `<prefix> e` opens the scrollback in `$EDITOR` instead |
| layouts (`<prefix> <Space>`, `M-1…5`) | none — panes are split, not arranged |
| `break-pane`, `swap-pane` | none |
| `last-window` (`<prefix> <Tab>`) | only pane-level cycling exists |
| tmux-resurrect save / restore | different model: `resume_agents_on_restore` |
| being on every server you ssh into | herdr is something you install |

That last row is the practical one, and the strongest argument for keeping tmux
fluent rather than migrating away from it.

## See also

- [herdr-shortcut.md](herdr-shortcut.md) — the keys, and the three ways the
  prefix can look dead when it isn't
- [herdr-loop-eng-tutorial.md](herdr-loop-eng-tutorial.md) — the staged agent
  workflow, and the automation boundary it must not cross
- [INSTALL.md](INSTALL.md) — the module, the config, the test suite
- [herdr.dev/docs/concepts](https://herdr.dev/docs/concepts/) — upstream
