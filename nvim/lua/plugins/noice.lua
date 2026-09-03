return {
    "folke/noice.nvim",
    event = "VeryLazy",
    -- Ya no requiere nui.nvim ni nvim-notify como dependencias
    opts = {
        lsp = {
            override = {
                ["vim.lsp.util.convert_input_to_markdown_lines"] = false,
                ["vim.lsp.util.stylize_markdown"] = false,
                ["cmp.entry.get_documentation"] = false,
            },
        },
        presets = {
            command_palette = true, -- Mantiene la barra flotante de ':'
            long_message_to_split = true,
            lsp_doc_border = true,
        },
    },
}
