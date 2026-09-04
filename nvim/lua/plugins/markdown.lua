-- Ruta al vault normalizada para Windows y Linux
local vault_path = vim.fs.normalize(vim.fn.expand("~/syncthing/obsidian"))

return {
    -- 1. OBSIDIAN.NVIM
    {
        "epwalsh/obsidian.nvim",
        version = "*",
        lazy = true,
        ft = "markdown",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-telescope/telescope.nvim",
            "nvim-treesitter/nvim-treesitter",
        },
        opts = {
            workspaces = {
                {
                    name = "personal",
                    path = vault_path,
                },
            },
            completion = {
                nvim_cmp = false,
                blink_cmp = true,
                min_chars = 2,
            },
            mappings = {
                ["gf"] = {
                    action = function()
                        return require("obsidian").util.gf_passthrough()
                    end,
                    opts = { noremap = false, expr = true, buffer = true },
                },
                ["<leader>ch"] = {
                    action = function()
                        return require("obsidian").util.toggle_checkbox()
                    end,
                    opts = { buffer = true },
                },
                ["<leader>onn"] = {
                    action = function()
                        return require("obsidian").commands.new_note()
                    end,
                    opts = { buffer = true },
                },
            },
            attachments = {
                img_folder = "attachments",
            },
            ui = { enable = false }, -- Desactivado para evitar conflictos con render-markdown
        },
    },

    -- 2. RENDER-MARKDOWN (Estilos visuales e iconos avanzados)
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown", "obsidian" },
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
        opts = {
            heading = {
                enabled = true,
                sign = true,
                icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
            },
            checkbox = {
                enabled = true,
                unchecked = { icon = "󰄱 " },
                checked = { icon = " " },
                custom = {
                    todo = { raw = "[-]", rendered = "󰅖 ", highlight = "RenderMarkdownWarn" },
                    important = { raw = "[!]", rendered = "󰀪 ", highlight = "RenderMarkdownError" },
                    progress = { raw = "[/]", rendered = "󱎖 ", highlight = "RenderMarkdownInfo" },
                },
            },
            link = {
                enabled = true,
                image = "󰋩 ",
                email = "󰇮 ",
                hyperlink = "󰌹 ",
                wiki = { icon = "󱞁 ", highlight = "RenderMarkdownWikiLink" },
            },
            callout = {
                note = { raw = "[!NOTE]", rendered = "󰋽 Nota", highlight = "RenderMarkdownInfo" },
                tip = { raw = "[!TIP]", rendered = "󰌶 Consejo", highlight = "RenderMarkdownSuccess" },
                important = { raw = "[!IMPORTANT]", rendered = "󰅾 Importante", highlight = "RenderMarkdownHint" },
                warning = { raw = "[!WARNING]", rendered = "󰀪 Advertencia", highlight = "RenderMarkdownWarn" },
                caution = { raw = "[!CAUTION]", rendered = "󰳦 Peligro", highlight = "RenderMarkdownError" },
                todo = { raw = "[!TODO]", rendered = "󰗡 Pendiente", highlight = "RenderMarkdownInfo" },
                bug = { raw = "[!BUG]", rendered = "󰨰 Error/Bug", highlight = "RenderMarkdownError" },
                example = { raw = "[!EXAMPLE]", rendered = "󰉹 Ejemplo", highlight = "RenderMarkdownHint" },
                quote = { raw = "[!QUOTE]", rendered = "󱆧 Cita", highlight = "RenderMarkdownQuote" },
            },
            bullet = {
                icons = { "●", "○", "◆", "◇" },
            },
        },
    },
}
