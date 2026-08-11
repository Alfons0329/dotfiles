# VSCode → Neovim cheat-sheet

Personal learning map. Left column is the VSCode key you're used to, right
column is what actually does it here. Leader is `Space`.

This setup uses **snacks.picker** for all the fuzzy finding, **not** Telescope.
Telescope is the same category of plugin (a fuzzy finder), not a superset — it
was removed on purpose, so there's nothing to migrate. `<leader>ff` etc. are
`Snacks.picker.*`.

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
- Case matters with Shift: `<C-b>` ≠ `<C-B>`. `<S-l>` is just a capital `L`.
- `<leader>ff` means: press `Space`, then `f`, then `f`. which-key pops up
  ~400ms after you press `Space` and shows you the options — you don't have to
  memorize.

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
| `Ctrl+P` | `<leader>ff` or `Ctrl+P` | find files |
| `Ctrl+B` | `<C-b>` / `<C-n>` / `<leader>e` | toggle the sidebar (see tmux note below) |
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

## Splits (your target #1)

There's no drag-and-drop in a terminal — you **split first, then open/move** the
file.

| VSCode | Neovim | What it does |
| --- | --- | --- |
| drag file right | `<leader>sv` | split right (vertical) |
| drag file down | `<leader>sh` | split below (horizontal) |
| click a pane | `<C-h>` `<C-j>` `<C-k>` `<C-l>` | move between splits |
| — | `<leader>q` | close the current split/window |
| — | `<C-w> =` | equalize split sizes (built-in) |

Tip: inside any picker (`<leader>ff`, `<leader>fg`, …) `<C-v>` opens the
selection in a vertical split, `<C-s>` in a horizontal one — so you can
"find → split" in one motion.

## Tabs / buffers (your target #3)

Buffers are what bufferline draws as editor tabs across the top.

| VSCode | Neovim | What it does |
| --- | --- | --- |
| `Ctrl+Tab` | `<S-l>` / `<S-h>` | next / prev tab (always works) |
| `Ctrl+Tab` | `<C-PageDown>` / `<C-PageUp>` | next / prev tab |
| `Ctrl+1..9` | `<M-1>` … `<M-9>` | jump straight to tab N |
| `Ctrl+W` | `<leader>bd` | close the tab |
| — | `<leader>tn` / `<leader>tp` | next / prev tab (leader form) |

`<C-Tab>` is also bound, but it only arrives under the kitty keyboard protocol,
which tmux 3.2a doesn't pass through — so **`<S-l>`/`<S-h>` or `<C-PageDown>`
are the reliable ones** (especially over SSH in tmux).

## Code intelligence (LSP)

| VSCode | Neovim | What it does |
| --- | --- | --- |
| `F12` | `F12` or `gd` | go to definition |
| `Shift+F12` | `Shift+F12` or `gr` | find all references |
| — | `gy` / `gi` | type definition / implementation |
| hover | `K` | hover documentation |
| `F2` | `F2` or `<leader>rn` | rename symbol |
| `Ctrl+.` | `Ctrl+.` or `<leader>ca` | code action / quick-fix |
| `F8` / `Shift+F8` | `F8` / `Shift+F8` | next / prev diagnostic |
| — | `<leader>cf` | format the buffer |
| `Ctrl+Shift+O` | `<leader>fo` | document symbols outline |
| problems panel | `<leader>fd` | all diagnostics, searchable |

## Completion & Copilot

| VSCode | Neovim | What it does |
| --- | --- | --- |
| suggestion popup | automatic | blink.cmp completes as you type |
| cycle suggestion | `Tab` / `Shift+Tab` | move through the menu |
| accept | `Enter` | accept the selected completion |
| trigger manually | `Ctrl+Space` | open the menu / its docs |
| accept Copilot | `Ctrl+J` | (Tab is taken by completion) |
| cycle Copilot | `<M-]>` / `<M-[>` | next / prev Copilot suggestion |
| dismiss Copilot | `<C-]>` | dismiss |

## Editing helpers

| VSCode | Neovim | What it does |
| --- | --- | --- |
| `Alt+↑/↓` | select, then `J` / `K` | move the line/selection down/up |
| `Ctrl+/` | `Ctrl+/` (normal or visual) | toggle comment |
| `Tab`/`Shift+Tab` (indent) | `>` / `<` | indent, keeps the selection |
| paste over | `<leader>p` | paste without losing your yank register |
| `Ctrl+S` | `Ctrl+S` or `<leader>w` | save |

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
| `Tab` | toggle-select multiple |
| `?` | show the full picker keymap help |
| `<Esc>` | close |

## Gotchas worth knowing

- **tmux prefix is `C-b`.** Inside tmux (your Ghostty → SSH → tmux → nvim path)
  tmux eats `C-b` as its prefix, so nvim's sidebar key never sees it. **Use
  `<C-n>` (or `<leader>e`) for the sidebar when you're in tmux**, and keep
  `C-b s` for switching tmux sessions. Outside tmux, `<C-b>` works fine.
- **`<leader>e` is two things.** Globally it toggles the sidebar, but in a
  buffer with a language server attached it instead shows the diagnostic float
  (buffer-local wins). Use `<C-b>`/`<C-n>` for the sidebar there.
- **`<C-b>` no longer pages back.** `<C-u>` / `<C-d>` are your half-page
  up/down (and they re-center the cursor).
- **`<C-s>` needs `stty -ixon`**, which `.zshrc` already sets — otherwise the
  terminal swallows Ctrl+S and freezes until Ctrl+Q.
- **Want a real replace UI later?** The native `:%s` / `:cdo` flow above covers
  it, but if you'd rather have VSCode's find-and-replace panel, look at
  `grug-far.nvim`. Not installed by default to keep the plugin set lean.
