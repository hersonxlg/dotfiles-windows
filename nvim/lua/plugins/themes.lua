return {
    -- 1. Catppuccin
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = true, -- 'true' para que esté disponible sin activarse de entrada
        opts = {
            flavour = "mocha",
        },
    },

    -- 2. Tokyo Night (TEMA ACTIVO)
    {
        "folke/tokyonight.nvim",
        lazy = false, -- 'false' para que cargue al iniciar Neovim
        priority = 1000, -- Prioridad alta para evitar destellos blancos/negros al arrancar
        config = function()
            vim.cmd.colorscheme("tokyonight-night")
        end,
    },

    -- 3. Kanagawa
    {
        "rebelot/kanagawa.nvim",
        lazy = true,
    },

    -- 4. Gruvbox
    {
        "ellisonleao/gruvbox.nvim",
        lazy = true,
    },
    -- 5. Rose Pine (Elegante, tonos pastel suaves y oscuros)
    {
        "rose-pine/neovim",
        name = "rose-pine",
        lazy = true,
    },

    -- 6. Nightfox (Incluye variantes: nightfox, nordfox, dayfox, duskfox, terafox)
    {
        "EdenEast/nightfox.nvim",
        lazy = true,
    },

    -- 7. Dracula (Clásico tema oscuro con colores morados/neón de alto contraste)
    {
        "Mofiqul/dracula.nvim",
        lazy = true,
    },

    -- 8. Everforest (Tonos verdosos orgánicos, relajantes para la vista)
    {
        "neanias/everforest-nvim",
        lazy = true,
    },

    -- 9. One Dark Pro (El diseño icónico y equilibrado estilo Atom / VS Code)
    {
        "olimorris/onedarkpro.nvim",
        lazy = true,
    },

    -- 10. Cyberdream (Estilo Cyberpunk futurista con colores muy vivos)
    {
        "scottmckendry/cyberdream.nvim",
        lazy = true,
    },

    -- 11. Nordic (Inspirado en la paleta Nord, pero con azules/grises más profundos)
    {
        "AlexvZyl/nordic.nvim",
        lazy = true,
    },

    -- 12. Monokai Pro (Paleta profesional clásica con variaciones como Ristretto y Octagon)
    {
        "loctvl842/monokai-pro.nvim",
        lazy = true,
    },
}
