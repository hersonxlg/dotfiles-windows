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
                    "powershell_es"
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
            lspconfig.pylsp.setup({
                capabilities = capabilities
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
            lspconfig.powershell_es.setup({
              capabilities = capabilities,
              filetypes = {
                    "ps1", 
                    "psm1", 
                    "psd1" 
                },
              bundle_path = vim.fn.stdpath("data") .. "/mason/packages/powershell-editor-services",
              shell = "pwsh",
              settings = {
                powershell = {
                  codeFormatting = {
                    Preset = "OTBS",
                  },
                },
              },
              init_options = {
                enableProfileLoading = false,
              },
            })
            ---------------------------------
            -- Configuración del LSP de Matlab
            ---------------------------------
            lspconfig.matlab_ls.setup({
              cmd = { "matlab-ls" },  -- asegúrate de que esté en tu PATH, o usa la ruta completa
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
