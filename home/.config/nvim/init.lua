-- ~/.config/nvim/init.lua
--
-- A self-contained Neovim configuration. It deliberately does NOT source
-- ~/.vimrc or any VimScript framework: exactly one plugin owns the statusline
-- and exactly one sets the colorscheme, which is what keeps the statusline from
-- flickering between two competing owners.
--
-- Layout:
--   lua/config/options.lua   editor settings
--   lua/config/keymaps.lua   keymaps that don't depend on a plugin
--   lua/config/lazy.lua      plugin manager bootstrap
--   lua/plugins/*.lua        one file per concern, each returning a lazy spec

-- Leader must be set before lazy.nvim loads, or plugin-defined <leader>
-- mappings bind to the wrong key.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")
require("config.keymaps")
require("config.lazy")
