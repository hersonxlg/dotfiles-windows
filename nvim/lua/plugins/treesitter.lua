return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main", -- Obligatorio para las nuevas versiones de Neovim
        lazy = false,    -- El nuevo Treesitter ya no recomienda la carga perezosa (lazy-load)
        build = ":TSUpdate",
        config = function()
            -- El setup moderno es minimalista. Neovim ahora maneja el resaltado de forma nativa.
            require("nvim-treesitter").setup({
                -- Aquí puedes meter tu install_dir o configuraciones básicas si las requieres
            })
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        branch = "main",
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
    }
}
