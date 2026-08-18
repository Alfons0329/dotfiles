-- Appearance: colorscheme, statusline, editor tabs, git gutter.
--
-- Indent guides are not here: snacks.nvim owns those (see plugins/editor.lua).
--
-- Exactly one plugin owns each of these. The previous setup ran vim-airline on
-- top of a framework that already bundled lightline; both wrote to
-- &statusline from their own autocmds, so whichever fired last won and the
-- statusline visibly changed style after every :w. Keeping one owner per
-- concern is the entire fix.
--
-- The colorscheme is chosen by ~/.dotfiles_theme (written by install.sh
-- --theme), so nvim and Ghostty ship the same palette on a given machine.
-- Exactly one colorscheme plugin is returned below, so only one loads and
-- calls :colorscheme at startup - switching themes swaps the plugin spec, and
-- lazy.nvim installs the new one on the next launch.

local active_theme = function()
    local path = vim.fn.expand("~/.dotfiles_theme")
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then return "tokyonight" end
    for _, line in ipairs(lines) do
        local name = line:match('^DOTFILES_THEME="(.+)"$')
        if name then return name end
    end
    return "tokyonight"
end

local theme = active_theme()

local colorscheme_plugins = {
    tokyonight = {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000, -- must load before anything that reads highlight groups
        opts = {
            style = "night",
            transparent = false,
            styles = { comments = { italic = true } },
            on_highlights = function(hl, c)
                -- The stock CursorLine is a couple of shades off the background
                -- and effectively invisible on a dark terminal - the complaint
                -- that started this. Lift it, and make the line number carry
                -- the accent so the cursor row is findable at a glance.
                hl.CursorLine = { bg = c.bg_highlight }
                hl.CursorLineNr = { fg = c.orange, bold = true }
            end,
        },
        config = function(_, opts)
            require("tokyonight").setup(opts)
            vim.cmd.colorscheme("tokyonight")
        end,
    },
    kanagawa = {
        "rebelot/kanagawa.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd.colorscheme("kanagawa")
        end,
    },
    ["ayu-dark"] = {
        "Shatur/neovim-ayu",
        lazy = false,
        priority = 1000,
        opts = { mirage = false, terminal = true },
        config = function(_, opts)
            require("ayu").setup(opts)
            vim.cmd.colorscheme("ayu-dark")
        end,
    },
}

-- Map each editor theme to the lualine theme name, or "auto" when lualine has
-- none built in (kanagawa). "auto" derives the statusline colours from the
-- active highlight groups, so a missing theme module degrades the colours
-- instead of breaking the statusline outright.
local lualine_theme_name = {
    tokyonight = "tokyonight",
    kanagawa = "auto",
    ["ayu-dark"] = "ayu_dark",
}
local lualine_theme =
    pcall(require, "lualine.themes." .. lualine_theme_name[theme]) and lualine_theme_name[theme]
    or "auto"

return {
    colorscheme_plugins[theme] or colorscheme_plugins.tokyonight,

    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        event = "VeryLazy",
        opts = function()
            return {
                options = {
                    theme = lualine_theme,
                    globalstatus = true, -- pairs with laststatus=3
                    -- Powerline separators, matching the tmux status bar, which
                    -- names the same four codepoints at .tmux.conf.local's
                    -- tmux_conf_theme_*_separator_* settings.
                    --
                    -- Written as \u{} escapes rather than pasted literally: as
                    -- literals these are unprintable private-use-area bytes, and
                    -- they silently vanished once already - this file shipped
                    -- `left = "", right = ""` under this very comment, which is
                    -- why the statusline rendered as flat rectangles instead of
                    -- arrows. An escape is visible in a diff; a lost PUA byte is
                    -- not. They still need a patched font in the terminal
                    -- emulator, or they show as tofu boxes.
                    component_separators = { left = "\u{e0b1}", right = "\u{e0b3}" },
                    section_separators = { left = "\u{e0b0}", right = "\u{e0b2}" },
                    disabled_filetypes = { statusline = { "NvimTree" } },
                },
                sections = {
                    lualine_a = { "mode" },
                    lualine_b = { "branch", "diff", "diagnostics" },
                    lualine_c = { { "filename", path = 1 } },
                    lualine_x = { "encoding", "fileformat", "filetype" },
                    lualine_y = { "progress" },
                    lualine_z = { "location" },
                },
            }
        end,
    },

    {
        -- Editor tabs across the top, the way VSCode shows open files.
        --
        -- Cycling is bound to Ctrl+PageDown/PageUp *and* Ctrl+Tab. Ctrl+Tab is
        -- VSCode's own key but a legacy terminal encodes it as the same byte as
        -- plain Tab, so it only arrives under the kitty keyboard protocol -
        -- which tmux 3.2a, the version on Ubuntu 22.04, does not pass through.
        -- Mapping it costs nothing (where the protocol is absent Neovim never
        -- sees the event, so bare <Tab> keeps its <C-i> jumplist meaning) but it
        -- cannot be the only binding.
        "akinsho/bufferline.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        event = "VeryLazy",
        keys = {
            { "<C-PageDown>", "<cmd>BufferLineCycleNext<CR>", desc = "Next editor tab" },
            { "<C-PageUp>",   "<cmd>BufferLineCyclePrev<CR>", desc = "Previous editor tab" },
            { "<C-Tab>",      "<cmd>BufferLineCycleNext<CR>", desc = "Next editor tab" },
            { "<C-S-Tab>",    "<cmd>BufferLineCyclePrev<CR>", desc = "Previous editor tab" },
            { "<leader>bd",   "<cmd>bdelete<CR>",             desc = "Close editor tab" },
        },
        opts = {
            options = {
                diagnostics = "nvim_lsp",
                show_buffer_close_icons = true,
                separator_style = "thin",
                offsets = {
                    -- Keep the tab strip clear of the sidebar, as VSCode does.
                    { filetype = "NvimTree", text = "Explorer", highlight = "Directory" },
                },
            },
        },
        config = function(_, opts)
            require("bufferline").setup(opts)

            -- Alt+1..9 jumps straight to a tab, matching VSCode's Cmd/Ctrl+1..9.
            -- Those chords cannot be used directly: a terminal cannot transmit
            -- Cmd at all, and Ctrl+<digit> is not a distinct control code.
            for i = 1, 9 do
                vim.keymap.set("n", ("<M-%d>"):format(i), function()
                    require("bufferline").go_to(i, true)
                end, { desc = ("Go to editor tab %d"):format(i) })
            end
        end,
    },

    {
        -- Git gutter. snacks has a statuscolumn module that can render these
        -- too; it stays disabled so exactly one plugin owns the sign column.
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            signs = {
                add          = { text = "│" },
                change       = { text = "│" },
                delete       = { text = "_" },
                topdelete    = { text = "‾" },
                changedelete = { text = "~" },
            },
            on_attach = function(bufnr)
                local gs = package.loaded.gitsigns
                local function map(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
                end
                map("n", "]c", gs.next_hunk, "Next git hunk")
                map("n", "[c", gs.prev_hunk, "Previous git hunk")
                map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
                map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
                map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
            end,
        },
    },
}
