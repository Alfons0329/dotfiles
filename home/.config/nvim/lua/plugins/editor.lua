-- Navigation and quality of life, almost all of it from snacks.nvim.
--
-- snacks replaces what used to be four plugins here - telescope, plenary,
-- telescope-fzf-native and nvim-tree - with one, and it is the better trade for
-- this repo specifically: telescope-fzf-native compiles C at install time, so
-- dropping it takes a build step out of a machine setup that has to work on a
-- fresh box behind a corporate proxy.
--
-- What is deliberately NOT snacks: the colorscheme, statusline, editor tabs,
-- git gutter, treesitter, LSP and completion. snacks does not do those, and
-- the ones it does touch (statuscolumn) would fight gitsigns for the gutter.
-- One owner per concern.
--
-- Keymaps, VSCode equivalents on the right:
--   <leader>ff  find files            Ctrl+P
--   <leader>fg  grep the project      Ctrl+Shift+F
--   <leader>fr  recent files          File > Open Recent
--   <leader>fb  open buffers          Ctrl+Tab
--   <leader>gl  git log               GitLens history
--   <C-b>       toggle the explorer   Ctrl+B
--   <M-F>       grep word/selection   double-click then Ctrl+Shift+F

-- Treesitter parsers. `:TSUpdate` at install time starts these but does not
-- finish them - it is async, and nvim exits first - so expect some to compile
-- the first time you open that filetype. That is the intended behaviour, not an
-- oversight: these are multi-megabyte generated C files (typescript's parser.c
-- is 17.5 MB), and compiling the whole list serially takes over half an hour,
-- which does not belong in a machine-setup script. auto_install below is what
-- makes the lazy path work.
--
-- Neovim already bundles parsers for c, lua, markdown, markdown_inline, query,
-- vim and vimdoc, so they are left out: asking nvim-treesitter to build its own
-- copy of `vim` fails every run (a permanent "failed: 1" in the install output)
-- while .vim files highlight perfectly from the bundled one.
vim.g.dotfiles_ts_parsers = {
    "bash", "diff", "dockerfile", "go", "json",
    "python", "toml", "tsx", "typescript", "yaml",
}

-- The explorer is a picker in disguise and has no toggle of its own, so ask the
-- picker registry whether one is already open.
local function explorer_toggle()
    local open = Snacks.picker.get({ source = "explorer" })[1]
    if open then
        open:close()
    else
        Snacks.explorer.open()
    end
end

return {
    {
        "folke/snacks.nvim",
        priority = 1000,
        -- Not lazy: bigfile, quickfile, indent and the netrw replacement all
        -- have to be in place before the first buffer is read.
        lazy = false,
        ---@type snacks.Config
        opts = {
            bigfile = { enabled = true },   -- disable the expensive bits on huge files
            quickfile = { enabled = true }, -- render the file before loading plugins
            indent = { enabled = true },    -- indent guides, as VSCode draws them
            input = { enabled = true },     -- prettier vim.ui.input, used by F2 rename
            notifier = { enabled = true },  -- LSP progress and messages as toasts
            scope = { enabled = true },     -- indent-scope text objects and motions
            words = { enabled = true },     -- highlight the symbol under the cursor
            picker = { enabled = true },
            explorer = { enabled = true },  -- also replaces netrw
        },
        keys = {
            -- Files and search. These follow the snacks convention, with the
            -- one divergence that <leader>fg is a project grep rather than
            -- upstream's git-files picker - grep is the daily driver.
            { "<leader>ff", function() Snacks.picker.files() end,     desc = "Find files" },
            { "<C-p>",      function() Snacks.picker.files() end,     desc = "Find files" },
            { "<leader>fg", function() Snacks.picker.grep() end,      desc = "Grep in project" },
            { "<leader>fr", function() Snacks.picker.recent() end,    desc = "Recent files" },
            { "<leader>fb", function() Snacks.picker.buffers() end,   desc = "Open buffers" },
            { "<leader>fh", function() Snacks.picker.help() end,      desc = "Help tags" },
            { "<leader>fd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
            { "<leader>fo", function() Snacks.picker.lsp_symbols() end, desc = "Document symbols" },
            { "<leader>fl", function() Snacks.picker.lines() end,     desc = "Search in buffer" },
            { "<leader>f;", function() Snacks.picker.resume() end,    desc = "Resume last picker" },

            -- Grep the word under the cursor, or the visual selection. This is
            -- VSCode's select-then-Ctrl+Shift+F, and <M-F> is what both
            -- terminal emulators translate Cmd+Shift+F into - see the keybind
            -- in home/.config/ghostty/config and the iTerm2 profile. <M-F> is
            -- used rather than <C-S-f> because every terminal can transmit it,
            -- including through tmux over SSH.
            { "<leader>fw", function() Snacks.picker.grep_word() end, desc = "Grep word/selection", mode = { "n", "x" } },
            { "<M-F>",      function() Snacks.picker.grep_word() end, desc = "Grep word/selection", mode = { "n", "x" } },

            -- Explorer, the VSCode sidebar.
            { "<C-b>",      explorer_toggle, desc = "Toggle side pane" },
            { "<C-n>",      explorer_toggle, desc = "Toggle side pane" },
            { "<leader>e",  explorer_toggle, desc = "Toggle side pane" },

            -- Git.
            { "<leader>gl", function() Snacks.picker.git_log() end,      desc = "Git log" },
            { "<leader>gb", function() Snacks.picker.git_branches() end, desc = "Git branches" },
            { "<leader>gs", function() Snacks.picker.git_status() end,   desc = "Git status" },
            { "<leader>gg", function() Snacks.lazygit() end,             desc = "Lazygit" },
            { "<leader>gB", function() Snacks.gitbrowse() end,           desc = "Open in browser", mode = { "n", "x" } },

            -- A terminal in the editor, VSCode's panel.
            { "<C-\\>",     function() Snacks.terminal.toggle() end, desc = "Toggle terminal", mode = { "n", "t" } },

            -- Jump between references to the symbol under the cursor.
            { "]]", function() Snacks.words.jump(1, true) end,  desc = "Next reference",     mode = { "n", "t" } },
            { "[[", function() Snacks.words.jump(-1, true) end, desc = "Previous reference", mode = { "n", "t" } },
        },
        init = function()
            -- Open the explorer at startup, the way VSCode always shows its
            -- file tree, then hand focus back to the file so typing starts in
            -- the editor rather than the sidebar.
            vim.api.nvim_create_autocmd("VimEnter", {
                group = vim.api.nvim_create_augroup("snacks_explorer_open", { clear = true }),
                callback = function(data)
                    -- Never headless: `nvim --headless` is how the test suite
                    -- and the plugin sync run, and a picker there is at best
                    -- noise and at worst a hang.
                    if #vim.api.nvim_list_uis() == 0 then return end

                    -- A directory argument is already the explorer's own job
                    -- via replace_netrw; don't open a second one.
                    if vim.fn.isdirectory(data.file) == 1 then return end

                    Snacks.explorer.open()
                    vim.schedule(function() pcall(vim.cmd, "wincmd p") end)
                end,
            })
        end,
    },

    {
        "nvim-treesitter/nvim-treesitter",
        -- The default branch is now `main`, a rewrite that no longer ships the
        -- `nvim-treesitter.configs` module named below - so an unpinned clone
        -- throws on every file open and you silently lose all highlighting.
        -- `master` also keeps auto_install, which means a language that isn't
        -- in the list still highlights itself the first time you open one.
        branch = "master",
        build = ":TSUpdate",
        event = { "BufReadPost", "BufNewFile" },
        main = "nvim-treesitter.configs",
        opts = {
            -- Parsers compile on install; keep the default set small and let
            -- auto_install pick up anything else on demand.
            ensure_installed = vim.g.dotfiles_ts_parsers,
            auto_install = true,
            highlight = { enable = true },
            indent = { enable = true },
        },
    },

    {
        -- Auto-closing brackets and quotes, as VSCode does by default.
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        opts = {},
    },

    {
        -- Shows which keys are available after a prefix. Mostly here so the
        -- leader mappings above are discoverable rather than memorised.
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {},
    },
}
