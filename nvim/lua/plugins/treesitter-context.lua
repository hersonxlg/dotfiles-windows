return {
    "nvim-treesitter/nvim-treesitter-context",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
        require("treesitter-context").setup({
            enable = true,            -- Activa el plugin
            max_lines = 3,            -- Límite de líneas que se quedarán pegadas arriba (para no tapar toda tu pantalla)
            trim_scope = 'outer',     -- Si el contexto es más grande que max_lines, recorta desde afuera hacia adentro
            mode = 'cursor',          -- Calcula el contexto basado en dónde está tu cursor
        })
    end,
}
