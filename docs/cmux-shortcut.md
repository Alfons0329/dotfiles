# cmux keys, for someone whose hands already know tmux

cmux's prefix is `<C-b>` here — the same as tmux's and herdr's, deliberately, so
one habit drives all three. Below, `<prefix>` means press-and-release `Ctrl+B`,
then the next key.

**Notation**, which is vim's and tmux's and is worth stating because the two
kinds of second key look alike on the page:

| Written | Press |
| --- | --- |
| `<prefix> s` | `Ctrl+B`, let go, then the letter `s` on its own |
| `<prefix> %` | `Ctrl+B`, let go, then `%` — the shifted key you would type into a file |
| `<prefix> <C-c>` | `Ctrl+B`, let go, then `Ctrl+C` — `<C-x>` always means Ctrl held with `x` |
| `<prefix> <Tab>` | `Ctrl+B`, let go, then the Tab key; `<S-Tab>` is Shift+Tab |

Nothing here is a hold-all-three chord: the prefix is always released first, and
in the config every binding is literally a two-item list — `<prefix> <C-c>` is
`["ctrl+b", "ctrl+c"]`, `<prefix> s` is `["ctrl+b", "s"]`.

Out of the box cmux has no prefix at all: it is a macOS app with Cmd shortcuts,
`⌘D` to split and `⌘T` for a new tab. `modules/65-cmux.sh` replaces those with
the map below by writing a managed block into `~/.config/cmux/cmux.json`, which
is rewritten on every `./install.sh` run — so unlike herdr's seeded config, an
existing machine gets a change by re-running the installer.

**Read [the trade](#what-you-give-up) before using this page as a reference.** A
cmux action holds exactly one binding, so every chord below *replaces* a Cmd
key rather than joining it, and `<C-b>` stops reaching anything running inside
cmux.

For the tmux side of the comparison, see [TERMINAL.md](TERMINAL.md); for the
same exercise done against herdr, [herdr-shortcut.md](herdr-shortcut.md).

Every binding on this page was read out of cmux's published shortcut schema,
accepted by `cmux config doctor`, and checked by `test/verify.sh` against the
default table cmux itself writes into `~/.config/cmux/cmux.json` — so the action
ids are real and no two chords collide. That is **not** the same as having been
pressed — `%`, `"`, `$` and `s` have been, on cmux 0.64.22 under macOS 26.5, and
the two rows still marked ⚠ have not. See
[Keys that may need a press-test](#keys-that-may-need-a-press-test).

## The map

cmux nests one level deeper than tmux — window > workspace > pane > surface —
so the analogy used throughout is: **workspace ≈ tmux session**, **surface
(tab) ≈ tmux window**, **pane ≈ pane**. That is what puts the workspace picker
on `s` and the digit row on tabs.

### Panes

| Keys | What it does | Was |
| --- | --- | --- |
| `<prefix> %` | split right | `⌘D` |
| `<prefix> "` | split below | `⌘⇧D` |
| `<prefix> h j k l` | move between panes | `⌥⌘` + arrows |
| `<prefix> o` | next pane | *unbound in cmux* |
| `<prefix> ;` | previous pane | *unbound in cmux* |
| `<prefix> z` | zoom the pane | `⌘⇧↩` |
| `<prefix> =` | equalise the splits | `⌃⌘⇧=` |

### Tabs (cmux calls them surfaces)

| Keys | What it does | Was |
| --- | --- | --- |
| `<prefix> c` | new tab | `⌘T` |
| `<prefix> x` | close the tab | `⌘W` |
| `<prefix> ,` | rename the tab | `⌘R` |
| `<prefix> 1…9` ⚠ | jump straight to tab N | `⌃1…9` |
| `<prefix> <C-h>` / `<C-l>` | previous / next tab | `⌘⇧[` / `⌘⇧]` |
| `<prefix> <Tab>` / `<S-Tab>` | focus back / forward | `⌘[` / `⌘]` |

`<C-h>` / `<C-l>` rather than `n` / `p` because that is what oh-my-tmux moved
window switching to, and `n` / `p` are left unbound here for the same reason
they are unbound there — a stale habit should do nothing rather than something.

### Workspaces (the tmux session axis)

| Keys | What it does | Was |
| --- | --- | --- |
| `<prefix> s` | the workspace picker | `⌘P` |
| `<prefix> w` | command palette | `⌘⇧P` |
| `<prefix> (` / `)` ⚠ | previous / next workspace | `⌃⌘[` / `⌃⌘]` |
| `<prefix> $` | rename the workspace | `⌘⇧R` |
| `<prefix> <C-c>` | new workspace | `⌘N` |

### Everything else

| Keys | What it does | Was |
| --- | --- | --- |
| `<prefix> [` | copy mode | `⌘⇧M` |
| `<prefix> r` | reload cmux.json **and** the Ghostty config | `⌘⇧,` |

`toggleSidebar` (cmux's own left sidebar) is deliberately **not** on this list.
It stays on its native `⌘B` rather than moving to `<prefix> b` the way herdr's
equivalent key would suggest: `⌘B` is a real, separate shortcut people reach
for constantly, and losing it to a tmux-parity binding with no tmux default to
justify it is a worse trade than leaving `<prefix> b` unbound.

Mouse selection copies to the clipboard, which is `terminal.copyOnSelect` in the
same managed block. tmux gets that from `set -g mouse on` plus the
`MouseDragEnd1Pane` unbind in `~/.tmux.conf.local`, and herdr gets it for free —
`copy_on_select = true` is already in `herdr --default-config`. cmux is the only
one of the three that defaults it off. Plain Ghostty, opened without cmux, gets
the same behaviour from `copy-on-select = clipboard` in
`~/.config/ghostty/config` directly — `clipboard` rather than Ghostty's own
default of `true`, which only reaches the system clipboard on a platform with
no separate selection clipboard (true of macOS by accident, false on Linux).

## What you give up

**The Cmd keys those chords replaced.** `shortcuts.bindings` in cmux's schema
takes a single shortcut *or* a two-stroke chord — never a list — so an action
cannot answer to both. After this module runs, in cmux:

- `⌘T`, `⌘W`, `⌘N`, `⌘R`, `⌘D`, `⌘P` do nothing;
- `⌘[` and `⌘]` are free, which is a small win: cmux binds focus-back/forward to
  them by default, and that is what stops a terminal program inside cmux from
  ever seeing those keys.

`⌘,` (settings), `⌘Q` (quit), `⌘⇧W` (close workspace) and the rest are
untouched. Closing a *workspace* deliberately keeps its Cmd key: tmux's `&`
kills a window, which here is `<prefix> x`, and a chord that destroys a whole
workspace is not one to add by analogy.

**`<C-b>` inside cmux.** cmux claims the first stroke app-wide, so a program
running in a cmux terminal may never see it: readline's `backward-char`, vim's
page-up, and — the one that matters — **a nested tmux**. Running tmux inside a
cmux pane is not practical with this map. If you need it, change the first
stroke of every binding in `cmux_managed_block()` in `modules/65-cmux.sh` and
re-run `./install.sh --only cmux`; the prefix is not special-cased anywhere.

## Keys that have no cmux equivalent

Not oversights — cmux has no action to point these at, and leaving them out is
better than approximating them with something that does a different thing.

| Pressed | Expected (tmux) | cmux |
| --- | --- | --- |
| `<prefix> d` | detach | nothing to detach from; cmux has no sessions |
| `<prefix> H J K L` | resize the pane | no resize-by-direction action — drag the divider, or `<prefix> =` |
| `<prefix> _` / `<prefix> -` | split | one binding per action; `%` and `"` hold them |
| `<prefix> ?` | list every binding | the shortcut list has no bindable action id — run `cmux settings shortcuts`, or read this page |
| `<prefix> <C-s>` / `<C-r>` | tmux-resurrect | different model; cmux restores on its own |
| `<prefix> <Space>` | next layout | cmux has no layouts |

## Keys that may need a press-test

The schema's key grammar accepts `[A-Za-z0-9]` and `,./\;'` `` ` `` `=[]-` and
nothing else, so the five keys with no literal spelling are written as their
shifted form: `%` is `shift+5`, `"` is `shift+'`, `$` is `shift+4`, `(` and `)`
are `shift+9` and `shift+0`.

**That spelling works.** `<prefix> %`, `<prefix> "` and `<prefix> $` were pressed
on cmux 0.64.22 / macOS 26.5 and all three fire, which settles the mechanism
rather than one key: cmux does resolve a shifted-digit stroke back to the
character the keyboard produces. `(` and `)` ride on the same two lines of
grammar and are marked ⚠ only because nobody has pressed them yet.

`<prefix> 1…9` is the genuine open question. It is written `["ctrl+b", "1"]`,
where `"1"` is meant to name the whole 1…9 family exactly as it does in the
`"cmd+1"` default cmux ships for that action. That the shorthand survives into a
chord is an assumption, and it fails differently from a bad stroke: `<prefix> 1`
would work while `<prefix> 2` did nothing.

If one of them does nothing, `cmux config doctor` will still say the config is
fine — it validates JSONC syntax and lists top-level keys, and a binding it
cannot parse is simply dropped. Fix the stroke in `cmux_managed_block()` in
`modules/65-cmux.sh` and re-run `./install.sh --only cmux`.

## When the prefix looks dead

Two of the three causes are the same as herdr's, and for the same reason —
identical prefix, identical two-step shape.

**1. A non-ASCII input source is eating the second key.** With a Bopomofo (zhTW)
source active, `<C-b>` registers and the key after it never arrives:
`<prefix> %` types a Bopomofo character into the pane. Switch input source to
English. This was diagnosed on herdr, where the `[experimental]` setting that
claims to fix it reported itself applied and did nothing — see
[herdr-shortcut.md](herdr-shortcut.md#when-the-prefix-looks-dead).

**2. Caps Lock is not an English toggle.** It sends `V`, not `v`, and a shifted
key is a *different* binding — `<prefix> (` and `<prefix> 9` are not the same
chord here.

**3. Something outside cmux has the key.** A macOS system shortcut, or cmux not
being the frontmost app. `⌘,` → Keyboard Shortcuts shows cmux's live table,
which is rendered from the config rather than from a built-in list, so it is the
authority on what cmux thinks it has.

## Agent notifications

The banner an agent triggers says the **session** name, because that is the
name you think in:

```
┌──────────────────────────────┐
│ EX-1234                  now │   ← cmux workspace (session) name
│ completed                    │   ← or "needs input"
│ <the agent's last message>   │
└──────────────────────────────┘
```

cmux posts its own banner for the same events, and it cannot say that. Its
subtitle is the workspace's **project directory** — `Completed in example-app`
— and the session name is nowhere in the payload. So the managed block hands
the banner to `~/.local/bin/cmux-notify` (deployed by this module, source at
`home/.local/bin/cmux-notify`), wired up as `notifications.command`:

| Piece | Owner |
| --- | --- |
| banner text | `cmux-notify`, via `osascript` |
| the ding | cmux (`notifications.sound`, `soundOverrides` per state) |
| sidebar unread mark, pane flash, notification record | cmux |
| cmux's own banner | muted by the `osascript-owns-the-banner` hook |

Sound deliberately stays with cmux: it is configurable per state there
(`Glass` on completion, `Sosumi` when an agent wants you), and it respects Do
Not Disturb. `osascript`'s own `sound name` does not.

**The cost:** an `osascript` banner belongs to Script Editor, so clicking it
does nothing. cmux's own banner would have focused the pane. Delete the hook
from `cmux_managed_block()` to get that back — you then get two banners per
event, which is the other thing you can have but not both.

### What cmux actually hands the script

Three variables, no argv, no stdin — probed against a live agent event, not
read off a doc:

```
CMUX_NOTIFICATION_TITLE=Claude Code
CMUX_NOTIFICATION_SUBTITLE=Completed in example-app   # or "Waiting"
CMUX_NOTIFICATION_BODY=<the agent's last message>
```

Two consequences the script is built around:

- **The state is only in the subtitle**, as English prose. cmux's three agent
  categories (`turn-complete`, `needs-permission`, `idle-reminder`) arrive
  already rendered, so the script maps the prose, not a category id.
- **PATH is `/usr/bin:/bin:/usr/sbin:/sbin`** and none of cmux's own variables
  are set, so `command -v cmux` finds nothing. The session name is read back
  out of `cmux list-notifications` — its last field is `pct:<session name>` —
  using the bundle path `/Applications/cmux.app/Contents/Resources/bin/cmux`.

The body is whatever an agent last printed, and cmux's docs note it can arrive
from an SSH relay or a cloud machine. It is passed to `osascript` as `on run
argv` arguments and never interpolated into the AppleScript source, which is
the one thing those docs tell you not to do. `test/verify.sh` asserts a body
containing `$(echo pwned)` comes back out as literal text.

### When nothing appears

```sh
cmux list-notifications     # did cmux record the event at all?
CMUX_NOTIFICATION_TITLE="Claude Code" CMUX_NOTIFICATION_SUBTITLE="Waiting" \
    ~/.local/bin/cmux-notify --dry-run    # what would the banner say?
```

`--dry-run` prints `session|state|body` and posts nothing. If that is right but
no banner appears, the block is macOS: `osascript` notifications are delivered
as **Script Editor**, so that is the row to enable in System Settings →
Notifications.

## Getting this onto another machine

One line, which is the entire reason the config is spliced rather than seeded:

```sh
./install.sh --only cmux
```

It links `~/.local/bin/cmux-notify` first, then rewrites the managed block
between its two markers, leaves the rest of `~/.config/cmux/cmux.json` —
including the ~400-line commented template cmux writes on first launch — byte
for byte, backs the file up only when something actually changed, and reloads
a running cmux so the keys and the notification wiring apply without a
restart. Running it twice prints `already up to date` and touches nothing.

Per-machine settings belong in cmux's own Settings UI, **not** in a second copy
of a key in `cmux.json`: file keys override the UI, and two copies of the same
key parse fine while one of them silently loses. The module refuses to write
rather than create that situation.
