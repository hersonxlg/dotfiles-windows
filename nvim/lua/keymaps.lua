vim.g.mapleader = " "
vim.g.maplocalleader = " "


-----------------------------------------------------
-- Atajos de teclado generales
-----------------------------------------------------
--vim.keymap.set("n", "<leader>x", ":bd<CR>", { noremap = true })
--vim.keymap.set("n", "<leader>s", ":so %<CR>", { noremap = true })
--vim.keymap.set("n", "<leader>ev", ":vsplit $MYVIMRC<CR>", { noremap = true })
--vim.keymap.set("n", "<leader>sv", ":w<CR>:so %<CR>:q<CR>", { noremap = true })
--
vim.keymap.set("n", "zv", "<c-v>",{noremap = true})
vim.keymap.set("n", "<leader>;", "q:",{noremap = true})
--
vim.keymap.set("n", "<c-j>", "<c-w><c-j>",{noremap = true})
vim.keymap.set("n", "<c-k>", "<c-w><c-k>",{noremap = true})
vim.keymap.set("n", "<c-h>", "<c-w><c-h>",{noremap = true})
vim.keymap.set("n", "<c-l>", "<c-w><c-l>",{noremap = true})

-- Reemplaza el texto seleccionado sin perder lo que copiaste
vim.keymap.set("x", "p", [["_dP]], {
    desc = "Pegar sobre selección sin perder el texto copiado"
})

-- Elimina texto sin guardarlo en ningún registro
-- Ejemplos:
--   <leader>dw  -> elimina una palabra sin copiarla
--   <leader>dd  -> elimina una línea sin copiarla
--   <leader>diw -> elimina una palabra interna sin copiarla
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]], {
    desc = "Eliminar sin copiar"
})

-- Salir del modo insertar usando "kj"
vim.keymap.set("i", "kj", "<Esc>", {
    silent = true,
    desc = "Salir del modo insertar"
})

-- Guardar el archivo actual
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", {
    silent = false,
    desc = "Guardar archivo"
})

-- Cerrar la ventana actual
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", {
    silent = true,
    desc = "Cerrar ventana"
})

-- Limpiar el resaltado de las búsquedas
vim.keymap.set("n", "<Esc>", ":nohl<CR>", {
    desc = "Limpiar resaltado de búsqueda",
    silent = true
})

-- Mover líneas seleccionadas hacia abajo en modo visual
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", {
    desc = "Mover líneas seleccionadas hacia abajo"
})

-- Mover líneas seleccionadas hacia arriba en modo visual
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", {
    desc = "Mover líneas seleccionadas hacia arriba"
})

-- Reducir indentación y mantener la selección visual
vim.keymap.set("v", "<", "<gv", {
    desc = "Reducir indentación y mantener selección"
})

-- Aumentar indentación y mantener la selección visual
vim.keymap.set("v", ">", ">gv", {
    desc = "Aumentar indentación y mantener selección"
})

-- Unir líneas sin mover el cursor de posición
vim.keymap.set("n", "J", "mzJ`z", {
    desc = "Unir líneas sin mover el cursor"
})

-- Bajar media página manteniendo el cursor centrado
vim.keymap.set("n", "<C-d>", "<C-d>zz", {
    desc = "Bajar media página centrando el cursor"
})

-- Subir media página manteniendo el cursor centrado
vim.keymap.set("n", "<C-u>", "<C-u>zz", {
    desc = "Subir media página centrando el cursor"
})

-- Ir al siguiente resultado de búsqueda centrando el cursor
vim.keymap.set("n", "n", "nzzzv", {
    desc = "Siguiente resultado de búsqueda centrado"
})

-- Ir al resultado anterior de búsqueda centrando el cursor
vim.keymap.set("n", "N", "Nzzzv", {
    desc = "Resultado anterior de búsqueda centrado"
})

-- Reemplazar globalmente la palabra bajo el cursor
-- Deja el cursor listo para escribir el reemplazo
vim.keymap.set("n", "<leader>s",
    [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
    {
        desc = "Reemplazar palabra bajo el cursor globalmente"
    }
)

-- Hacer ejecutable el archivo actual (Linux/macOS)
vim.keymap.set("n", "<leader>X", "<cmd>!chmod +x %<CR>", {
    silent = true,
    desc = "Hacer ejecutable el archivo actual"
})

-- Reiniciar la configuración de Neovim
vim.keymap.set("n", "<leader>re", "<cmd>restart<cr>", {
    desc = "Reiniciar configuración de Neovim"
})

-- Abrir/cerrar el árbol de deshacer (Undotree)
vim.keymap.set("n", "<leader>u", function()
    vim.cmd.packadd("nvim.undotree")
    require("undotree").open()
end, {
    desc = "Alternar árbol de deshacer"
})


----------------------------------------------
-- Cerrar la ventana actual
----------------------------------------------
local function smart_quit()
  local modified = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].modified then
      local name = vim.api.nvim_buf_get_name(b)
      table.insert(modified, name == "" and "[Sin nombre]" or vim.fn.fnamemodify(name, ":~:."))
    end
  end

  -- Si NO hay cambios, sale inmediatamente sin preguntar nada
  if #modified == 0 then
    vim.cmd("qa")
    return
  end

  -- Si HAY cambios, consulta qué hacer
  local options = {
    "1. Guardar todo y salir",
    "2. Descartar cambios y salir",
    "3. Cancelar",
  }
  local prompt = "Cambios pendientes en: " .. table.concat(modified, ", ")

  vim.ui.select(options, { prompt = prompt }, function(choice)
    if choice == options[1] then
      vim.cmd("wall | qa")
    elseif choice == options[2] then
      vim.cmd("qa!")
    end
  end)
end

vim.keymap.set('n', 'q', smart_quit, { desc = 'Salir directo o consultar si hay cambios' })
