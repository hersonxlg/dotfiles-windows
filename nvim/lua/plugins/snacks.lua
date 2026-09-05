local is_windows = vim.uv.os_uname().sysname:find("Windows") ~= nil

local square_cmd = is_windows
        and "powershell -NoProfile -EncodedCommand JABlACAAPQAgAFsAYwBoAGEAcgBdADIANwAKAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAiACQAZQBgAFsAOQAxAG0AgCUgAIglIACIJSAAgCUgACAAJABlAGAAWwA5ADIAbQCAJSAAiCUgAIglIACAJSAAIAAkAGUAYABbADkAMwBtAIAlIACIJSAAiCUgAIAlIAAgACQAZQBgAFsAOQA0AG0AgCUgAIglIACIJSAAgCUgACAAJABlAGAAWwA5ADUAbQCAJSAAiCUgAIglIACAJSAAIAAkAGUAYABbADkANgBtAIAlIACIJSAAiCUgAIAlIgAKAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAiACQAZQBgAFsAOQAxAG0AiCWIJSAAIAAgAIgliCUgACAAJABlAGAAWwA5ADIAbQCIJYglIAAgACAAiCWIJSAAIAAkAGUAYABbADkAMwBtAIgliCUgACAAIACIJYglIAAgACQAZQBgAFsAOQA0AG0AiCWIJSAAIAAgAIgliCUgACAAJABlAGAAWwA5ADUAbQCIJYglIAAgACAAiCWIJSAAIAAkAGUAYABbADkANgBtAIgliCUgACAAIACIJYglIgAKAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAiACQAZQBgAFsAOQAxAG0AhCUgAIglIACIJSAAhCUgACAAJABlAGAAWwA5ADIAbQCEJSAAiCUgAIglIACEJSAAIAAkAGUAYABbADkAMwBtAIQlIACIJSAAiCUgAIQlIAAgACQAZQBgAFsAOQA0AG0AhCUgAIglIACIJSAAhCUgACAAJABlAGAAWwA5ADUAbQCEJSAAiCUgAIglIACEJSAAIAAkAGUAYABbADkANgBtAIQlIACIJSAAiCUgAIQlJABlAGAAWwAwAG0AIgAKAFMAdABhAHIAdAAtAFMAbABlAGUAcAAgAC0AUwBlAGMAbwBuAGQAcwAgADgANgA0ADAAMAAKAA=="
    or "colorscript -e square"

------------------------------------------------------------
-- 1. FUNCIONES AUXILIARES (Arriba del todo)
------------------------------------------------------------
local function smart_run()
    if vim.bo.modified then
        vim.cmd("w")
    end

    local file = vim.fn.expand("%:p")
    local file_dir = vim.fn.expand("%:p:h")
    local ft = vim.bo.filetype
    local is_win = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

    local root = vim.fs.root(0, { ".git", "xmake.lua", "Cargo.toml", "package.json", "pyproject.toml", "Makefile" })
    local exec_dir = root or file_dir

    -- Pausa universal: Funciona en Bash, Zsh, Fish, y PowerShell 5.1/7+
    local pause_cmd = is_win and ' ; Write-Host "" ; Read-Host "--- Presiona Enter para cerrar ---"'
        or ' ; printf "\n--- Presiona Enter para cerrar ---\n" ; read _'

    -- Respetar Shebangs (#!/usr/bin/env ...)
    local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or ""
    if first_line:sub(1, 2) == "#!" then
        Snacks.terminal(vim.fn.shellescape(file) .. pause_cmd, {
            cwd = file_dir,
            win = { position = "bottom", height = 0.35, border = "rounded" },
        })
        return
    end

    local runners = {
        python = function()
            if vim.fn.executable("uv") == 1 then
                return "uv run " .. vim.fn.shellescape(file)
            end
            local sys_python = is_win and "python" or "python3"
            return sys_python .. " " .. vim.fn.shellescape(file)
        end,

        c = function()
            if root and vim.fn.filereadable(root .. "/xmake.lua") == 1 then
                return "xmake run"
            end
            if is_win then
                return "gcc " .. vim.fn.shellescape(file) .. " -o .\\bin_out.exe ; if ($?) { .\\bin_out.exe }"
            end
            return "gcc " .. vim.fn.shellescape(file) .. " -o /tmp/c_out && /tmp/c_out"
        end,

        cpp = function()
            if root and vim.fn.filereadable(root .. "/xmake.lua") == 1 then
                return "xmake run"
            end
            if is_win then
                return "g++ -std=c++20 "
                    .. vim.fn.shellescape(file)
                    .. " -o .\\bin_out.exe ; if ($?) { .\\bin_out.exe }"
            end
            return "g++ -std=c++20 " .. vim.fn.shellescape(file) .. " -o /tmp/cpp_out && /tmp/cpp_out"
        end,

        rust = function()
            if root and vim.fn.filereadable(root .. "/Cargo.toml") == 1 then
                return "cargo run"
            end
            if is_win then
                return "rustc " .. vim.fn.shellescape(file) .. " -o .\\bin_out.exe ; if ($?) { .\\bin_out.exe }"
            end
            return "rustc " .. vim.fn.shellescape(file) .. " -o /tmp/rs_out && /tmp/rs_out"
        end,

        javascript = function()
            if root and vim.fn.filereadable(root .. "/package.json") == 1 then
                return "bun run start"
            end
            if vim.fn.executable("bun") == 1 then
                return "bun " .. vim.fn.shellescape(file)
            end
            if vim.fn.executable("deno") == 1 then
                return "deno run " .. vim.fn.shellescape(file)
            end
            return "node " .. vim.fn.shellescape(file)
        end,

        typescript = function()
            if root and vim.fn.filereadable(root .. "/package.json") == 1 then
                return "bun run start"
            end
            if vim.fn.executable("bun") == 1 then
                return "bun " .. vim.fn.shellescape(file)
            end
            if vim.fn.executable("deno") == 1 then
                return "deno run " .. vim.fn.shellescape(file)
            end
            return "npx ts-node " .. vim.fn.shellescape(file)
        end,

        lua = function()
            if file_dir:find("nvim") or file_dir:find("lua") then
                return "nvim -l " .. vim.fn.shellescape(file)
            end
            if vim.fn.executable("lua") == 1 then
                return "lua " .. vim.fn.shellescape(file)
            end
            return "nvim -l " .. vim.fn.shellescape(file)
        end,

        sh = function()
            return "bash " .. vim.fn.shellescape(file)
        end,
    }

    local get_cmd = runners[ft]
    if get_cmd then
        Snacks.terminal(get_cmd() .. pause_cmd, {
            cwd = exec_dir,
            win = { position = "bottom", height = 0.35, border = "rounded" },
        })
    else
        vim.notify("No hay regla de ejecución para: " .. ft, vim.log.levels.WARN)
    end
end

------------------------------------------------------------
-- 2. CONFIGURACIÓN DEL PLUGIN LAZY
------------------------------------------------------------

return {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {

        -- Detección y navegación por el ámbito de código activo
        scope = { enabled = true },
        -- Oscurece el código fuera del alcance/ámbito actual
        dim = { enabled = true },

        win = {
            show = true,
            fixbuf = true,
            relative = "editor",
            position = "float",
            minimal = true,
            wo = {
                winhighlight = "Normal:SnacksNormal,NormalNC:SnacksNormalNC,WinBar:SnacksWinBar,WinBarNC:SnacksWinBarNC,FloatTitle:SnacksTitle,FloatFooter:SnacksFooter,WinSeparator:SnacksWinSeparator",
            },
            bo = {},
            title_pos = "center",
            keys = {
                q = "close",
            },
            footer_pos = "center",
            footer_keys = false,
        },

        -- Diálogos de entrada estilizados (remplaza vim.ui.input)
        input = {
            backdrop = false,
            position = "float",
            border = true,
            title_pos = "center",
            height = 1,
            width = 60,
            relative = "editor",
            noautocmd = true,
            row = 2,
            -- relative = "cursor",
            -- row = -3,
            -- col = 0,
            wo = {
                winhighlight = "NormalFloat:SnacksInputNormal,FloatBorder:SnacksInputBorder,FloatTitle:SnacksInputTitle",
                cursorline = false,
            },
            bo = {
                filetype = "snacks_input",
                buftype = "prompt",
            },
            --- buffer local variables
            b = {
                completion = false, -- disable blink completions in input
            },
            keys = {
                n_esc = { "<esc>", { "cmp_close", "cancel" }, mode = "n", expr = true },
                i_esc = { "<esc>", { "cmp_close", "stopinsert" }, mode = "i", expr = true },
                i_cr = { "<cr>", { "cmp_accept", "confirm" }, mode = { "i", "n" }, expr = true },
                i_tab = { "<tab>", { "cmp_select_next", "cmp" }, mode = "i", expr = true },
                i_ctrl_w = { "<c-w>", "<c-s-w>", mode = "i", expr = true },
                i_up = { "<up>", { "hist_up" }, mode = { "i", "n" } },
                i_down = { "<down>", { "hist_down" }, mode = { "i", "n" } },
                q = "cancel",
            },
        },
        -- Notificaciones rápidas (remplaza nvim-notify)
        notifier = { enabled = true },

        profiler = { enabled = true },

        zen = {
            enter = true,
            fixbuf = false,
            minimal = false,
            width = 120,
            height = 0,
            backdrop = { transparent = true, blend = 40 },
            keys = { q = false },
            zindex = 40,
            wo = {
                winhighlight = "NormalFloat:Normal",
            },
            w = {
                snacks_main = true,
            },
        },

        -- 1. Pantalla de inicio

        dashboard = {
            sections = {
                { section = "header" },
                {
                    pane = 2,
                    section = "terminal",
                    cmd = square_cmd,
                    height = 5,
                    padding = 1,
                },
                { section = "keys", gap = 1, padding = 1 },
                { pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
                { pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
                {
                    pane = 2,
                    icon = " ",
                    title = "Git Status",
                    section = "terminal",
                    -- Verifica que estés en un repositorio Git Y que el ejecutable 'git' exista
                    enabled = function()
                        return vim.fn.executable("git") == 1 and Snacks.git.get_root() ~= nil
                    end,
                    cmd = "git status --short --branch --renames",
                    height = 5,
                    padding = 1,
                    ttl = 5 * 60,
                    indent = 3,
                },
                { section = "startup" },
            },
        },
        --        {
        --            sections = {
        --                -- Wide version (180 columns or more)
        --                {
        --                    enabled = function()
        --                        return (vim.o.columns >= 180)
        --                    end,
        --                    {
        --                        section = "header",
        --                        indent = 64,
        --                    },
        --                    {
        --                        pane = 1,
        --                        {
        --                            {
        --                                icon = " ",
        --                                key = "f",
        --                                desc = "Find File",
        --                                action = ":lua Snacks.dashboard.pick('files')",
        --                            },
        --                            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
        --                            {
        --                                icon = " ",
        --                                key = "r",
        --                                desc = "Recent Files",
        --                                action = ":lua Snacks.dashboard.pick('oldfiles')",
        --                            },
        --                            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
        --                            {
        --                                icon = " ",
        --                                key = "g",
        --                                desc = "Find Text",
        --                                action = ":lua Snacks.dashboard.pick('live_grep')",
        --                            },
        --                            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
        --                            {
        --                                icon = "󰒲 ",
        --                                key = "L",
        --                                desc = "Lazy",
        --                                action = ":Lazy",
        --                                enabled = package.loaded.lazy ~= nil,
        --                            },
        --                            { icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
        --                            { icon = "󱁤 ", key = "m", desc = "Mason", action = ":Mason" },
        --                            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        --                            padding = 5,
        --                        },
        --                        {
        --                            section = "startup",
        --                            indent = 64,
        --                        },
        --                    },
        --                    {
        --                        pane = 2,
        --                        {
        --                            padding = 8,
        --                        },
        --                        {
        --                            icon = " ",
        --                            title = "Recent Files",
        --                            section = "recent_files",
        --                            indent = 3,
        --                            padding = 1,
        --                        },
        --                        {
        --                            icon = " ",
        --                            title = "Projects",
        --                            section = "projects",
        --                            indent = 3,
        --                        },
        --                    },
        --                },
        --
        --                -- Slim version (less than 180 columns)
        --                {
        --                    enabled = function()
        --                        return (vim.o.columns < 180)
        --                    end,
        --                    {
        --                        { section = "header" },
        --                        {
        --                            {
        --                                icon = " ",
        --                                key = "f",
        --                                desc = "Find File",
        --                                action = ":lua Snacks.dashboard.pick('files')",
        --                            },
        --                            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
        --                            {
        --                                icon = " ",
        --                                key = "g",
        --                                desc = "Find Text",
        --                                action = ":lua Snacks.dashboard.pick('live_grep')",
        --                            },
        --                            {
        --                                icon = " ",
        --                                key = "r",
        --                                desc = "Recent Files",
        --                                action = ":lua Snacks.dashboard.pick('oldfiles')",
        --                            },
        --                            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
        --                            {
        --                                icon = " ",
        --                                key = "c",
        --                                desc = "Config",
        --                                action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
        --                            },
        --                            {
        --                                icon = "󰒲 ",
        --                                key = "L",
        --                                desc = "Lazy",
        --                                action = ":Lazy",
        --                                enabled = package.loaded.lazy ~= nil,
        --                            },
        --                            { icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
        --                            { icon = "󱁤 ", key = "m", desc = "Mason", action = ":Mason" },
        --                            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        --                            padding = 1,
        --                        },
        --                        {
        --                            icon = " ",
        --                            title = "Recent Files",
        --                            section = "recent_files",
        --                            indent = 3,
        --                            padding = 1,
        --                        },
        --                        {
        --                            icon = " ",
        --                            title = "Projects",
        --                            section = "projects",
        --                            indent = 3,
        --                            padding = 3,
        --                        },
        --                        {
        --                            section = "startup",
        --                        },
        --                    },
        --                },
        --            },
        --        },
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
        scroll = {
            enabled = true,
            animate = {
                duration = { step = 10, total = 200 },
                easing = "linear",
            },
            -- faster animation when repeating scroll after delay
            animate_repeat = {
                delay = 100, -- delay in ms before using the repeat animation
                duration = { step = 5, total = 50 },
                easing = "linear",
            },
            -- what buffers to animate
            filter = function(buf)
                return vim.g.snacks_scroll ~= false
                    and vim.b[buf].snacks_scroll ~= false
                    and vim.bo[buf].buftype ~= "terminal"
            end,
        },

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
        vim.opt.updatetime = 300
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

        -- Abre un panel flotante centrado para buscar líneas dentro del buffer actual
        vim.keymap.set("n", "<leader>fw", function()
            Snacks.picker.lines({
                layout = {
                    preset = "vertical", -- Diseño vertical centrado
                },
            })
        end, { desc = "Buscar en buffer (panel flotante centrado)" })
    end,

    ------------------------------------------------------------
    -- Atajos (shortcuts unificados y corregidos)
    ------------------------------------------------------------
    keys = {
        -- Navegación e inspección de Scope
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

        -- Principales Pickers y Búsquedas rápidas
        {
            "<leader><space>",
            function()
                Snacks.picker.smart()
            end,
            desc = "Búsqueda Inteligente",
        },
        {
            "<leader>,",
            function()
                Snacks.picker.buffers()
            end,
            desc = "Buscar Buffers",
        },
        {
            "<leader>/",
            function()
                Snacks.picker.grep()
            end,
            desc = "Grep Global",
        },
        {
            "<leader>:",
            function()
                Snacks.picker.command_history()
            end,
            desc = "Historial de Comandos",
        },
        {
            "<leader>n",
            function()
                Snacks.picker.notifications()
            end,
            desc = "Historial de Notificaciones",
        },
        {
            "<c-n>",
            function()
                Snacks.explorer()
            end,
            desc = "Toggle explorador de archivos",
        },
        {
            "<leader>e",
            function()
                Snacks.explorer()
            end,
            desc = "Explorador de Archivos",
        },

        -- Búsqueda de archivos y buffers
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
        {
            "<leader>fp",
            function()
                Snacks.picker.projects()
            end,
            desc = "Proyectos",
        },
        {
            "<leader>fr",
            function()
                Snacks.picker.recent()
            end,
            desc = "Archivos Recientes",
        },

        -- Integración Git y GitHub
        {
            "<leader>gb",
            function()
                Snacks.gitbrowse()
            end,
            desc = "Abrir en GitHub/GitLab",
            mode = { "n", "v" },
        },
        {
            "<leader>gB",
            function()
                Snacks.picker.git_branches()
            end,
            desc = "Buscar Ramas de Git",
        },
        {
            "<leader>pg",
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
        {
            "<leader>gS",
            function()
                Snacks.picker.git_stash()
            end,
            desc = "Git Stash",
        },
        {
            "<leader>gd",
            function()
                Snacks.picker.git_diff()
            end,
            desc = "Git Diff",
        },
        {
            "<leader>gi",
            function()
                Snacks.picker.gh_issue()
            end,
            desc = "GitHub Issues (abiertos)",
        },
        {
            "<leader>gp",
            function()
                Snacks.picker.gh_pr()
            end,
            desc = "GitHub Pull Requests (abiertos)",
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
            "gd",
            function()
                Snacks.picker.lsp_definitions()
            end,
            desc = "Ir a Definición",
        },
        {
            "gD",
            function()
                Snacks.picker.lsp_declarations()
            end,
            desc = "Ir a Declaración",
        },
        {
            "gI",
            function()
                Snacks.picker.lsp_implementations()
            end,
            desc = "Ir a Implementación",
        },
        {
            "gy",
            function()
                Snacks.picker.lsp_type_definitions()
            end,
            desc = "Ir a Definición de Tipo",
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

        -- Terminales y LazyGit
        {
            "<leader>tf",
            function()
                local dir = vim.fn.expand("%:p:h")
                Snacks.terminal(nil, { cwd = dir ~= "" and dir or nil })
            end,
            desc = "Terminal flotante en carpeta actual",
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

        -- Buffers, Ventanas y Utilidades
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
            desc = "Alternar Zoom",
        },
        {
            "<leader>ud",
            function()
                Snacks.dim()
            end,
            desc = "Alternar Modo Dim (Enfoque)",
        },
        {
            "<leader>cR",
            function()
                Snacks.rename.rename_file()
            end,
            desc = "Renombrar Archivo Actual",
        },
        {
            "<leader>un",
            function()
                Snacks.notifier.hide()
            end,
            desc = "Ocultar Notificaciones",
        },

        -- Ayuda, Temas y Picker Extras
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
        {
            "<leader>sk",
            function()
                Snacks.picker.keymaps()
            end,
            desc = "Ver todos los atajos de teclado",
        },
        {
            "<leader>sK",
            function()
                Snacks.picker.keymaps({ pattern = "Snacks" })
            end,
            desc = "Ver atajos de Snacks",
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
            desc = "Reabrir la última búsqueda",
        },
        {
            "<leader>pr",
            function()
                Snacks.picker.resume()
            end,
            desc = "Reanudar última búsqueda",
        },
        {
            "<leader>su",
            function()
                Snacks.picker.undo()
            end,
            desc = "Historial de Deshacer (Undo Tree)",
        },

        -- Imágenes
        {
            "<leader>ih",
            function()
                Snacks.image.hover()
            end,
            desc = "Vista previa flotante de imagen",
        },
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

                local is_win = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
                local target_path = is_win and full_path:gsub("/", "\\") or full_path

                vim.notify("📷 Abriendo imagen en visor externo...", vim.log.levels.INFO, { title = "Obsidian" })

                local apps = is_win and { "qview", "imageglass", "irfanview", "mpv" }
                    or { "nsxiv", "feh", "sxiv", "eog", "loupe" }

                for _, app in ipairs(apps) do
                    if vim.fn.executable(app) == 1 then
                        vim.system({ app, target_path }, { detach = true })
                        return
                    end
                end

                if is_win then
                    vim.system({ "cmd.exe", "/c", "start", "", target_path }, { detach = true })
                else
                    vim.ui.open(target_path)
                end
            end,
            ft = "markdown",
            desc = "Abrir imagen en visor externo",
        },

        -- Terminales Flotantes
        {
            "<A-;>",
            function()
                local active_terms = Snacks.terminal.list()
                local term = active_terms[1] or Snacks.terminal.get()
                if term then
                    if term.win and vim.api.nvim_win_is_valid(term.win) then
                        term:hide()
                    else
                        term:show()
                    end
                end
            end,
            mode = { "n", "t" },
            desc = "Toggle Terminal Flotante",
        },
        {
            "<leader>os",
            function()
                local root_dir = vim.fn.getcwd()
                local file_dir = vim.fn.expand("%:p:h")
                local term = Snacks.terminal.get()
                if term then
                    term:show()
                end
            end,
            mode = { "n", "t" },
            desc = "Terminal en carpeta del archivo",
        },

        -- Profiler
        {
            "<leader>pp",
            function()
                Snacks.profiler.toggle()
            end,
            desc = "Iniciar/Detener Profiler",
        },
        {
            "<leader>pS",
            function()
                Snacks.profiler.scratch()
            end,
            desc = "Scratch Buffer del Profiler",
        },
        {
            "<leader>ph",
            function()
                Snacks.profiler.highlight()
            end,
            desc = "Alternar Highlights de Profiler",
        },
        -- En los atajos de Snacks:
        {
            "<leader>x",
            function()
                smart_run()
            end,
            desc = "Ejecutar proyecto o script actual",
        },
    },
}
