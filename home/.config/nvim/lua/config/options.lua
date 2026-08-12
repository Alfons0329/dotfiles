-- Editor options.
local opt = vim.opt

-- Indentation: 4 spaces, no hard tabs.
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.expandtab = true
opt.smartindent = true

-- Display
opt.number = true
opt.relativenumber = false
opt.cursorline = true
opt.wrap = true
opt.scrolloff = 4
opt.signcolumn = "yes" -- always reserve the gutter so text doesn't jump when
                       -- diagnostics or git signs appear
opt.termguicolors = true
opt.laststatus = 3     -- one global statusline rather than one per split

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

-- Splits open where you expect them to
opt.splitright = true
opt.splitbelow = true

-- Files: rely on undo history and git rather than swap/backup litter.
opt.swapfile = false
opt.backup = false
opt.undofile = true

-- Responsiveness. updatetime also drives how quickly LSP diagnostics and
-- gitsigns refresh.
opt.updatetime = 250
opt.timeoutlen = 400

opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.completeopt = { "menu", "menuone", "noselect" }

-- NOTE: 'paste' is deliberately never set. Paste mode disables every
-- insert-mode mapping, which silently breaks completion keys. Neovim handles
-- bracketed paste natively, so it is unnecessary as well as harmful.

-- Trim trailing whitespace on save.
vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("trim_whitespace", { clear = true }),
    pattern = "*",
    callback = function()
        local pos = vim.api.nvim_win_get_cursor(0)
        vim.cmd([[%s/\s\+$//e]])
        vim.api.nvim_win_set_cursor(0, pos)
    end,
})

-- Briefly highlight yanked text. `vim.highlight` was renamed to `vim.hl` in
-- 0.11 and now prints a deprecation warning, so prefer the new name and keep
-- the old one as the fallback for the 0.11 floor this config supports.
vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
    callback = function()
        local hl = vim.hl or vim.highlight
        hl.on_yank({ timeout = 150 })
    end,
})
