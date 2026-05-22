return {
    {
        "kevinhwang91/nvim-ufo",
        dependencies = { "kevinhwang91/promise-async" },
        event = "BufReadPost", -- Carga diferida inteligente al leer un archivo
        init = function()
            -- Configuración global requerida por UFO en Neovim 0.12+
            vim.o.foldcolumn = "1" -- Columna delgada a la izquierda para ver pliegues
            vim.o.foldlevel = 99   -- Iniciar con niveles altos (manejado por UFO)
            vim.o.foldlevelstart = 99
            vim.o.foldenable = true
        end,
        -- Dejamos 'opts' vacío. Al quitar 'provider_selector', UFO activará de forma
        -- segura su comportamiento por defecto: LSP -> Treesitter -> Indent
        opts = {}, 
        config = function(_, opts)
            local ufo = require("ufo")
            ufo.setup(opts)

            -- Atajos de teclado dedicados para los pliegues asíncronos
            vim.keymap.set("n", "zR", ufo.openAllFolds, { desc = "UFO: Abrir todos los pliegues" })
            vim.keymap.set("n", "zM", ufo.closeAllFolds, { desc = "UFO: Cerrar todos los pliegues" })
            --vim.keymap.set("n", "zr", ufo.openFoldsExceptKinds, { desc = "UFO: Abrir pliegues por nivel" })
            --vim.keymap.set("n", "zm", ufo.closeFoldsWith, { desc = "UFO: Cerrar pliegues por nivel" })
            
            -- Atajo maestro zK: Vista previa flotante si está plegado, si no, Hover clásico del LSP
            vim.keymap.set("n", "zK", function()
                local winid = ufo.peekFoldedLinesUnderCursor()
                if not winid then
                    vim.lsp.buf.hover()
                end
            end, { desc = "UFO: Previsualizar código plegado o Hover LSP" })
        end,
    },
}
