return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    indent = { char = "▏" }, -- Una línea delgada y elegante
    scope = { enabled = true }, -- Resalta la línea del bloque donde estás parado actualmente
  },
}
