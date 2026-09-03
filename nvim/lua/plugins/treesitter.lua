return {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        -- Array ordenado con todos los analizadores (parsers) solicitados.
        -- 'markdown' y 'markdown_inline' son esenciales para renderizar las ventanas emergentes (LSP doc / Blink).
        local mis_lenguajes = {
            "arduino",
            "asm",
            "bash",
            "c",
            "cmake",
            "cpp",
            "css",
            "csv",
            "diff",
            "fish",
            "gitcommit",
            "gitignore",
            "gnuplot",
            "go",
            "html",
            "ini",
            "javascript",
            "json",
            "lua",
            "matlab",
            "markdown",
            "markdown_inline",
            "nasm",
            "powershell",
            "python",
            "regex",
            "rust",
            "sql",
            "toml",
            "tsx",
            "typescript",
            "vim",
            "vimdoc",
            "yaml",
        }

        -- Carga de forma segura 'nvim-treesitter.configs'. Si Lazy aún no ha instalado el plugin,
        -- pcall evita que Neovim lance una pantalla roja de error al iniciar.
        local status_ok, configs = pcall(require, "nvim-treesitter.configs")
        if status_ok then
            configs.setup({
                ensure_installed = mis_lenguajes,
                auto_install = true,

                -- IMPORTANTE EN NEOVIM 0.12:
                -- Desactivamos los módulos legados 'highlight' e 'indent' del plugin nvim-treesitter.
                -- Esto previene el crash fatal por métodos obsoletos de Treesitter (como '.range()').
                highlight = {
                    enable = false,
                },
                indent = {
                    enable = false,
                },
            })
        end

        -- DELEGACIÓN AL MOTOR NATIVO Y DESCARGA FILTRADA AL VUELO:
        -- Neovim 0.12 incluye su propio motor Treesitter en C. Usamos este autocomando para
        -- iniciar el pintado nativo (vim.treesitter.start) cada vez que se detecta un tipo de archivo.
        vim.api.nvim_create_autocmd("FileType", {
            desc = "Activa el resaltado nativo de Treesitter e instala el parser si pertenece a la lista",
            group = vim.api.nvim_create_augroup("native-treesitter-highlight", { clear = true }),
            callback = function(args)
                local ft = vim.bo[args.buf].filetype
                local started = pcall(vim.treesitter.start, args.buf)

                -- Si Treesitter no pudo iniciar en este buffer (parser no instalado):
                if not started and ft ~= "" then
                    vim.bo[args.buf].syntax = "on"
                    -- Lanza la instalación automática SOLO si el tipo de archivo está en tu lista 'mis_lenguajes'
                    if vim.tbl_contains(mis_lenguajes, ft) then
                        pcall(vim.cmd, "TSInstall " .. ft)
                    end
                end
            end,
        })
    end,
}
