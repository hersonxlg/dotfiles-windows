return {
  "metakirby5/codi.vim",
  cmd = "Codi",
  config = function()
    -- Opciones globales de Codi
    vim.g["codi#interpreters"] = {
      javascript = { bin = "node" },
      python = { bin = "python" },
      lua = { bin = "lua" },
    }
    -- Abrir Codi en un split vertical por defecto
    vim.g["codi#rightsplit"] = 1
    vim.g["codi#autoclose"] = 0
  end,
}
