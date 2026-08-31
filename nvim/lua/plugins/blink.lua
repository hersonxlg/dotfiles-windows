return {
    "saghen/blink.cmp",
    version = "*",

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
        keymap = {
            preset = "none", -- Desactivamos los presets para definir las teclas explícitamente

            ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
            ["<C-e>"] = { "hide" },
            ["<CR>"] = { "accept", "fallback" },

            -- 🚀 Configuración explícita de TAB y SHIFT-TAB estilo VS Code
            ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
            ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },

            ["<Up>"] = { "select_prev", "fallback" },
            ["<Down>"] = { "select_next", "fallback" },
        },

        appearance = {
            use_nvim_cmp_as_default = true,
            nerd_font_variant = "mono",
        },

        sources = {
            default = { "lsp", "path", "snippets", "buffer" },
        },

        completion = {
            documentation = { auto_show = true, auto_show_delay_ms = 200 },
            menu = { border = "rounded" },
        },
    },
    opts_extend = { "sources.default" },
}
