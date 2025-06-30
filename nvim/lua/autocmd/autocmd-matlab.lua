--------------------------------------------------------------------
-- Asocia la extensión .m con el tipo de archivo matlab
--------------------------------------------------------------------
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.m",
  callback = function()
    vim.bo.filetype = "matlab"
  end,
})
