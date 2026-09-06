# herdr keys, for someone whose hands already know tmux

herdr's prefix is `<C-b>` — the same as tmux's on this machine, deliberately, so
you never have to remember which multiplexer you are attached to. Below,
`<prefix>` means press-and-release `Ctrl+B`, then the next key.

Because the prefix matches, the only thing worth learning is the **diff**: what
the second key does differently. That turns out to be seven bindings, plus three
keys for [moving between agents](#moving-between-agents) that herdr ships unbound
and this repo binds. This page is those lists, plus the three ways the prefix can
appear dead when it isn't.

For what workspaces and tabs actually *are*, see
[herdr-tmux-analogy.md](herdr-tmux-analogy.md). For the tmux side of the
comparison, [TERMINAL.md](TERMINAL.md). For the staged agent workflow,
[herdr-loop-eng-tutorial.md](herdr-loop-eng-tutorial.md).

Every key here was read out of `herdr --default-config` on herdr 0.8.2, and the
six you will use hourly — `v`, `-`, `q`, `w`, `b`, `?` — were pressed by hand on
macOS 25.5 to confirm they fire. That distinction matters on this page: an
earlier revision documented an IME fix that herdr reported as applied and which
did nothing, so "read from the config" and "verified working" are not the same
claim. See [When the prefix looks dead](#when-the-prefix-looks-dead).

The three agent keys were held to the same standard: `herdr config check` parses
and accepts them, `herdr server reload-config` applies them with no diagnostics,
and then all three — `J`, `K` and `<A-1>` — were pressed on a live two-agent
session on macOS 25.5 and observed to move focus. The last step is the one that
matters, because the IME setting also reported itself applied and did nothing.
`<A-1>` firing also settles the open question about Alt: Option reaches herdr as
`Esc+` in this setup, so the indexed row works rather than merely parsing.

This repo's config sets `prefix` and those three agent bindings, and nothing
else — see [Why nothing is remapped](#why-nothing-is-remapped).

## The seven that differ

This is the whole learning cost.

| What you want | tmux (oh-my-tmux) | herdr |
| --- | --- | --- |
| split right | `<prefix> _` | `<prefix> v` |
| detach | `<prefix> d` | `<prefix> q` |
| previous / next tab | `<prefix> <C-h>` / `<C-l>` | `<prefix> p` / `<prefix> n` |
| rename | `<prefix> ,` (window) | `<prefix> T` (tab), `<prefix> P` (pane) |
| resize a pane | `<prefix> H J K L` | `<prefix> r`, then move |
| the picker | `<prefix> s` sessions, `<prefix> w` windows | `<prefix> w` workspaces, `<prefix> g` goto |
| reload the config | — | `<prefix> R` |

Two of these bite harder than the rest.

`<prefix> p` / `<prefix> n` is the row most likely to catch you, because it looks
like it should already be familiar: those *are* vanilla tmux's next/previous
window keys. But oh-my-tmux **unbinds** them, moving window switching to
`<C-h>`/`<C-l>` and `M-n`/`M-p`. So herdr matches stock tmux and your tmux
doesn't, which is the worst of both.

`<prefix> s` does something in herdr rather than nothing: it opens **settings**,
not a session picker. Reaching for it out of tmux habit gives you a UI you did
not ask for instead of a no-op you would notice.

## The ones that already match

Nothing to learn here; they are listed so you know not to look them up.

| Keys | What it does |
| --- | --- |
| `<prefix> -` | split below |
| `<prefix> h j k l` | move between panes |
| `<prefix> c` | new tab (tmux: new window) |
| `<prefix> x` | close the pane |
| `<prefix> z` | zoom / fullscreen the pane |
| `<prefix> 1…9` | jump straight to tab N |
| `<prefix> ?` | list every binding — the escape hatch |

## Moving between agents

The reason to run herdr at all is that it knows which agent is `working`,
`blocked`, `done` or `idle` across every workspace at once. Out of the box you
cannot *act* on that: the sidebar tells you an agent went `blocked`, and then
leaves you to walk to it by hand through the workspace picker.

That gap is not a mistake in this setup — herdr ships the three agent actions
**unbound**, and `prefix ?` lists them under `agent` as `unset previous agent`,
`unset next agent`, `unset focus agent 1-9`. Which reads like "herdr does not do
this" rather than "you have not said where to put it."

This repo binds them:

| Keys | What it does |
| --- | --- |
| `<prefix> K` | previous agent |
| `<prefix> J` | next agent |
| `<prefix> <A-1>` … `<A-9>` | jump straight to agent N, in sidebar order |

`J` / `K` because `h j k l` already means "move focus" here, so shift is the same
motion one level out: panes are the inner axis, agents the outer one. What they
walk is the agent list the sidebar shows, not the current workspace's tabs, so
they cross workspace boundaries — which no tab or pane key can do, and which is
the whole point.

The numeric jump takes Alt because `<prefix> 1…9` is already tab switching, and
Alt is the modifier herdr's own config suggests for it. Alt reaches herdr as
`Esc+` in both terminals this repo configures: Ghostty via `macos-option-as-alt`,
iTerm2 via the Option-sends-Esc+ setting in the dynamic profile that
`modules/60-desktop.sh` deploys. `<A-1>` was pressed and confirmed under Ghostty;
the iTerm2 half is the profile's stated behaviour and has not been exercised. In
some third terminal where Option types `¡™£`, that row is the one that will not
fire; `J` / `K` still will.

### Getting these onto a machine that predates them

`modules/52-herdr.sh` seeds `~/.config/herdr/config.toml` once and never
overwrites it, so an existing machine keeps the config it already has and these
keys stay unset there. Paste this into its `[keys]` block:

```toml
previous_agent = "prefix+shift+k"
next_agent = "prefix+shift+j"
focus_agent = "prefix+alt+1..9"
```

Then, without restarting anything:

```sh
herdr config check          # config: ok
herdr server reload-config  # {"diagnostics":[],"status":"applied"}
```

`herdr config check` is worth running rather than trusting, because it reads the
key syntax and not just the TOML: `"prefix+quux+1..9"` comes back as
`invalid keybinding …; disabling binding`, and a `focus_agent` that is not
indexed as `indexed keybinding must use 1..9`.

What it will **not** catch is a collision. `next_agent = "prefix+n"` reports
`config: ok` even though `prefix+n` is already `next_tab`, and one of the two
then silently loses. So if you pick different keys, diff them against
`herdr --default-config` yourself — `test/verify.sh` does exactly that for the
three above, so a future herdr release claiming one of them fails the build
instead of quietly taking the binding away.

## herdr-only, with no tmux ancestor

These are the ones worth actually practising, because no habit will produce
them. The agent keys above belong to this group too and are listed separately
only because they are the ones you have to bind yourself.

| Keys | What it does |
| --- | --- |
| `<prefix> b` | toggle the sidebar — the agent-state view |
| `<prefix> N` | new **workspace** (the per-repo / per-epic container) |
| `<prefix> g` | goto: jump to a tab or pane by name |
| `<prefix> e` | open the pane's scrollback in `$EDITOR` |
| `<prefix> G` | new git worktree, with a workspace on it |
| `<prefix> o` | open the target of the last notification |
| `<prefix> W` / `<prefix> D` | rename / close the workspace |
| `<prefix> X` | close the tab |
| `<prefix> <Tab>` | cycle panes |

`<prefix> e` is the closest thing to tmux's copy-mode. herdr's binding list has
no copy-mode or scrollback-search action at all, so rather than reimplementing
one it hands the buffer to `$EDITOR` — which is Neovim here, where you already
know how to search.

## Keys that do nothing, and why that is confusing

tmux habits that land on an unbound key in herdr. Nothing happens, which is
indistinguishable from the prefix itself having failed — see the next section
before assuming the prefix is broken.

| Pressed | Expected (tmux) | herdr |
| --- | --- | --- |
| `<prefix> _` / `<prefix> %` | split right | unbound |
| `<prefix> "` | split below | unbound |
| `<prefix> d` | detach | unbound (it is `q`) |
| `<prefix> <C-h>` / `<C-l>` | previous / next window | unbound (it is `p`/`n`) |
| `<prefix> [` | copy-mode | unbound (use `e`) |
| `<prefix> <Space>` | next layout | unbound — herdr has no layouts |
| `<prefix> !` / `{` / `}` | break / swap pane | unbound |
| `<prefix> <C-s>` / `<C-r>` | tmux-resurrect save / restore | unbound — different model entirely |

## When the prefix looks dead

Three separate causes, all of which present identically: you press `<C-b>`, then
a key, and nothing happens. Diagnose in this order.

**1. A non-ASCII input source is eating the second key.** With a Bopomofo (zhTW)
source active, `<C-b>` registers but the key *after* it never reaches herdr —
`<prefix> v` types `ㄒ` into the pane, which reads as a dead prefix if you do not
recognise the character.

**Switch input source to English.** That is the whole fix, and it is the reason
this repo ships no config for it.

herdr does document an `[experimental]` setting,
`switch_ascii_input_source_in_prefix`, which is supposed to select an
ASCII-capable layout for the duration of prefix mode. It was tried here on herdr
0.8.2 / macOS 25.5 and **did not work**: `herdr server reload-config` returned
`{"diagnostics":[],"status":"applied"}` and `<prefix> v` still produced `ㄒ`. The
cause was not pinned down — plausibly the hook is installed at server start
rather than on a config reload, or the Bopomofo source has no ASCII-capable
sibling to switch to. It was removed rather than left in place looking
load-bearing. The lesson generalises: *"config applied" is not "hook working."*

**2. Caps Lock is not an English toggle.** Using Caps Lock to escape the IME
makes this worse, not better: it sends `V`, not `v`, and herdr reads
`prefix+shift+<key>` as a *different* action — `<prefix> N` is new-workspace,
`<prefix> X` is close-tab. So `<prefix> v` with Caps Lock on either matches
nothing and looks exactly like a dead prefix, or matches something you did not
ask for. Since this repo binds `<prefix> J` / `<prefix> K`, a Caps-Locked
`<prefix> j` now walks you to another agent rather than moving pane focus, which
is the more confusing of the two outcomes. Switch input source properly instead.

**3. Something outside herdr is eating `<C-b>` first.** A herdr client running
inside a tmux pane is the usual cause — the outer multiplexer takes the prefix.

Diagnose that with the **process ancestry**, not the `TMUX` environment variable:

```sh
p=$$; while [ "$p" -gt 1 ]; do ps -o pid=,ppid=,comm= -p "$p"; \
  p=$(ps -o ppid= -p "$p"); done
```

`TMUX` is not proof. On this machine it was set and pointed at a live tmux
server while the pane in question was a direct child of `herdr server` — not
nested at all. The variable had been inherited from whatever shell started the
server and outlived it. Chasing that false positive cost the first diagnosis of
a problem that turned out to be cause 2.

If you *are* genuinely nested, change `keys.prefix` in
`~/.config/herdr/config.toml` and run `herdr server reload-config`. Do not change
it pre-emptively — the shared prefix is worth more than the nested case costs.

## Why nothing is remapped

"Remapped" is the operative word: the agent keys above are not a remap, and the
argument below does not apply to them. herdr ships those three actions with no
key at all, so binding them overrides nothing, and `prefix ?` stays truthful on
every machine because it renders the live config rather than a built-in table. A
machine without the block simply has no agent keys — not different ones.

Everything else is a different story. herdr's keys are fully rebindable, and an
earlier version of this setup remapped five of them to match oh-my-tmux. That was
reverted, for a reason that is specific to how this repo installs herdr.

`modules/52-herdr.sh` seeds `~/.config/herdr/config.toml` **once and never
overwrites it**. A keymap added to the tracked template therefore reaches a
*new* machine and never an *existing* one — so instead of one config you get
several that quietly disagree, and `<prefix> ?` is accurate on none of them. Zero
config is the only state that stays identical across machines for free.

The other half of the argument is that a full remap is not achievable anyway.
herdr's bindable actions are a closed set with no copy-mode, no layouts, no
`break-pane`, no last-window and no resurrect, so a chunk of the tmux map has
nothing to point at. Remapping relocates the differences rather than removing
them, while adding config that this repo cannot test headlessly.

Seven keys is a smaller price than that. If you do remap anyway, put it in
`~/.config/herdr/config.toml` on that one machine, not in the template.
