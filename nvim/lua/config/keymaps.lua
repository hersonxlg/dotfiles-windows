-----------------------------------------------------
-- Atajos de teclado generales
-----------------------------------------------------
--vim.keymap.set("n", "<leader>x", ":bd<CR>", { noremap = true })
--vim.keymap.set("n", "<leader>s", ":so %<CR>", { noremap = true })
--vim.keymap.set("n", "<leader>ev", ":vsplit $MYVIMRC<CR>", { noremap = true })
--vim.keymap.set("n", "<leader>sv", ":w<CR>:so %<CR>:q<CR>", { noremap = true })

vim.opt.cursorline = true
vim.opt.winborder = "rounded"
vim.opt.breakindent = true

-- Ejecutar archivos LUA con Neovim.
vim.keymap.set("n", "<leader>rl", ":source %<CR>", { desc = "Ejecutar archivo Lua actual" })

--
vim.keymap.set("n", "zv", "<c-v>", { noremap = true })
vim.keymap.set("n", "<leader>;", "q:", { noremap = true })
--
vim.keymap.set("n", "<M-j>", "<c-w><c-j>", { noremap = true })
vim.keymap.set("n", "<M-k>", "<c-w><c-k>", { noremap = true })
vim.keymap.set("n", "<M-h>", "<c-w><c-h>", { noremap = true })
vim.keymap.set("n", "<M-l>", "<c-w><c-l>", { noremap = true })

-- Navegación de pestañas (tabs)
vim.keymap.set("n", "<A-p>", "<cmd>tabprevious<CR>", { desc = "Ir a la pestaña anterior" })
vim.keymap.set("n", "<A-n>", "<cmd>tabnext<CR>", { desc = "Ir a la pestaña siguiente" })

-- Reemplaza el texto seleccionado sin perder lo que copiaste
vim.keymap.set("x", "p", [["_dP]], {
    desc = "Pegar sobre selección sin perder el texto copiado",
})

-- Elimina texto sin guardarlo en ningún registro
-- Ejemplos:
--   <leader>dw  -> elimina una palabra sin copiarla
--   <leader>dd  -> elimina una línea sin copiarla
--   <leader>diw -> elimina una palabra interna sin copiarla
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]], {
    desc = "Eliminar sin copiar",
})

-- Salir del modo insertar usando "kj"
vim.keymap.set("i", "kj", "<Esc>", {
    silent = true,
    desc = "Salir del modo insertar",
})

-- Guardar el archivo actual
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", {
    silent = false,
    desc = "Guardar archivo",
})

-- Cerrar la ventana actual
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", {
    silent = true,
    desc = "Cerrar ventana",
})

-- Limpiar el resaltado de las búsquedas
vim.keymap.set("n", "<Esc>", ":nohl<CR>", {
    desc = "Limpiar resaltado de búsqueda",
    silent = true,
})

-- Mover líneas seleccionadas hacia abajo en modo visual
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", {
    desc = "Mover líneas seleccionadas hacia abajo",
})

-- Mover líneas seleccionadas hacia arriba en modo visual
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", {
    desc = "Mover líneas seleccionadas hacia arriba",
})

-- Reducir indentación y mantener la selección visual
vim.keymap.set("v", "<", "<gv", {
    desc = "Reducir indentación y mantener selección",
})

-- Aumentar indentación y mantener la selección visual
vim.keymap.set("v", ">", ">gv", {
    desc = "Aumentar indentación y mantener selección",
})

-- Unir líneas sin mover el cursor de posición
vim.keymap.set("n", "J", "mzJ`z", {
    desc = "Unir líneas sin mover el cursor",
})

-- Bajar media página manteniendo el cursor centrado
vim.keymap.set("n", "<C-d>", "<C-d>zz", {
    desc = "Bajar media página centrando el cursor",
})

-- Subir media página manteniendo el cursor centrado
vim.keymap.set("n", "<C-u>", "<C-u>zz", {
    desc = "Subir media página centrando el cursor",
})

-- Ir al siguiente resultado de búsqueda centrando el cursor
vim.keymap.set("n", "n", "nzzzv", {
    desc = "Siguiente resultado de búsqueda centrado",
})

-- Ir al resultado anterior de búsqueda centrando el cursor
vim.keymap.set("n", "N", "Nzzzv", {
    desc = "Resultado anterior de búsqueda centrado",
})

-- Reemplazar globalmente la palabra bajo el cursor
-- Deja el cursor listo para escribir el reemplazo
vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], {
    desc = "Reemplazar palabra bajo el cursor globalmente",
})

-- Hacer ejecutable el archivo actual (Linux/macOS)
vim.keymap.set("n", "<leader>X", "<cmd>!chmod +x %<CR>", {
    silent = true,
    desc = "Hacer ejecutable el archivo actual",
})

-- Reiniciar la configuración de Neovim
vim.keymap.set("n", "<leader>re", "<cmd>restart<cr>", {
    desc = "Reiniciar configuración de Neovim",
})

-- Abrir/cerrar el árbol de deshacer (Undotree)
vim.keymap.set("n", "<leader>u", function()
    vim.cmd.packadd("nvim.undotree")
    require("undotree").open()
end, {
    desc = "Alternar árbol de deshacer",
})

-- ==========================================================
-- Helper para contar buffers visibles/activos
-- ==========================================================

-- Helper: Contar buffers activos/listados
local function get_listed_buffers()
    local listed = {}
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted then
            table.insert(listed, b)
        end
    end
    return listed
end

-- Helper: Contar paneles (ventanas normales) abiertos en la pestaña actual
local function get_normal_windows()
    local wins = {}
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local cfg = vim.api.nvim_win_get_config(w)
        if cfg.relative == "" then -- Filtra ventanas flotantes
            table.insert(wins, w)
        end
    end
    return wins
end

-- 1. Salir de TODO Neovim (Cierre global)
local function smart_quit()
    local modified = {}
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].modified then
            local name = vim.api.nvim_buf_get_name(b)
            table.insert(modified, name == "" and "[Sin nombre]" or vim.fn.fnamemodify(name, ":~:."))
        end
    end

    if #modified == 0 then
        vim.cmd("qa")
        return
    end

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

-- 2. Cierre contextual (Imagen -> Panel -> Buffer -> Neovim)
local function smart_close()
    -- =========================================================================
    -- NUEVA LÓGICA DE PRIORIDAD 1: Cerrar la imagen de Obsidian si está abierta
    -- =========================================================================
    -- 1. Obtenemos todas las ventanas de la pestaña actual
    local current_wins = vim.api.nvim_tabpage_list_wins(0)
    local img_closed = false

    -- 2. Iteramos buscando alguna ventana que esté en el extremo derecho (botright vsplit)
    -- y que su buffer NO sea listado (que es como configuraste la imagen en tu init.lua)
    for _, w in ipairs(current_wins) do
        local b = vim.api.nvim_win_get_buf(w)
        local buf_name = vim.api.nvim_buf_get_name(b)

        -- Si encontramos un buffer que está dentro de tu carpeta de attachments...
        if string.find(buf_name, "syncthing/obsidian/attachments") then
            -- Cerramos la ventana de la imagen
            pcall(vim.api.nvim_win_close, w, true)

            -- Limpiamos la caché gráfica (Kitty protocol) y repintamos
            pcall(vim.api.nvim_chan_send, vim.v.stderr, "\27_Ga=d,d=a;\27\\")
            vim.cmd("redraw!")

            -- Para evitar que el archivo de obsidian intente cerrarla de nuevo si tenías 'img_win_id'
            -- lanzamos un pequeño autocomando que el init.lua puede escuchar (opcional pero limpio)
            vim.api.nvim_exec_autocmds("User", { pattern = "ObsidianImageClosed" })

            img_closed = true
            break -- Ya encontramos y cerramos la imagen, salimos del bucle
        end
    end

    -- 3. Si cerramos una imagen, DETENEMOS la ejecución aquí.
    -- No queremos cerrar tu código ni tus búferes.
    if img_closed then
        return
    end
    -- =========================================================================

    local normal_wins = get_normal_windows()

    -- NIVEL 1: Si hay múltiples paneles (splits) abiertos, cierra solo el panel enfocado
    if #normal_wins > 1 then
        vim.cmd("close")
        return
    end

    local listed_bufs = get_listed_buffers()

    -- NIVEL 3: Si es el último panel Y el último buffer, redirige a salir de Neovim
    if #listed_bufs <= 1 then
        smart_quit()
        return
    end

    -- NIVEL 2: Si hay 1 solo panel pero múltiples buffers en segundo plano, cierra el buffer actual
    local current_buf = vim.api.nvim_get_current_buf()

    if not vim.bo[current_buf].modified then
        vim.cmd("bdelete")
        return
    end

    local buf_name = vim.api.nvim_buf_get_name(current_buf)
    local display_name = buf_name == "" and "[Sin nombre]" or vim.fn.fnamemodify(buf_name, ":~:.")

    local options = {
        "1. Guardar cambios y cerrar buffer",
        "2. Descartar cambios y cerrar buffer",
        "3. Cancelar",
    }

    vim.ui.select(options, { prompt = "Cambios sin guardar en " .. display_name .. ":" }, function(choice)
        if choice == options[1] then
            vim.cmd("write | bdelete")
        elseif choice == options[2] then
            vim.cmd("bdelete!")
        end
    end)
end

-- Mapeos
vim.keymap.set("n", "q", smart_close, { desc = "Cerrar panel, buffer o Neovim de forma inteligente" })
vim.keymap.set("n", "<S-q>", smart_quit, { desc = "Salir de todo Neovim" })
