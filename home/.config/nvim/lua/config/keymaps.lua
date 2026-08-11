-- Plugin-independent keymaps. Plugin-specific ones live with their plugin spec
-- so that a disabled plugin takes its keymaps with it.
local map = vim.keymap.set

-- Clear search highlight.
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Window navigation without the <C-w> prefix.
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Keep the cursor centred when paging and jumping between search hits.
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Move the selected lines up/down, reindenting as they go.
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Keep the yank register when pasting over a selection.
map("x", "<leader>p", [["_dP]], { desc = "Paste without clobbering register" })

-- Stay in visual mode after shifting.
map("v", "<", "<gv")
map("v", ">", ">gv")

map("n", "<leader>w", "<cmd>write<CR>", { desc = "Write buffer" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit window" })

-- Splits. VSCode's "drag the file to the right" has no drag in a terminal, so
-- the workflow is: split first, then open or move the file into it. These only
-- *create* the split - moving between them is the <C-hjkl> block above, and
-- splitright/splitbelow (options.lua) make them open where you expect.
map("n", "<leader>sv", "<cmd>vsplit<CR>", { desc = "Split window right" })
map("n", "<leader>sh", "<cmd>split<CR>",  { desc = "Split window below" })

-- Buffer cycling, the vim-native equivalent of the editor-tab keys in
-- lua/plugins/ui.lua.
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })

-- Leader aliases for tab cycling, the "tab next/prev" mnemonic. Buffers are
-- what bufferline renders as editor tabs, so these are the same action as
-- <S-l>/<S-h> and the <C-PageDown> pair - kept as the discoverable <leader>t
-- form for anyone reaching for it.
map("n", "<leader>tn", "<cmd>bnext<CR>",     { desc = "Next editor tab" })
map("n", "<leader>tp", "<cmd>bprevious<CR>", { desc = "Previous editor tab" })

-- Search-and-replace. <leader>fr is taken (recent files), so replace lives
-- under <leader>sr. This prefills the per-buffer substitute command with the
-- confirm flag; the project-wide flow is <leader>fg to grep, <C-q> to send the
-- hits to the quickfix list, then :cdo s/old/new/gc | update.
map("n", "<leader>sr", ":%s///gc<Left><Left><Left><Left>", { desc = "Find and replace in buffer" })

-- -------------------------------------------------------------------
-- VSCode-shaped bindings
-- -------------------------------------------------------------------
-- These are global rather than buffer-local. VSCode's F12 works everywhere, the
-- keys shadow nothing built in, and a global map is assertable from a headless
-- test. The g-prefixed LSP maps (gd/gy/gi/gr/K) stay buffer-local in the
-- LspAttach handler in lua/plugins/lsp.lua, where they belong: those *do*
-- shadow built-in motions and should only exist where a server is running.
-- F12/Shift+F12 go through the snacks pickers, the same as gd/gr, so several
-- results open a searchable list with a preview rather than a quickfix window.
map("n", "<F12>", function()
    if Snacks and Snacks.picker then Snacks.picker.lsp_definitions() else vim.lsp.buf.definition() end
end, { desc = "Go to definition" })
map("n", "<S-F12>", function()
    if Snacks and Snacks.picker then Snacks.picker.lsp_references() else vim.lsp.buf.references() end
end, { desc = "Find all references" })
map("n", "<F2>", vim.lsp.buf.rename, { desc = "Rename symbol" })
map({ "n", "v" }, "<C-.>", vim.lsp.buf.code_action, { desc = "Code action" })

-- Save. <cmd> does not change mode, so the same mapping works from insert.
-- This only reaches Neovim because ~/.zshrc runs `stty -ixon`; otherwise the
-- terminal swallows Ctrl+S as XOFF and freezes the display.
map({ "n", "i", "v" }, "<C-s>", "<cmd>write<CR>", { desc = "Save file" })

-- Toggle comment, using Neovim's built-in gc operator. Mapped twice because
-- most terminals transmit Ctrl+/ as Ctrl+_.
map("n", "<C-/>", "gcc", { remap = true, desc = "Toggle comment" })
map("n", "<C-_>", "gcc", { remap = true, desc = "Toggle comment" })
map("x", "<C-/>", "gc",  { remap = true, desc = "Toggle comment" })
map("x", "<C-_>", "gc",  { remap = true, desc = "Toggle comment" })

-- Diagnostics navigation, VSCode's F8.
map("n", "<F8>",   function() vim.diagnostic.jump({ count = 1, float = true }) end,
    { desc = "Next diagnostic" })
map("n", "<S-F8>", function() vim.diagnostic.jump({ count = -1, float = true }) end,
    { desc = "Previous diagnostic" })
