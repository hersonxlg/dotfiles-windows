return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  config = function()
    require("copilot").setup({
      suggestion = {
        enabled = true,
        auto_trigger = true, -- Muestra sugerencias gris automáticamente
        keymap = {
          -- ¡IMPORTANTE! Usamos Control+J para aceptar para no pelear con el Tab del LSP
          accept = "<C-j>", 
          accept_word = false,
          accept_line = false,
          next = "<M-]>", -- Alt + ] para ver la siguiente sugerencia de IA
          prev = "<M-[>", 
          dismiss = "<C-]>",
        },
      },
      panel = { enabled = false },
    })
  end,
}
