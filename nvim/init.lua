-- 1. Primero cargamos las variables globales (Leader)
require("config.globals")

------------------------------------------------------------
-- 2. Instalar LAZY:
------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop
if not uv.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end

vim.opt.rtp:prepend(lazypath)

------------------------------------------------------------
-- 3. Configuraciones Base de NeoVim:
------------------------------------------------------------
require("config.options")
require("config.keymaps")
require("config.autocmd")

------------------------------------------------------------
-- 4. PLUGINS FOR LAZY:
-----------------------------------------------------------
require("lazy").setup("plugins", {
    git = {
        timeout = 300,
    },
    ui = {
        icons = {
            cmd = "⌘",
            config = "🛠",
            event = "📅",
            ft = "📂",
            init = "⚙",
            keys = "🗝",
            runtime = "💻",
            require = "🌙",
            source = "📄",
            start = "🚀",
            task = "📌",
            loaded = "✓",
            not_loaded = "✗",
            lazy = "➜",
            plugin = "📦",
        },
    },
})

------------------------------------------------------------
-- 5. Autocomando Multiplataforma (Linux / Windows)
------------------------------------------------------------
function RequireAll(relative_path)
    local config_path = vim.fn.stdpath("config") .. "/lua/"
    local target_dir = config_path .. relative_path

    local paths = vim.split(vim.fn.globpath(target_dir, "*.lua"), "\n", { trimempty = true })

    for _, p in ipairs(paths) do
        local normalized_p = p:gsub("\\", "/")
        local normalized_config = config_path:gsub("\\", "/")
        local module_name = normalized_p:gsub(normalized_config, ""):gsub("%.lua$", ""):gsub("/", ".")
        require(module_name)
    end
end

------------------------------------------------------------
-- 6. Ejecutar Eventos Específicos
------------------------------------------------------------
RequireAll("autocmd")

------------------------------------------------------------
-- 7. Mis autocomandos
------------------------------------------------------------
--local obsidian_img_group = vim.api.nvim_create_augroup("ObsidianImageDetector", { clear = true })
--vim.opt.updatetime = 300
--
--local last_opened_line = nil
--
--vim.api.nvim_create_autocmd("CursorHold", {
--    group = obsidian_img_group,
--    pattern = "*.md",
--    callback = function()
--        local current_line_num = vim.api.nvim_win_get_cursor(0)[1]
--        local line = vim.api.nvim_get_current_line()
--
--        local wiki_match = line:match("%!%[%[(.-)%]%]")
--        local md_match = line:match("%!%[.-%]%((.-)%)")
--
--        if wiki_match or md_match then
--            if last_opened_line == current_line_num then
--                return
--            end
--
--            last_opened_line = current_line_num
--
--            -- Recorre todas las ventanas abiertas en Neovim
--            for _, win in ipairs(vim.api.nvim_list_wins()) do
--                -- Obtiene el buffer asociado a cada ventana
--                local buf = vim.api.nvim_win_get_buf(win)
--
--                -- Si el tipo de archivo del buffer es el de la imagen de snacks...
--                if vim.bo[buf].filetype == "snacks_image" then
--                    -- ...cierra la ventana forzosamente de manera segura
--                    pcall(vim.api.nvim_win_close, win, true)
--                end
--            end
--
--            -- 1. Inicia la animación suave de scroll hacia arriba
--            vim.cmd("normal! zt")
--
--            -- 2. Espera 150ms a que termine la animación antes de dibujar
--            vim.defer_fn(function()
--                -- Verificación de seguridad
--                if vim.api.nvim_win_get_cursor(0)[1] ~= current_line_num then
--                    return
--                end
--
--                -- 3. ¡NUEVO!: Fuerza a Neovim a repintar la interfaz antes de inyectar la imagen
--                vim.cmd("redraw")
--
--                -- 4. Renderiza la miniatura
--                Snacks.image.hover({
--                    -- Tamaño de la imagen: Se le restan 2 celdas para respetar el borde
--                    width = 33,
--                    height = 8,
--                    win = {
--                        --relative = "editor",
--                        relative = "split",
--                        position = "center",
--                        border = "none",
--                        -- Tamaño total de la ventana: Sigue siendo 35x10
--                        width = 35,
--                        height = 10,
--                    },
--                })
--            end, 150)
--        end
--    end,
--})
--
--vim.api.nvim_create_autocmd("CursorMoved", {
--    group = obsidian_img_group,
--    pattern = "*.md",
--    callback = function()
--        local current_line_num = vim.api.nvim_win_get_cursor(0)[1]
--        if last_opened_line and last_opened_line ~= current_line_num then
--            last_opened_line = nil
--        end
--    end,
--})
------------------------------------------------------------
-- 7. Autocomandos: Vista previa de imágenes en Obsidian
------------------------------------------------------------
local obsidian_img_group = vim.api.nvim_create_augroup("ObsidianImageDetector", { clear = true })

-- [Ajustes Globales de Rendimiento]
-- updatetime: Define milisegundos de inactividad para disparar CursorHold.
-- Nota: Afecta a otros plugins (LSP, Gitsigns). Subir a 150-200 si hay lag.
vim.opt.updatetime = 50
local waitUntilScrollEnd = 20

-- [Variables de Estado]
local last_opened_line = nil -- Evita reabrir la imagen si seguimos en la misma línea
local img_win_id = nil -- Almacena el ID del split vertical activo

------------------------------------------------------------
-- EVENTO 1: Detectar y abrir la imagen al detener el cursor
------------------------------------------------------------
vim.api.nvim_create_autocmd("CursorHold", {
    group = obsidian_img_group,
    pattern = "*.md",
    callback = function()
        local current_line_num = vim.api.nvim_win_get_cursor(0)[1]
        local line = vim.api.nvim_get_current_line()

        -- Extraer nombre de la imagen (Soporta WikiLinks y Markdown estándar)
        local wiki_match = line:match("%!%[%[(.-)%]%]")
        local md_match = line:match("%!%[.-%]%((.-)%)")
        local img_name = wiki_match or md_match

        if img_name then
            -- Prevenir bucles: No hacer nada si ya abrimos la imagen de esta línea
            if last_opened_line == current_line_num then
                return
            end
            last_opened_line = current_line_num

            -- Normalizar la ruta de la imagen
            img_name = img_name:gsub("%%20", " ")
            local attachments_dir = vim.fn.expand("~/syncthing/obsidian/attachments/")
            local full_path = vim.fs.normalize(attachments_dir .. img_name)

            if vim.fn.filereadable(full_path) == 1 then
                -- Iniciar animación para centrar la vista en el enlace
                vim.cmd("normal! zt")

                -- Esperar a que la pantalla se estabilice antes de dibujar
                vim.defer_fn(function()
                    -- Abortar si el usuario se movió durante la espera
                    if vim.api.nvim_win_get_cursor(0)[1] ~= current_line_num then
                        return
                    end

                    -- Cerrar imagen anterior si quedó huérfana
                    if img_win_id and vim.api.nvim_win_is_valid(img_win_id) then
                        pcall(vim.api.nvim_win_close, img_win_id, true)
                    end

                    local current_win = vim.api.nvim_get_current_win()

                    -- Crear el split vertical en el extremo derecho (40 columnas)
                    vim.cmd("botright 40vsplit " .. vim.fn.fnameescape(full_path))
                    img_win_id = vim.api.nvim_get_current_win()

                    -- Limpiar UI del panel de la imagen
                    vim.wo[img_win_id].number = false
                    vim.wo[img_win_id].relativenumber = false
                    vim.wo[img_win_id].signcolumn = "no"

                    -- Optimización de RAM: Destruir el buffer al cerrar el panel
                    vim.bo[vim.api.nvim_win_get_buf(img_win_id)].bufhidden = "wipe"

                    -- Regresar el foco al código y repintar
                    vim.api.nvim_set_current_win(current_win)
                    vim.cmd("redraw")
                end, waitUntilScrollEnd)
            end
        end
    end,
})

------------------------------------------------------------
-- EVENTO 2: Cerrar y limpiar al moverse de línea
------------------------------------------------------------
vim.api.nvim_create_autocmd("CursorMoved", {
    group = obsidian_img_group,
    pattern = "*.md",
    callback = function()
        local current_line_num = vim.api.nvim_win_get_cursor(0)[1]

        -- Detectar si abandonamos la línea donde se abrió una imagen
        if last_opened_line and last_opened_line ~= current_line_num then
            last_opened_line = nil

            if img_win_id and vim.api.nvim_win_is_valid(img_win_id) then
                pcall(vim.api.nvim_win_close, img_win_id, true)
                img_win_id = nil

                -- Protocolo Kitty: Ocultar gráficos conservando la caché (d=a)
                pcall(vim.api.nvim_chan_send, vim.v.stderr, "\27_Ga=d,d=a;\27\\")
                vim.cmd("redraw!")
            end
        end
    end,
})

------------------------------------------------------------
-- EVENTO 3: Ocultar panel al entrar en Modo Insertar
------------------------------------------------------------
vim.api.nvim_create_autocmd("InsertEnter", {
    group = obsidian_img_group,
    pattern = "*.md",
    callback = function()
        if img_win_id and vim.api.nvim_win_is_valid(img_win_id) then
            pcall(vim.api.nvim_win_close, img_win_id, true)
            img_win_id = nil
            pcall(vim.api.nvim_chan_send, vim.v.stderr, "\27_Ga=d,d=a;\27\\")
            vim.cmd("redraw!")
        end
    end,
})

------------------------------------------------------------
-- ATAJOS DE TECLADO (Mapeos)
------------------------------------------------------------

-- [Esc]: Cierra el panel manualmente si está abierto, respeta la línea actual
vim.keymap.set("n", "<Esc>", function()
    if img_win_id and vim.api.nvim_win_is_valid(img_win_id) then
        pcall(vim.api.nvim_win_close, img_win_id, true)
        img_win_id = nil
        pcall(vim.api.nvim_chan_send, vim.v.stderr, "\27_Ga=d,d=a;\27\\")
        vim.cmd("redraw!")
    end
    vim.cmd("nohlsearch") -- Comportamiento nativo de Esc
end, { desc = "Cerrar panel de imagen y limpiar resaltado" })

-- [<leader>im]: Alternar tamaño del panel (Maximizar / Restaurar a 40 col)
vim.keymap.set("n", "<leader>im", function()
    if img_win_id and vim.api.nvim_win_is_valid(img_win_id) then
        local current_win = vim.api.nvim_get_current_win()
        vim.api.nvim_set_current_win(img_win_id)

        -- Si el ancho supera las 45 celdas, asume que está maximizado
        if vim.api.nvim_win_get_width(img_win_id) > 45 then
            vim.cmd("wincmd =") -- Igualar divisiones
            vim.cmd("vertical resize 40") -- Forzar 40 columnas
        else
            vim.cmd("wincmd _") -- Altura máxima
            vim.cmd("wincmd |") -- Anchura máxima
        end

        vim.api.nvim_set_current_win(current_win)

        -- Limpiar remanentes gráficos estirados tras el redimensionamiento
        pcall(vim.api.nvim_chan_send, vim.v.stderr, "\27_Ga=d,d=a;\27\\")
        vim.cmd("redraw!")
    end
end, { desc = "Maximizar o restaurar panel de imagen" })
