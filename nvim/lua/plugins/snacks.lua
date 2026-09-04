return {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
        -- Detección y navegación por el ámbito de código activo
        scope = { enabled = true },
        -- Oscurece el código fuera del alcance/ámbito actual
        dim = { enabled = true },
        -- Diálogos de entrada estilizados (remplaza vim.ui.input)
        input = { enabled = true },

        -- Notificaciones rápidas (remplaza nvim-notify)
        notifier = { enabled = true },
        -- 1. Pantalla de inicio
        dashboard = { enabled = true },

        -- 2. Guias de sangrado y scope
        indent = { enabled = true },

        -- 3. Buscador Fuzzy
        picker = {
            enabled = true,
            ui_select = true,
        },

        -- 4. Arbol de archivos lateral
        explorer = { enabled = true },

        -- 5. Terminal Flotante y LazyGit con diseño estilizado
        terminal = {
            enabled = true,
            win = {
                position = "float",
                border = "rounded",
                title = " Terminal ",
                title_pos = "center",
                width = 0.85,
                height = 0.85,
                backdrop = 60,
            },
        },

        -- 6. Navegación entre palabras/variables LSP
        words = { enabled = true },

        -- 7. Optimizaciones de rendimiento
        bigfile = { enabled = true },
        quickfile = { enabled = true },

        -- 8. Animaciones
        animate = {
            enabled = true,
            duration = 20,
            fps = 60,
            easing = "outQuad",
        },
        -- 9. Desplazamiento suave (Smooth Scroll)
        scroll = { enabled = true },
        -- 10. Renderizado e inspección de imágenes con Snacks
        image = {
            enabled = true,
            doc = {
                --inline = true, -- Intenta renderizar dentro del buffer
                --float = true, -- Muestra vista previa en ventana flotante si inline falla
                inline = false, -- Intenta renderizar dentro del buffer
                float = false, -- Muestra vista previa en ventana flotante si inline falla
                --max_width = 80,
                --max_height = 20,
            },
        },
    },
    config = function(_, opts)
        require("snacks").setup(opts)

        ------------------------------------------------------------
        -- AUTOCOMANDOS: Precarga la shell principal en segundo
        --               plano y regresa a Modo Normal.
        ------------------------------------------------------------
        vim.api.nvim_create_autocmd("UIEnter", {
            once = true,
            callback = function()
                vim.schedule(function()
                    local term = Snacks.terminal.get()
                    if term then
                        term:hide()
                    end
                    vim.cmd("stopinsert") -- Fuerza al editor principal a quedar en Modo Normal
                end)
            end,
        })

        ------------------------------------------------------------
        -- AUTOCOMANDOS: Vista previa de imágenes de Obsidian
        ------------------------------------------------------------
        vim.opt.updatetime = 50
        local waitUntilScrollEnd = 20
        local last_opened_line = nil
        local img_win_id = nil

        local group = vim.api.nvim_create_augroup("ObsidianImageDetector", { clear = true })

        local function clear_terminal_graphics()
            pcall(vim.api.nvim_chan_send, vim.v.stderr, "\27_Ga=d,d=a;\27\\")
            vim.cmd("redraw!")
        end

        local function close_image_panel()
            if img_win_id and vim.api.nvim_win_is_valid(img_win_id) then
                pcall(vim.api.nvim_win_close, img_win_id, true)
                img_win_id = nil
                clear_terminal_graphics()
                return true
            end
            return false
        end

        -- 1. Detectar y abrir la imagen al detener el cursor
        vim.api.nvim_create_autocmd("CursorHold", {
            group = group,
            pattern = "*.md",
            callback = function()
                local current_line_num = vim.api.nvim_win_get_cursor(0)[1]
                local line = vim.api.nvim_get_current_line()

                local wiki_match = line:match("%!%[%[(.-)%]%]")
                local md_match = line:match("%!%[.-%]%((.-)%)")
                local img_name = wiki_match or md_match

                if img_name then
                    if last_opened_line == current_line_num then
                        return
                    end
                    last_opened_line = current_line_num

                    img_name = img_name:gsub("%%20", " ")
                    local attachments_dir = vim.fn.expand("~/syncthing/obsidian/attachments/")
                    local full_path = vim.fs.normalize(attachments_dir .. img_name)

                    if vim.fn.filereadable(full_path) == 1 then
                        vim.cmd("normal! zt")

                        vim.defer_fn(function()
                            if vim.api.nvim_win_get_cursor(0)[1] ~= current_line_num then
                                return
                            end

                            if img_win_id and vim.api.nvim_win_is_valid(img_win_id) then
                                pcall(vim.api.nvim_win_close, img_win_id, true)
                            end

                            local current_win = vim.api.nvim_get_current_win()
                            vim.cmd("botright 40vsplit " .. vim.fn.fnameescape(full_path))
                            img_win_id = vim.api.nvim_get_current_win()

                            vim.wo[img_win_id].number = false
                            vim.wo[img_win_id].relativenumber = false
                            vim.wo[img_win_id].signcolumn = "no"
                            vim.bo[vim.api.nvim_win_get_buf(img_win_id)].bufhidden = "wipe"

                            vim.api.nvim_set_current_win(current_win)
                            vim.cmd("redraw")
                        end, waitUntilScrollEnd)
                    end
                end
            end,
        })

        -- 2. Cerrar al mover el cursor fuera de la línea
        vim.api.nvim_create_autocmd("CursorMoved", {
            group = group,
            pattern = "*.md",
            callback = function()
                local current_line_num = vim.api.nvim_win_get_cursor(0)[1]
                if last_opened_line and last_opened_line ~= current_line_num then
                    last_opened_line = nil
                    close_image_panel()
                end
            end,
        })

        -- 3. Cerrar al entrar a Modo Insertar
        vim.api.nvim_create_autocmd("InsertEnter", {
            group = group,
            pattern = "*.md",
            callback = function()
                close_image_panel()
            end,
        })

        -- Atajo para Maximizar / Restaurar el panel de la imagen
        vim.keymap.set("n", "<leader>im", function()
            if img_win_id and vim.api.nvim_win_is_valid(img_win_id) then
                local current_win = vim.api.nvim_get_current_win()
                vim.api.nvim_set_current_win(img_win_id)

                if vim.api.nvim_win_get_width(img_win_id) > 45 then
                    vim.cmd("wincmd =")
                    vim.cmd("vertical resize 40")
                else
                    vim.cmd("wincmd _")
                    vim.cmd("wincmd |")
                end

                vim.api.nvim_set_current_win(current_win)
                clear_terminal_graphics()
            end
        end, { desc = "Maximizar o restaurar panel de imagen" })
    end,

    ------------------------------------------------------------
    -- Atajos (shortcuts)
    ------------------------------------------------------------
    keys = {
        -- Saltar al inicio o final del bloque actual
        {
            "[s",
            function()
                Snacks.scope.jump({ edge = "top" })
            end,
            desc = "Ir al inicio del Scope",
        },
        {
            "]s",
            function()
                Snacks.scope.jump({ edge = "bottom" })
            end,
            desc = "Ir al final del Scope",
        },

        -- Textobjects: Seleccionar dentro o todo el Scope (en modo visual u operador)
        {
            "ii",
            function()
                Snacks.scope.textobject({ inner = true })
            end,
            mode = { "o", "x" },
            desc = "Seleccionar contenido del Scope",
        },
        {
            "ai",
            function()
                Snacks.scope.textobject({ inner = false })
            end,
            mode = { "o", "x" },
            desc = "Seleccionar Scope completo con cabecera",
        },
        {
            "<leader>ud",
            function()
                Snacks.dim()
            end,
            desc = "Alternar Modo Dim (Enfoque de ámbito)",
        },
        -- Explorador de archivos
        {
            "<c-n>",
            function()
                Snacks.explorer()
            end,
            desc = "Toggle explorador de archivos",
        },

        -- Búsquedas generales de archivos
        {
            "<C-p>",
            function()
                Snacks.picker.files()
            end,
            desc = "Buscar archivos",
        },
        {
            "<leader>ff",
            function()
                Snacks.picker.files()
            end,
            desc = "Buscar archivos",
        },
        {
            "<leader>pf",
            function()
                Snacks.picker.files()
            end,
            desc = "Buscar archivos (Find Files)",
        },
        {
            "<leader>en",
            function()
                Snacks.picker.files({ cwd = vim.fn.stdpath("config") })
            end,
            desc = "Archivos de configuración Neovim",
        },
        {
            "<leader>fg",
            function()
                Snacks.picker.grep()
            end,
            desc = "Buscar texto (Grep)",
        },
        {
            "<leader>fc",
            function()
                Snacks.picker.grep_word()
            end,
            desc = "Buscar palabra bajo el cursor",
        },
        {
            "<leader>fb",
            function()
                Snacks.picker.buffers()
            end,
            desc = "Buscar en buffers",
        },

        -- Integración LSP
        {
            "grr",
            function()
                Snacks.picker.lsp_references()
            end,
            desc = "LSP Referencias",
        },
        {
            "<leader>ds",
            function()
                Snacks.picker.lsp_symbols()
            end,
            desc = "LSP Símbolos del documento",
        },
        {
            "<leader>fd",
            function()
                Snacks.picker.diagnostics()
            end,
            desc = "Buscar diagnósticos/errores LSP",
        },

        -- Integración Git
        {
            "<leader>pp",
            function()
                Snacks.picker.git_files()
            end,
            desc = "Buscar archivos Git",
        },
        {
            "<leader>gs",
            function()
                Snacks.picker.git_status()
            end,
            desc = "Git Status",
        },
        {
            "<leader>gc",
            function()
                Snacks.picker.git_log()
            end,
            desc = "Git Commits",
        },

        -- Terminales y LazyGit
        {
            "<leader>tf",
            function()
                local dir = vim.fn.expand("%:p:h")
                Snacks.terminal(nil, { cwd = dir ~= "" and dir or nil })
            end,
            desc = "Terminal flotante en directorio del archivo actual",
        },
        {
            "<leader>tv",
            function()
                Snacks.terminal(nil, { win = { position = "right", width = 0.4, border = "none" } })
            end,
            desc = "Terminal vertical",
        },
        {
            "<leader>lg",
            function()
                Snacks.lazygit()
            end,
            desc = "Toggle LazyGit",
        },

        -- Gestión de Buffers
        {
            "<leader>bd",
            function()
                Snacks.bufdelete()
            end,
            desc = "Cerrar buffer actual",
        },
        {
            "<leader>bo",
            function()
                Snacks.bufdelete.other()
            end,
            desc = "Cerrar todos los demás buffers",
        },

        -- Bloc de notas rápido (Scratchpad)
        {
            "<leader>bs",
            function()
                Snacks.scratch()
            end,
            desc = "Abrir buffer borrador temporal",
        },
        {
            "<leader>bS",
            function()
                Snacks.scratch.select()
            end,
            desc = "Buscar en borradores guardados",
        },

        -- Modo Enfoque / Zen
        {
            "<leader>z",
            function()
                Snacks.zen()
            end,
            desc = "Activar/Desactivar Modo Zen",
        },
        {
            "<leader>Z",
            function()
                Snacks.zen.zoom()
            end,
            desc = "Alternar Zoom de la ventana activa",
        },

        -- Utilidades de Git
        {
            "<leader>gb",
            function()
                Snacks.gitbrowse()
            end,
            desc = "Abrir línea/archivo actual en GitHub/GitLab",
        },

        -- Navegación LSP
        {
            "]]",
            function()
                Snacks.words.jump(1, true)
            end,
            mode = { "n", "x" },
            desc = "Siguiente referencia LSP",
        },
        {
            "[[",
            function()
                Snacks.words.jump(-1, true)
            end,
            mode = { "n", "x" },
            desc = "Anterior referencia LSP",
        },

        -- Búsquedas extra en el Picker
        {
            "<leader>sk",
            function()
                Snacks.picker.keymaps()
            end,
            desc = "Ver todos los atajos de teclado del editor",
        },
        {
            "<leader>uT",
            function()
                Snacks.picker.colorschemes()
            end,
            desc = "Seleccionar Tema de Color",
        },
        {
            "<leader>sh",
            function()
                Snacks.picker.help()
            end,
            desc = "Buscar en la documentación de Neovim",
        },
        {
            "<leader>sr",
            function()
                Snacks.picker.resume()
            end,
            desc = "Reabrir la última ventana de búsqueda",
        },
        {
            "<leader>pr",
            function()
                Snacks.picker.resume()
            end,
            desc = "Reanudar última búsqueda",
        },

        -- Interacción y vista previa de imágenes (Multiplataforma)
        {
            "<leader>ih",
            function()
                Snacks.image.hover()
            end,
            desc = "Vista previa flotante de imagen (Hover)",
        },

        -- Interacción y apertura de imágenes en visor externo (Instantáneo + Con Foco)
        {
            "<CR>",
            function()
                local line = vim.api.nvim_get_current_line()
                local wiki_match = line:match("%!%[%[(.-)%]%]")
                local md_match = line:match("%!%[.-%]%((.-)%)")
                local img_name = wiki_match or md_match

                if not img_name or img_name == "" then
                    vim.notify("No se detectó ningún enlace de imagen en la línea actual", vim.log.levels.WARN)
                    return
                end

                img_name = img_name:gsub("%%20", " ")
                local attachments_dir = vim.fn.expand("~/syncthing/obsidian/attachments/")
                local full_path = vim.fs.normalize(attachments_dir .. img_name)

                if vim.fn.filereadable(full_path) == 0 then
                    vim.notify("No se encontró la imagen: " .. full_path, vim.log.levels.ERROR)
                    return
                end

                local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
                local target_path = is_windows and full_path:gsub("/", "\\") or full_path

                -- 1. Feedback visual instantáneo para confirmar el atajo
                vim.notify("📷 Abriendo imagen en visor externo...", vim.log.levels.INFO, { title = "Obsidian" })

                -- 2. Visores dedicados prioritarios (si existen en el PATH)
                local apps = is_windows and { "qview", "imageglass", "irfanview", "mpv" }
                    or { "nsxiv", "feh", "sxiv", "eog", "loupe" }

                for _, app in ipairs(apps) do
                    if vim.fn.executable(app) == 1 then
                        vim.system({ app, target_path }, { detach = true })
                        return
                    end
                end

                -- 3. Fallback con foco forzado según el Sistema Operativo
                if is_windows then
                    -- 'cmd.exe /c start ""' obliga a Windows a traer la app lanzada al primer plano
                    vim.system({ "cmd.exe", "/c", "start", "", target_path }, { detach = true })
                else
                    vim.ui.open(target_path)
                end
            end,
            desc = "Abrir imagen en visor externo (con foco y notificación)",
        },

        -- Terminal Flotante General (Toggle / Raíz del proyecto)
        {
            "<A-;>",
            function()
                local active_terms = Snacks.terminal.list()
                local term = active_terms[1] or Snacks.terminal.get()

                if term then
                    -- Comprueba si la ventana de la terminal está actualmente visible
                    local is_open = term.win and vim.api.nvim_win_is_valid(term.win)

                    if is_open then
                        term:hide()
                    else
                        term:show()
                        local root_dir = vim.fn.getcwd()
                        term._current_cwd = term._current_cwd or root_dir

                        -- Si venías de una subcarpeta con <leader>os, regresa a la raíz
                        if term._current_cwd ~= root_dir then
                            local job_id = term.buf and vim.b[term.buf] and vim.b[term.buf].terminal_job_id
                            if job_id then
                                local cmd = vim.fn.has("win32") == 1
                                        and string.format("cd '%s'\r\n", root_dir:gsub("/", "\\"))
                                    or string.format("cd %s\n", vim.fn.fnameescape(root_dir))
                                vim.api.nvim_chan_send(job_id, cmd)
                                term._current_cwd = root_dir
                            end
                        end
                    end
                end
            end,
            mode = { "n", "t" },
            desc = "Toggle Terminal Flotante (Raíz del proyecto)",
        },

        -- Terminal Flotante en carpeta del archivo actual
        {
            "<leader>os",
            function()
                local root_dir = vim.fn.getcwd()
                local file_dir = vim.fn.expand("%:p:h")

                if file_dir == "" or file_dir:find("term://") then
                    file_dir = root_dir
                end

                local active_terms = Snacks.terminal.list()
                local term = active_terms[1] or Snacks.terminal.get()

                if term then
                    term:show()
                    term._current_cwd = term._current_cwd or root_dir

                    -- Solo cambia de directorio si la carpeta es distinta a la actual
                    if term._current_cwd ~= file_dir then
                        local job_id = term.buf and vim.b[term.buf] and vim.b[term.buf].terminal_job_id
                        if job_id then
                            local cmd = vim.fn.has("win32") == 1
                                    and string.format("cd '%s'\r\n", file_dir:gsub("/", "\\"))
                                or string.format("cd %s\n", vim.fn.fnameescape(file_dir))
                            vim.api.nvim_chan_send(job_id, cmd)
                            term._current_cwd = file_dir
                        end
                    end
                end
            end,
            mode = { "n", "t" },
            desc = "Terminal en carpeta del archivo (<leader>os)",
        },
    },
}
