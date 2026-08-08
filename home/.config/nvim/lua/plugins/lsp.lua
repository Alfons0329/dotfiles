-- Language servers and completion.
--
-- Replaces coc.nvim with Neovim's built-in LSP client plus blink.cmp. The
-- go-to keymaps are kept identical to the old coc bindings so nothing has to
-- be relearned:
--   gd  definition      gy  type definition
--   gi  implementation  gr  references        K  hover

return {
    {
        "williamboman/mason.nvim",
        cmd = { "Mason", "MasonInstall", "MasonUpdate" },
        opts = {},
    },

    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "saghen/blink.cmp",
        },
        config = function()
            -- Servers are installed by install.sh (on by default, disable with
            -- --no-lsp-servers), not from here: a mason download that fails on
            -- a restricted network must not take the editor down with it.
            local servers = {
                lua_ls = {
                    settings = {
                        Lua = {
                            -- Stop lua_ls asking which runtime this is, and
                            -- stop it flagging `vim` as undefined.
                            runtime = { version = "LuaJIT" },
                            diagnostics = { globals = { "vim" } },
                            workspace = {
                                library = vim.api.nvim_get_runtime_file("", true),
                                checkThirdParty = false,
                            },
                            telemetry = { enable = false },
                        },
                    },
                },
                basedpyright = {},
                ts_ls = {},
                bashls = {},
                jsonls = {},
                gopls = {},
            }

            require("mason-lspconfig").setup({
                -- Servers are installed by install.sh, not from here.
                ensure_installed = {},
                -- mason-lspconfig v2 dropped `automatic_installation` and
                -- defaults `automatic_enable` to true, which would enable every
                -- installed server a second time with stock settings - fighting
                -- the vim.lsp.config/vim.lsp.enable calls below over
                -- capabilities and per-server options. One owner per concern.
                automatic_enable = false,
            })

            local capabilities = require("blink.cmp").get_lsp_capabilities()

            for name, cfg in pairs(servers) do
                cfg.capabilities = capabilities
                vim.lsp.config(name, cfg)
            end
            vim.lsp.enable(vim.tbl_keys(servers))

            -- Buffer-local keymaps, attached only where a server is running.
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("lsp_attach", { clear = true }),
                callback = function(event)
                    local function map(keys, fn, desc)
                        vim.keymap.set("n", keys, fn, { buffer = event.buf, desc = desc })
                    end
                    -- Routed through snacks pickers rather than vim.lsp.buf,
                    -- so several results land in a searchable list with a
                    -- preview instead of a bare quickfix window. Falls back to
                    -- the builtin if snacks is somehow not loaded.
                    local function pick(source, builtin)
                        return function()
                            if Snacks and Snacks.picker then
                                Snacks.picker[source]()
                            else
                                builtin()
                            end
                        end
                    end

                    map("gd", pick("lsp_definitions", vim.lsp.buf.definition), "Go to definition")
                    map("gy", pick("lsp_type_definitions", vim.lsp.buf.type_definition), "Go to type definition")
                    map("gi", pick("lsp_implementations", vim.lsp.buf.implementation), "Go to implementation")
                    map("gr", pick("lsp_references", vim.lsp.buf.references), "List references")
                    map("K",  vim.lsp.buf.hover, "Hover documentation")
                    map("<leader>rn", vim.lsp.buf.rename,      "Rename symbol")
                    map("<leader>ca", vim.lsp.buf.code_action, "Code action")
                    map("<leader>e",  vim.diagnostic.open_float, "Show diagnostic")
                    map("<leader>cf", function()
                        vim.lsp.buf.format({ async = true })
                    end, "Format buffer")
                end,
            })

            vim.diagnostic.config({
                virtual_text = { spacing = 2, prefix = "●" },
                severity_sort = true,
                float = { border = "rounded", source = true },
            })
        end,
    },

    {
        "saghen/blink.cmp",
        version = "*", -- use a tagged release: it ships a prebuilt fuzzy matcher
        event = "InsertEnter",
        opts = {
            keymap = {
                preset = "default",
                -- Tab/Shift-Tab to cycle and Enter to accept, matching the old
                -- coc.nvim mappings.
                ["<Tab>"]   = { "select_next", "snippet_forward", "fallback" },
                ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
                ["<CR>"]    = { "accept", "fallback" },
                ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
            },
            appearance = { nerd_font_variant = "mono" },
            sources = { default = { "lsp", "path", "snippets", "buffer" } },
            completion = {
                documentation = { auto_show = true, auto_show_delay_ms = 200 },
            },
        },
    },
}
