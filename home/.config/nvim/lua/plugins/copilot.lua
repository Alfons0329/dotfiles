-- GitHub Copilot.
--
-- Requires a one-time interactive login: open nvim and run `:Copilot auth`.
-- Nothing in install.sh can do this for you, so it is listed in the
-- post-install steps.
--
-- Suggestions are accepted with Ctrl-J rather than Tab, because Tab already
-- cycles blink.cmp's completion menu. Two plugins competing for Tab is the
-- same class of mistake as two plugins competing for the statusline.
--
-- Cycling moved off <C-.>/<C-,> to <M-]>/<M-[>, which frees <C-.> for the LSP
-- code action - VSCode's quick-fix key.

return {
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        event = "InsertEnter",
        opts = {
            suggestion = {
                enabled = true,
                auto_trigger = true,
                keymap = {
                    accept = "<C-j>",
                    next = "<M-]>",
                    prev = "<M-[>",
                    dismiss = "<C-]>",
                },
            },
            panel = { enabled = false },
            filetypes = {
                -- Don't send commit messages or secrets-adjacent buffers.
                gitcommit = false,
                gitrebase = false,
                -- copilot.lua disables markdown by default (internal_filetypes
                -- in copilot/client/filetypes.lua); the merge keeps whatever is
                -- set here, so it has to be re-enabled explicitly.
                markdown = true,
                ["."] = false,
                -- copilot.lua disables markdown in its internal_filetypes
                -- defaults (lua/copilot/client/filetypes.lua:4). Your config
                -- is checked first (is_ft_disabled), so this flips it back on
                -- for docs and prose.
                markdown = true,
            },
        },
    },
}
