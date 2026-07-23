return {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },

    opts = {
        indent = {
            char = "▏",
            tab_char = "▏",
        },

        scope = {
            enabled = true,
            show_start = false,
            show_end = false,
            -- Forzamos a IBL a usar este grupo de resaltado para el bloque activo
            highlight = { "IblScope" },
        },

        exclude = {
            filetypes = {
                "help",
                "alpha",
                "dashboard",
                "lazy",
                "mason",
                "neo-tree",
                "Trouble",
                "notify",
                "toggleterm",
            },
        },

        whitespace = {
            remove_blankline_trail = true,
        },
    },
    config = function(_, opts)
        -- 1. Inicializamos el plugin pasándole las opciones de arriba
        require("ibl").setup(opts)

        -- 2. GARANTIZAMOS EL COLOR DEL SCOPE
        -- Enlazamos 'IblScope' al grupo 'Function' (el color de las funciones de tu tema).
        -- Esto asegura que la línea se ilumine con un color llamativo y nativo de tu colorscheme.
        vim.api.nvim_set_hl(0, "IblScope", { link = "Function" })
    end,
}
