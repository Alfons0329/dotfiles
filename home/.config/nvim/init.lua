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

-- Machine-local overrides: lua/config/local.lua, gitignored, absent by default.
-- Loaded last so it wins - a different `vim.cmd.colorscheme`, a work-specific
-- keymap, an LSP the shared config has no business knowing about. pcall because
-- the file genuinely does not exist on most machines and a missing optional
-- module must not take the whole config down.
--
-- Same arrangement as ~/.zshrc.local, ~/.tmux.conf.user, and Ghostty's
-- ghostty-local.conf.
pcall(require, "config.local")
