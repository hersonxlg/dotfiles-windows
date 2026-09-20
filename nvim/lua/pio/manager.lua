-- ============================================================================
-- GESTOR UNIFICADO PLATFORMIO CON OIL.NVIM (pio-manager.lua)
-- ============================================================================

local M = {}

--------------------------------------------------------------------------------
-- 1. DETECCIÓN RECURSIVA DE RAÍZ DE PROYECTO
--------------------------------------------------------------------------------

local function find_pio_project_root(path)
    if not path or path == "" then
        return nil
    end
    local current = path
    if vim.fn.isdirectory(current) == 0 then
        current = vim.fn.fnamemodify(current, ":h")
    end

    while current and current ~= "" and current ~= "/" and not current:match("^%a:[/\\]?$") do
        if
            vim.fn.filereadable(current .. "/platformio.ini") == 1
            or vim.fn.filereadable(current .. "\\platformio.ini") == 1
        then
            return current
        end
        local parent = vim.fn.fnamemodify(current, ":h")
        if parent == current then
            break
        end
        current = parent
    end
    return nil
end

--------------------------------------------------------------------------------
-- 2. APERTURA DE PROYECTO DETECTADO
--------------------------------------------------------------------------------

local function open_existing_project(project_root)
    vim.api.nvim_set_current_dir(project_root)
    vim.notify("⚡ Proyecto PlatformIO cargado: " .. project_root, vim.log.levels.INFO)

    local main_file = project_root .. "/src/main.cpp"
    if vim.fn.filereadable(main_file) == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(main_file))
    else
        vim.cmd("edit " .. vim.fn.fnameescape(project_root .. "/platformio.ini"))
    end
end

--------------------------------------------------------------------------------
-- 3. ENTRADA Y SOBRESCRITURA GARANTIZADA EN OIL
--------------------------------------------------------------------------------

function M.open_manager()
    local ok_oil, oil = pcall(require, "oil")
    if not ok_oil then
        vim.notify("❌ El plugin `oil.nvim` no está instalado.", vim.log.levels.ERROR)
        return
    end

    -- 1. Abrir Oil en el directorio actual
    oil.open(vim.fn.getcwd())

    -- 2. vim.schedule garantiza que la asignación se ejecute DESPUÉS de que Oil configure el buffer
    vim.schedule(function()
        local buf = vim.api.nvim_get_current_buf()
        if vim.bo[buf].filetype ~= "oil" then
            return
        end

        -- Sobrescribir <CR> (Enter) para interceptar la selección
        vim.keymap.set("n", "<CR>", function()
            local entry = oil.get_cursor_entry()
            local dir = oil.get_current_dir()
            if not dir then
                return
            end

            local chosen_path = dir
            if entry then
                chosen_path = dir .. entry.name
            end

            local chosen_dir = vim.fn.isdirectory(chosen_path) == 1 and chosen_path
                or vim.fn.fnamemodify(chosen_path, ":h")
            local project_root = find_pio_project_root(chosen_dir)

            if project_root then
                -- Si la carpeta (o alguna superior) es un proyecto PlatformIO -> Abrir
                open_existing_project(project_root)
            else
                -- Si no es un proyecto -> Iniciar el Wizard de creación en esta carpeta
                local ok_proj, pio_project = pcall(require, "pio-project")
                if ok_proj and pio_project.interactive_create_project_wizard then
                    pio_project.interactive_create_project_wizard({ target_dir = chosen_dir })
                end
            end
        end, { buffer = buf, noremap = true, silent = true, nowait = true, desc = "PlatformIO Enter Handler" })

        -- Tecla 'l' para navegar dentro de carpetas normalmente sin activar el detector
        vim.keymap.set("n", "l", function()
            oil.select()
        end, { buffer = buf, noremap = true, silent = true, desc = "Navegar dentro de la carpeta" })
    end)
end

--------------------------------------------------------------------------------
-- 4. REGISTRO DEL COMANDO ÚNICO
--------------------------------------------------------------------------------

vim.api.nvim_create_user_command("PioManager", function()
    M.open_manager()
end, { desc = "Abre Oil para navegar o crear proyectos PlatformIO" })

return M
