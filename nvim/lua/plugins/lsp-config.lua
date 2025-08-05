return {
    ---------------------------------
    -- Install "Mason"
    ---------------------------------
    {
        "williamboman/mason.nvim",
        lazy = false,
        config = function()
            require("mason").setup()
        end
    },
    ---------------------------------
    -- Install "mason-lspconfig"
    ---------------------------------
    {
        "williamboman/mason-lspconfig.nvim",
        lazy = false,
        opts = {
            auto_install = true,
        },
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "lua_ls",
                    "pylsp",
                    "clangd",
                    "ts_ls",
                    "powershell_es",
                    "asm_lsp" -- requiere "cargo.exe" (Rust).
                },
            })
        end
    },
    ---------------------------------
    -- Install "mason-lspconfig"
    ---------------------------------
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "folke/neodev.nvim",
        },
        lazy = false,
        config = function()
            local capabilities = require('cmp_nvim_lsp').default_capabilities()
            local lspconfig = require("lspconfig")

            lspconfig.clangd.setup({
                capabilities = capabilities
            })

            -- asm_lsp: remove cmd_cwd (must be a directory, not a file)
            lspconfig.asm_lsp.setup({
                cmd       = { "asm-lsp" },
                filetypes = { "asm", "nasm", "gas", "armasm", "avr" },
                root_dir  = lspconfig.util.root_pattern("asm_lsp.toml", ".git"),
                on_attach = function(_, bufnr)
                    vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = bufnr })
                end,
            })

            lspconfig.pylsp.setup({
                capabilities = capabilities,
                root_dir = lspconfig.util.root_pattern(".git", ".")
            })
            lspconfig.lua_ls.setup({
                capabilities = capabilities
            })
            lspconfig.ts_ls.setup({
                capabilities = capabilities,
                filetypes = {
                    "javascript", "javascript.jsx",
                    "typescript", "typescript.tsx",
                },
                init_options = {
                    hostInfo = "neovim",
                },
            })
            --lspconfig.arduino_language_server.setup({
            --    capabilities = capabilities
            --})
            lspconfig.vimls.setup({
                capabilities = capabilities
            })

            ---------------------------------
            -- Configuración del LSP de PowerShell
            ---------------------------------
            local caps = require("cmp_nvim_lsp").default_capabilities()
            -- POWERHELL EDITOR SERVICES
            lspconfig.powershell_es.setup({
                capabilities = caps,
                filetypes    = { "ps1", "psm1", "psd1" },
                bundle_path  = vim.fn.stdpath("data")
                    .. "\\mason\\packages\\powershell-editor-services",
                shell        = "pwsh", -- PowerShell 7
                settings     = {
                    powershell = {
                        codeFormatting = { Preset = "OTBS" },
                    },
                },
                init_options = {
                    enableProfileLoading = false,
                },
                root_dir     = function(fname)
                    -- fname es la ruta completa al archivo que está abriendo el LSP
                    local path = vim.fs.dirname(fname)
                    local git  = vim.fs.find({ ".git" }, { upward = true, path = path })[1]
                    return git and vim.fs.dirname(git) or path
                end,
            })
            ---------------------------------
            -- Configuración del LSP de Matlab
            ---------------------------------
            lspconfig.matlab_ls.setup({
                cmd = { "matlab-ls" },                                       -- asegúrate de que esté en tu PATH, o usa la ruta completa
                filetypes = { "matlab" },
                root_dir = lspconfig.util.root_pattern(".git", "startup.m"), -- o lo que defina tu proyecto
                capabilities = require("cmp_nvim_lsp").default_capabilities(),
            })
            ---------------------------------
            vim.keymap.set('n', 'K', vim.lsp.buf.hover, {})
            vim.keymap.set('n', 'gd', vim.lsp.buf.definition, {})
            vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, {})
        end
    },
}
