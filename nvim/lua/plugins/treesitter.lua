return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    -- CAMBIO: Eliminamos 'lazy = false' y usamos eventos de lectura/creación de archivos.
    -- Esto optimiza el arranque de Neovim y asegura que las rutas internas estén listas.
    event = { "BufReadPost", "BufNewFile" }, 
    config = function()
        -- Usamos pcall (protected call) para evitar el pantallazo rojo
        local status, configs = pcall(require, "nvim-treesitter.configs")
        if not status then
            -- Dejamos el aviso por si acaso, pero con los eventos de arriba ya nunca se ejecutará
            print("Treesitter aún no está listo. Ejecuta :Lazy sync")
            return
        end

        configs.setup({
            -- Tus lenguajes favoritos
            ensure_installed = { "lua", "vim", "vimdoc", "query", "python", "asm", "c" },
            highlight = { enable = true },
            indent = { enable = true },
        })
    end
}
