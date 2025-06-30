------------------------------------------------------------
-- Auto comandos:
------------------------------------------------------------

-- autocmd-ps1.lua
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.ps1",
  callback = function()
    vim.bo.filetype = "ps1"
  end,
})
