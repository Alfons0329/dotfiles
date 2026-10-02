-- Live markdown preview in a browser, for READMEs and design docs.
--
-- Commands: :MarkdownPreview, :MarkdownPreviewToggle, :MarkdownPreviewStop.
-- Loaded on those commands and on a markdown buffer, so it costs nothing at
-- startup.
--
-- The build step is the plugin's own downloader rather than the `cd app &&
-- yarn install` line its README leads with. That line cannot work on the
-- machines this repo sets up: yarn is in no package manifest, and node is in
-- packages/brew.txt only - the bare Ubuntu build server has neither, so a
-- yarn build would fail every install there. mkdp#util#install() fetches the
-- prebuilt server binary for the platform instead and needs no toolchain.
--
-- Commands stay scoped to markdown (g:mkdp_command_for_global is left off) so
-- :MarkdownPreview does not appear in every buffer where it has nothing to
-- render.
return {
    {
        "iamcco/markdown-preview.nvim",
        ft = { "markdown" },
        cmd = { "MarkdownPreview", "MarkdownPreviewToggle", "MarkdownPreviewStop" },
        build = function(plugin)
            -- rtp:append is not optional. On a first install the plugin's
            -- autoload/ directory is not on the runtimepath yet when lazy runs
            -- this hook, so the README's own `vim.fn["mkdp#util#install"]()`
            -- dies with `E117: Unknown function: mkdp#util#install` and leaves
            -- the plugin cloned but with no server binary to run.
            vim.opt.runtimepath:append(plugin.dir)
            vim.fn["mkdp#util#install_sync"]()
        end,
        init = function()
            -- Without this, lazy's `ft` trigger and the plugin's own filetype
            -- list can disagree about which buffers it owns.
            vim.g.mkdp_filetypes = { "markdown" }
            -- Leave the preview tab open when moving to another buffer; the
            -- default tears it down and reopens a new tab on every switch.
            vim.g.mkdp_auto_close = 0
        end,
    },
}
