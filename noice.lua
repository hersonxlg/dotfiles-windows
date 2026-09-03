return {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
        "MunifTanjim/nui.nvim",
        "rcarriga/nvim-notify",
    },
    opts = {
        lsp = {
            override = {
                -- Le devuelve a Neovim/Blink el control sobre el renderizado de markdown
                ["vim.lsp.util.convert_input_to_markdown_lines"] = false,
                ["vim.lsp.util.stylize_markdown"] = false,
                ["cmp.entry.get_documentation"] = false,
            },
        },
        presets = {
            command_palette = true,
            long_message_to_split = true,
            lsp_doc_border = true,
        },
    },
}
