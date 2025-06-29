-- plugins.lua
return {
  -- administradores
  { "williamboman/mason.nvim",          opts = {} },
  { "williamboman/mason-lspconfig.nvim", opts = {
      ensure_installed = { "powershell_es" },
    },
    dependencies = { "mason.nvim" },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "mason.nvim", "mason-lspconfig.nvim" },
    config = function()
      local lspconfig = require("lspconfig")

      -- Configuración específica para PowerShell LSP
      lspconfig.powershell_es.setup {
        filetypes = { "ps1", "psm1", "psd1" },
        bundle_path = vim.fn.stdpath("data") .. "/mason/packages/powershell-es",
        shell = "pwsh",
        settings = {
          powershell = {
            codeFormatting = { Preset = "OTBS" },
          },
        },
        init_options = {
          enableProfileLoading = false,  -- evita el fallo de conexión :contentReference[oaicite:1]{index=1}
        },
      }

      -- Mapas útiles para LSP
      vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, {})
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {})
    end,
  },
}
