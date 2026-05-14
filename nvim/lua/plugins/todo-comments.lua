return {
  "folke/todo-comments.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = { "BufReadPost", "BufNewFile" },
  opts = {},
  keys = {
    -- Comando rápido para buscar todos tus TODOs usando tu Telescope actual
    { "<leader>ft", "<cmd>TodoTelescope<cr>", desc = "Buscar TODOs" },
  }
}
