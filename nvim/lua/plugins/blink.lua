return {
    "saghen/blink.cmp",
    version = "v1.10.2",
    dependencies = {
        "rafamadriz/friendly-snippets",
    },

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
        keymap = {
            preset = "none",

            ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
            ["<C-e>"] = { "hide" },
            ["<CR>"] = { "accept", "fallback" },

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
            providers = {
                lsp = {
                    transform_items = function(_, items)
                        for _, item in ipairs(items) do
                            if item.documentation and type(item.documentation) == "string" then
                                item.documentation = item.documentation:gsub("&nbsp;", " ")
                            elseif
                                item.documentation
                                and type(item.documentation) == "table"
                                and item.documentation.value
                            then
                                item.documentation.value = item.documentation.value:gsub("&nbsp;", " ")
                            end
                        end
                        return items
                    end,
                },
            },
        },

        completion = {
            documentation = {
                auto_show = true,
                auto_show_delay_ms = 200,
                window = { border = "rounded" },
            },
            menu = { border = "rounded" },
        },
    },
    opts_extend = { "sources.default" },
}
