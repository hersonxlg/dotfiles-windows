return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    -- Esto asegura que el plugin se descargue antes de intentar ejecutar nada
    lazy = false, 
    config = function()
        -- Usamos pcall (protected call) para evitar el pantallazo rojo
        local status, configs = pcall(require, "nvim-treesitter.configs")
        if not status then
            -- Si falla, imprimimos un mensaje discreto y salimos de la función
            print("Treesitter aún no está listo. Ejecuta :Lazy sync")
            return
        end

        configs.setup({
            -- Añade aquí tus lenguajes favoritos
            ensure_installed = { "lua", "vim", "vimdoc", "query", "python", "asm", "c" },
            highlight = { enable = true },
            indent = { enable = true },
        })
    end
}
