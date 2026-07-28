return {
    {
        "nvim-treesitter/nvim-treesitter",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            -- 1. Definimos nuestra lista de lenguajes
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
            }

            -- 2. El setup moderno utiliza "nvim-treesitter.configs"
            require("nvim-treesitter.configs").setup({
                -- Le pasamos la lista de lenguajes para que Treesitter los instale automáticamente
                ensure_installed = mis_lenguajes,
                
                -- Instala lenguajes de forma asíncrona para no bloquear el inicio de Neovim
                sync_install = false,
                
                -- Instala automáticamente lenguajes cuando entras a un archivo de un lenguaje no instalado
                auto_install = true,

                -- Habilita el resaltado de sintaxis
                highlight = { enable = true },
            })
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
