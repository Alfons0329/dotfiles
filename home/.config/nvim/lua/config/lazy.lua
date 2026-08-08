-- lazy.nvim bootstrap.
--
-- Clones the plugin manager on first launch, then hands it lua/plugins/ to
-- resolve. `import = "plugins"` picks up every file in that directory, so
-- adding a plugin means adding a file, not editing a list.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local repo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({
        "git", "clone", "--filter=blob:none", "--branch=stable", repo, lazypath,
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = { { import = "plugins" } },
    install = { colorscheme = { "vscode" } },
    checker = { enabled = false }, -- don't phone home for updates on startup
    change_detection = { notify = false },
    performance = {
        rtp = {
            -- Built-in plugins that only cost startup time here.
            disabled_plugins = {
                "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin", "netrwPlugin",
            },
        },
    },
})
