-- lazydev.nvim: Configuración para mejorar el desarrollo de plugins y scripts en Neovim.
-- Este plugin soluciona el error "Undefined global `vim`" configurando el LSP de Lua automáticamente.

return {
  {
    "folke/lazydev.nvim",
    -- ft = "lua" asegura que el plugin solo se active cuando abras archivos de Lua.
    ft = "lua", 
    opts = {
      library = {
        -- library: Indica al servidor de lenguaje dónde encontrar las definiciones 
        -- de las funciones de Neovim y otros entornos relacionados.
        
        -- luvit-meta es opcional, pero ayuda si usas la API de bajo nivel de Neovim (vim.uv)
        { path = "luvit-meta/library", words = { "vim%.uv" } },
      },
      -- integration: Permite que otros plugins (como cmp) sugieran autocompletado 
      -- para las funciones de la API de Neovim (como vim.api.* o vim.lsp.*)
      integrations = {
        lspconfig = true,
        cmp = true,
      },
    },
  },
}
