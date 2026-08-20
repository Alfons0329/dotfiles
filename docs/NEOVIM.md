# Neovim — keys, tuning, and the tmux path

Learning map from VSCode to this config. Leader is `Space`.

This setup uses **snacks.picker** for all fuzzy finding, **not** Telescope.
Telescope is the same category of plugin (a fuzzy finder), not a superset — it
was removed on purpose, so there's nothing to migrate. `<leader>ff` etc. are
`Snacks.picker.*`. Every binding below is named in Vim's `<…>` notation and
verified against the actual config — never prose like `Ctrl+P`, because case
carries the Shift key here and prose loses it.

## How to read the keys

| Notation | Meaning | On your keyboard |
| --- | --- | --- |
| `<C-x>` | Ctrl + x | `^` |
| `<M-x>` | Meta/Alt + x | Option `⌥` |
| `<S-x>` | Shift + x | `⇧` |
| `<leader>` | the leader key | `Space` |
| `<CR>` | Enter | Return |
| `<Esc>` | Escape | `⎋` |
| `<C-w>` | Ctrl+w | the window-command prefix |

- Ctrl (`<C-`) and Alt (`<M-`) are **different physical keys**.
- A terminal **can't send Cmd (⌘)** at all. Ghostty translates `Cmd+Shift+F`
  into `<M-F>` so it reaches nvim — that's why that mapping is Alt-based.
- **Case is Shift.** `<C-b>` ≠ `<C-B>`; the capital letter already includes the
  Shift. `<S-l>` is just a capital `L`. So `<C-j>` is Ctrl+j with **no** Shift —
  a capital J written in prose is not the same claim.
- `<leader>ff` means: press `Space`, then `f`, then `f`. which-key pops up
  ~400 ms after you press `Space` and shows the options — you don't have to
  memorize.
- **`<leader>` is normal-mode only.** In insert mode `Space` inserts a literal
  space; to fire a leader command while typing, hit `<Esc>` first.

## Running inside tmux on macOS — read this first

The Ghostty → SSH → tmux → nvim path drops or eats a few chords. These are the
bindings to actually learn; the rest of the page notes each case inline.

- **Editor tabs: use `<M-1>` … `<M-9>` or `<S-l>` / `<S-h>`, not `<C-Tab>`.**
  In Ghostty (not tmux) pressing Ctrl+Tab *is* delivered and cycles nvim's
  tabs. Inside tmux it switches **tmux's own windows**, not nvim's tabs, because
  tmux only passes `<C-Tab>` through under the kitty keyboard protocol, which
  tmux 3.2a (Ubuntu 22.04) doesn't speak. `<M-1..9>` works because Ghostty sets
  `macos-option-as-alt = true`, and `<S-l>`/`<S-h>` are plain Shift letters — so
  all of them reach nvim everywhere, tmux included.
- **Code jumping: use `gd` and `<C-o>`, not `F12`.** On this Mac `Fn+F12` is
  bound at the tmux level to toggle mouse mode (a machine-local
  `claude-dashboard` binding in `~/.tmux/.tmux.conf`), so tmux consumes `F12`
  before nvim ever sees it. `gd` jumps to a definition and `<C-o>` pops back up
  the jump stack — the pair you actually want. (`F12` still works in nvim when
  it *isn't* shadowed by tmux, so it's documented below too.)
- **Sidebar: use `<C-n>`, not `<C-b>`.** tmux's prefix **is** `<C-b>`, so it
  eats the key and nvim's sidebar toggle never sees it.
- **`<C-s>` (save) needs `stty -ixon`**, which `.zshrc` already sets —
  otherwise the terminal swallows Ctrl+S as XOFF and freezes until `<C-q>`.

## Mental model

Almost everything hangs off a leader group:

| Prefix | Group | Examples |
| --- | --- | --- |
| `<leader>f` | **f**ind | `ff` files, `fg` grep, `fr` recent, `fb` buffers |
| `<leader>g` | **g**it | `gl` log, `gb` branches, `gs` status, `gg` lazygit |
| `<leader>c` | **c**ode (LSP) | `ca` code action, `cf` format |
| `<leader>b` | **b**uffer | `bd` close tab |
| `<leader>h` | git **h**unk | `hp` preview, `hb` blame, `hr` reset |
| `<leader>s` | **s**plit / search-replace | `sv`/`sh` splits, `sr` replace |
| `<leader>t` | **t**ab | `tn` next, `tp` prev |

## Files & sidebar

| VSCode | Neovim | What it does |
| --- | --- | --- |
| `Ctrl+P` | `<C-p>` or `<leader>ff` | find files |
| `Ctrl+B` | `<C-n>` / `<leader>e` / `<C-b>` | toggle the sidebar (**`<C-n>` in tmux**) |
| Open Recent | `<leader>fr` | recent files |
| `Ctrl+Tab` (list) | `<leader>fb` | open buffers, searchable |
| — | `<leader>fh` | search help tags |

## Search

| VSCode | Neovim | What it does |
| --- | --- | --- |
| `Ctrl+Shift+F` | `<leader>fg` | grep the whole project |
| select → `Ctrl+Shift+F` | `<leader>fw` or `<M-F>` | grep the word/selection under the cursor |
| `Ctrl+F` (in file) | `<leader>fl` | fuzzy-find a line in this buffer |
| `Ctrl+Shift+H` (replace) | `<leader>sr` | find-and-replace in this buffer (prefills `:%s///gc`) |

**Project-wide replace** (no single key): `<leader>fg` to grep → in the picker
press `<C-q>` to send the hits to the quickfix list → `:cdo s/old/new/gc | update`.

## Splits

There's no drag-and-drop in a terminal — you **split first, then open/move** the
file.

| VSCode | Neovim | What it does |
| --- | --- | --- |
| drag file right | `<leader>sv` | split right (vertical) |
| drag file down | `<leader>sh` | split below (horizontal) |
| click a pane | `<C-h>` `<C-j>` `<C-k>` `<C-l>` | move between splits |
| — | `<leader>q` | close the current split/window |
| — | `<C-w> =` | equalize split sizes (built-in) |

The sidebar and any terminal panel are just windows, so `<C-h>` / `<C-l>` is
also how you move between the explorer and the editor. Tip: inside any picker
(`<leader>ff`, `<leader>fg`, …) `<C-v>` opens the selection in a vertical
split, `<C-s>` in a horizontal one — so you can "find → split" in one motion.

## Tabs / buffers

Buffers are what bufferline draws as editor tabs across the top.

| VSCode | Neovim | What it does |
| --- | --- | --- |
| `Ctrl+1..9` | `<M-1>` … `<M-9>` | jump straight to tab N (tmux-safe) |
| `Ctrl+Tab` | `<S-l>` / `<S-h>` | next / prev tab (tmux-safe) |
| `Ctrl+Tab` | `<C-Tab>` / `<C-S-Tab>` | next / prev tab — **only outside tmux** |
| `Ctrl+PageDown/Up` | `<C-PageDown>` / `<C-PageUp>` | next / prev tab |
| `Ctrl+W` | `<leader>bd` | close the tab |
| — | `<leader>tn` / `<leader>tp` | next / prev tab (leader form) |

`<C-Tab>` is bound and does work in Ghostty, but only under the kitty keyboard
protocol, which tmux 3.2a doesn't pass through — so **`<S-l>`/`<S-h>` or
`<M-1..9>` are the reliable ones** (especially over SSH in tmux).

## Code intelligence (LSP)

| VSCode | Neovim | What it does |
| --- | --- | --- |
| `F12` | `gd` (or `<F12>`) | go to definition |
| — | `<C-o>` / `<C-i>` | jump back / forward after a `gd` dive |
| `Shift+F12` | `gr` (or `<S-F12>`) | find all references |
| — | `gy` / `gi` | type definition / implementation |
| hover | `K` | hover documentation |
| `F2` | `<F2>` or `<leader>rn` | rename symbol |
| `Ctrl+.` | `<C-.>` or `<leader>ca` | code action / quick-fix |
| `F8` / `Shift+F8` | `<F8>` / `<S-F8>` | next / prev diagnostic |
| — | `<leader>cf` | format the buffer |
| `Ctrl+Shift+O` | `<leader>fo` | document symbols outline |
| problems panel | `<leader>fd` | all diagnostics, searchable |

`gd` `gy` `gi` `gr` `K` and the `<leader>r`/`<leader>c` maps are buffer-local
(they only exist once a language server attaches), so they shadow built-in
motions only where a server is running. `<F12>`/`<S-F12>` are global and go
through the same snacks pickers, so several results open a searchable list with
a preview rather than a quickfix window.

## Completion & Copilot

| VSCode | Neovim | What it does |
| --- | --- | --- |
| suggestion popup | automatic | blink.cmp completes as you type |
| cycle suggestion | `<Tab>` / `<S-Tab>` | move through the menu |
| accept | `<CR>` | accept the selected completion |
| trigger manually | `<C-Space>` | open the menu / its docs |
| accept Copilot | `<C-j>` | (Tab is taken by completion) |
| cycle Copilot | `<M-]>` / `<M-[>` | next / prev Copilot suggestion |
| dismiss Copilot | `<C-]>` | dismiss |

Copilot's accept is `<C-j>` rather than Tab precisely so it can't fight
blink.cmp's Tab-to-cycle — two plugins competing for one key is the same class
of mistake as two plugins fighting over the statusline.

## Editing helpers

| VSCode | Neovim | What it does |
| --- | --- | --- |
| `Alt+↑/↓` | select, then `J` / `K` | move the line/selection down/up |
| `Ctrl+/` | `<C-/>` (normal or visual) | toggle comment |
| `Tab`/`Shift+Tab` (indent) | `>` / `<` | indent, keeps the selection |
| paste over | `<leader>p` | paste without losing your yank register |
| `Ctrl+S` | `<C-s>` or `<leader>w` | save |

## Git

| VSCode | Neovim | What it does |
| --- | --- | --- |
| gutter | automatic | gitsigns in the sign column |
| next/prev change | `]c` / `[c` | jump between hunks |
| — | `<leader>hp` | preview the hunk |
| git blame line | `<leader>hb` | blame the current line |
| discard hunk | `<leader>hr` | reset the hunk |
| history | `<leader>gl` / `<leader>gb` / `<leader>gs` | log / branches / status |
| — | `<leader>gg` | lazygit |
| open on GitHub | `<leader>gB` | open in browser |

## Terminal & misc

| VSCode | Neovim | What it does |
| --- | --- | --- |
| `` Ctrl+` `` | `<C-\>` | toggle a terminal panel |
| highlight symbol | automatic | `snacks.words` highlights it |
| next/prev use of symbol | `]]` / `[[` | jump between references |
| clear search highlight | `<Esc>` | after a `/` search |

## Inside a picker (the fuzzy window)

When a picker (`<leader>ff`, `<leader>fg`, …) is open:

| Key | What it does |
| --- | --- |
| `<C-n>` / `<C-p>` or `↓`/`↑` | move through results |
| `<CR>` | open it |
| `<C-v>` / `<C-s>` | open in a vertical / horizontal split |
| `<C-q>` | send all results to the quickfix list |
| `<Tab>` | toggle-select multiple |
| `?` | show the full picker keymap help |
| `<Esc>` | close |

## Gotchas worth knowing

- **tmux prefix is `<C-b>`.** Inside tmux it eats `<C-b>` as its prefix, so
  nvim's sidebar key never sees it. **Use `<C-n>` (or `<leader>e`) for the
  sidebar in tmux**, and keep `<C-b> s` for switching tmux sessions. Outside
  tmux, `<C-b>` works fine.
- **`<F12>` is taken by tmux on this Mac** (mouse toggle, see the tmux section
  above). `gd` / `gr` / `<C-o>` cover everything it did.
- **`<leader>e` is two things.** Globally it toggles the sidebar, but in a
  buffer with a language server attached it instead shows the diagnostic float
  (buffer-local wins). Use `<C-b>`/`<C-n>` for the sidebar there.
- **`<C-b>` no longer pages back.** `<C-u>` / `<C-d>` are your half-page
  up/down (and they re-centre the cursor).
- **`<C-s>` needs `stty -ixon`**, which `.zshrc` already sets — otherwise the
  terminal swallows Ctrl+S and freezes until Ctrl+Q.
- **Completion too noisy?** The `buffer` source does fuzzy *substring*
  matching, so typing `of` also surfaces `confluence` and long base64 tokens.
  The LSP/path/snippet suggestions are separate and stay precise. To silence it
  for one buffer: `<Esc>` then
  `:lua require('blink.cmp').setup({ sources = { default = { 'lsp', 'path', 'snippets' } } })`.
  (Session-only; drops just the fuzzy `buffer` source.) Ask if you want a
  permanent `<leader>ct` toggle wired in.
- **Want a real replace UI later?** The native `:%s` / `:cdo` flow above covers
  it, but if you'd rather have VSCode's find-and-replace panel, look at
  `grug-far.nvim`. Not installed by default to keep the plugin set lean.
