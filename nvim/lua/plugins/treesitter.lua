return {
    {
        "nvim-treesitter/nvim-treesitter",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            -- 1. Separamos nuestra lista de lenguajes
            local mis_lenguajes = {
                "powershell",
                "lua",
                "python",
                "javascript",
                "typescript",
                "tsx",
                "rust",
                "go",
                "c",
                "cpp",
                "bash",
                "yaml",
                "toml",
                "css",
                "html",
                "json",
                -- Agrega aquí tus nuevos lenguajes (ej: "html", "json")
            }

            -- 2. El setup moderno solo enciende funciones nativas (como el resaltado)
            require("nvim-treesitter").setup({
                highlight = { enable = true },
            })

            -- 3. EL TRUCO: Forzamos la instalación explícita
            -- Esta función revisará la lista y solo descargará silenciosamente los que falten
            require("nvim-treesitter").install(mis_lenguajes)
        end,
    },

    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        config = function()
            -- =================================================================
            -- CONFIGURACIÓN MODERNA DIRECTA
            -- Mapeamos directamente a las funciones del plugin saltándonos el antiguo configs.setup
            -- =================================================================
            local move = require("nvim-treesitter-textobjects.move")

            -- Movimiento: Ir al SIGUIENTE INICIO (Next Start)
            vim.keymap.set({ "n", "x", "o" }, "]f", function()
                move.goto_next_start("@function.outer", "textobjects")
            end, { desc = "Saltar al inicio de la siguiente función" })

            vim.keymap.set({ "n", "x", "o" }, "]c", function()
                move.goto_next_start("@class.outer", "textobjects")
            end, { desc = "Saltar al inicio de la siguiente clase" })

            -- Movimiento: Ir al SIGUIENTE FIN (Next End)
            vim.keymap.set({ "n", "x", "o" }, "]F", function()
                move.goto_next_end("@function.outer", "textobjects")
            end, { desc = "Saltar al final de la siguiente función" })

            vim.keymap.set({ "n", "x", "o" }, "]C", function()
                move.goto_next_end("@class.outer", "textobjects")
            end, { desc = "Saltar al final de la siguiente clase" })

            -- Movimiento: Ir al ANTERIOR INICIO (Previous Start)
            vim.keymap.set({ "n", "x", "o" }, "[f", function()
                move.goto_previous_start("@function.outer", "textobjects")
            end, { desc = "Saltar al inicio de la función anterior" })

            vim.keymap.set({ "n", "x", "o" }, "[c", function()
                move.goto_previous_start("@class.outer", "textobjects")
            end, { desc = "Saltar al inicio de la clase anterior" })

            -- Movimiento: Ir al ANTERIOR FIN (Previous End)
            vim.keymap.set({ "n", "x", "o" }, "[F", function()
                move.goto_previous_end("@function.outer", "textobjects")
            end, { desc = "Saltar al final de la función anterior" })

            vim.keymap.set({ "n", "x", "o" }, "[C", function()
                move.goto_previous_end("@class.outer", "textobjects")
            end, { desc = "Saltar al final de la clase anterior" })
        end,
    },
}
