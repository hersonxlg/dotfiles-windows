return {
  "folke/trouble.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = "Trouble",
  keys = {
    { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Ver Errores del Proyecto (Trouble)" },
    { "<leader>xq", "<cmd>Trouble quickfix toggle<cr>", desc = "Lista Quickfix (Trouble)" },
  },
  opts = {},
}
