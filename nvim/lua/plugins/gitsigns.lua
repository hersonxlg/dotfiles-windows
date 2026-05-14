return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    on_attach = function(bufnr)
      local gitsigns = require('gitsigns')
      -- Atajo rápido para ver qué cambió en la línea actual
      vim.keymap.set('n', '<leader>gp', gitsigns.preview_hunk, { buffer = bufnr, desc = 'Ver cambio de Git' })
    end
  },
}
