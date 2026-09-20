local lib = require("pio.library")
local runner = require("pio.runner")
local ini_manager = require("pio.ini")
local generator = require("pio.generator")
local history = require("pio.history")

local M = {}

local LOG_FILE = vim.fn.stdpath("cache") .. "/pio.log"

local function log(level, msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local line = string.format("[%s] [%s] %s\n", timestamp, level, msg)
    local f = io.open(LOG_FILE, "a")
    if f then
        f:write(line)
        f:close()
    end
end

local function clean_value(val, key)
    if type(val) == "table" then
        val = val[key] or (key == "baud" and val.rate) or val.id or val.value or val.text or val[1] or ""
    end
    local str = tostring(val or "")
    if str:find("=") then
        str = str:match("=%s*(.-)%s*$") or str
    end
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    return str
end

local function get_lib_fn(...)
    for _, name in ipairs({ ... }) do
        if type(lib[name]) == "function" then
            return lib[name]
        end
    end
    return nil
end

local function await(async_fn, ...)
    if type(async_fn) ~= "function" then
        local err_msg = "Se intentó ejecutar una función inexistente o 'nil' en pio.library."
        log("ERROR", err_msg)
        error(err_msg)
    end
    local co = coroutine.running()
    local n = select("#", ...)
    local args = { ... }
    args[n + 1] = function(res)
        if coroutine.status(co) == "suspended" then
            coroutine.resume(co, res)
        end
    end
    async_fn(unpack(args, 1, n + 1))
    return coroutine.yield()
end

--- Analizador interno adaptativo que soporta valores monolínea y multilínea (lib_deps, build_flags, etc.)
local function parse_ini_file(filepath)
    local f = io.open(filepath, "r")
    if not f then
        return nil
    end

    local result = {}
    local last_key = nil

    for line in f:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        -- Ignorar líneas vacías, comentarios (;) (#) y nombres de sección ([...])
        if trimmed ~= "" and trimmed:sub(1, 1) ~= ";" and trimmed:sub(1, 1) ~= "#" and trimmed:sub(1, 1) ~= "[" then
            -- Aceptamos '=' seguido de 0 o más caracteres (permite claves vacías como "lib_deps =")
            local key, val = line:match("^%s*([^=]+)=(.*)$")
            if key then
                key = key:match("^%s*(.-)%s*$")
                val = val:match("^%s*(.-)%s*$")
                result[key] = val
                last_key = key
            elseif last_key then
                -- Acumulación multilínea indentada
                if result[last_key] == "" then
                    result[last_key] = trimmed
                else
                    result[last_key] = result[last_key] .. "\n" .. trimmed
                end
            end
        end
    end
    f:close()
    return result
end

function M.manage_project(project_path_arg)
    local log_init = io.open(LOG_FILE, "a")
    if log_init then
        log_init:write("\n=========================================\n")
        log_init:write("=== NUEVA SESIÓN PIO.PROJECT (" .. os.date("%H:%M:%S") .. ") ===\n")
        log_init:write("=========================================\n")
        log_init:close()
    end

    local search_start = vim.fn.fnamemodify(project_path_arg or vim.fn.getcwd(), ":p")
    if vim.fn.isdirectory(search_start) == 0 then
        search_start = vim.fn.fnamemodify(search_start, ":h")
    end

    search_start = search_start:gsub("[/\\]$", "")

    local found = vim.fs.find("platformio.ini", {
        upward = true,
        path = search_start,
        type = "file",
    })

    local is_edit = #found > 0
    local project_path, ini_path

    if is_edit then
        ini_path = vim.fn.fnamemodify(found[1], ":p")
        project_path = vim.fn.fnamemodify(ini_path, ":h")
    else
        project_path = search_start
        ini_path = project_path .. "/platformio.ini"
    end

    local mode = is_edit and "edit" or "create"
    log("INFO", "Path del proyecto resuelto: " .. project_path)
    log("INFO", "Modo detectado: " .. mode)

    local existing_config = nil
    if is_edit then
        existing_config = parse_ini_file(ini_path)
    end

    coroutine.wrap(function()
        local ok, err = pcall(function()
            local config = {
                port = "auto",
                baud = "115200",
                board = "esp32-s3-devkitc-1",
                flash = "default",
                psram = "none",
                has_psram = false,
                psram_lines = {},
                framework = "arduino",
                libs = {},
            }

            if existing_config and type(existing_config) == "table" then
                log("INFO", "Config en bruto leída del .ini: " .. vim.inspect(existing_config))

                config.port = existing_config.upload_port
                    or existing_config.monitor_port
                    or existing_config.port
                    or config.port
                config.baud = existing_config.monitor_speed or existing_config.baud or config.baud
                config.board = existing_config.board or config.board
                config.framework = existing_config.framework or config.framework

                if existing_config["board_build.flash_size"] then
                    config.flash = existing_config["board_build.flash_size"]
                end

                local has_psram_flag = false
                if existing_config["build_flags"] and existing_config["build_flags"]:match("-DBOARD_HAS_PSRAM") then
                    has_psram_flag = true
                end
                config.has_psram = has_psram_flag

                if existing_config["board_build.arduino.memory_type"] then
                    config.psram = existing_config["board_build.arduino.memory_type"]
                elseif has_psram_flag then
                    config.psram = "qio_opi"
                else
                    config.psram = "none"
                end

                if existing_config.lib_deps then
                    local parsed_libs = {}
                    -- Separa por comas o por saltos de línea (multilínea)
                    for lib_item in existing_config.lib_deps:gmatch("[^\r\n,]+") do
                        local clean_lib = lib_item:match("^%s*(.-)%s*$")
                        if clean_lib ~= "" then
                            table.insert(parsed_libs, clean_lib)
                        end
                    end
                    config.libs = parsed_libs
                end

                log("INFO", "Configuración mapeada y lista para la UI: " .. vim.inspect(config))
            end

            local steps = {
                {
                    key = "port",
                    fn = function(c)
                        return await(lib.pio_select_serial_port, clean_value(c.port, "port"))
                    end,
                },
                {
                    key = "baud",
                    fn = function(c)
                        return await(lib.pio_select_baud_rate, clean_value(c.baud, "baud"))
                    end,
                },
                {
                    key = "board",
                    fn = function(c)
                        local preferred = history.load()
                        if not preferred or #preferred == 0 then
                            preferred = nil
                        end
                        return await(lib.pio_select_board_snacks, clean_value(c.board, "board"), preferred)
                    end,
                },
                {
                    key = "flash",
                    cond = function(c)
                        return clean_value(c.board, "board"):match("esp32%-s3") ~= nil
                    end,
                    fn = function(c)
                        local flash_fn =
                            get_lib_fn("pio_select_flash_size", "pio_select_esp32s3_flash", "pio_select_flash")
                        if not flash_fn then
                            return { action = "next", value = c.flash or "default" }
                        end
                        return await(flash_fn, clean_value(c.flash, "flash"))
                    end,
                },
                {
                    key = "psram",
                    cond = function(c)
                        return clean_value(c.board, "board"):match("esp32%-s3") ~= nil
                    end,
                    fn = function(c)
                        local psram_fn =
                            get_lib_fn("pio_select_psram_type", "pio_select_esp32s3_psram", "pio_select_psram")
                        if not psram_fn then
                            return { action = "next", value = c.psram or "none" }
                        end
                        return await(psram_fn, clean_value(c.psram, "psram"), c.has_psram)
                    end,
                },
                {
                    key = "framework",
                    fn = function(c)
                        return await(
                            lib.pio_select_framework,
                            clean_value(c.board, "board"),
                            clean_value(c.framework, "framework")
                        )
                    end,
                },
                {
                    key = "libs",
                    fn = function(c)
                        return await(lib.pio_manage_installed_libs, c.libs)
                    end,
                },
            }

            local idx = 1
            local direction = 1

            while idx >= 1 and idx <= #steps do
                local step = steps[idx]

                if not step.cond or step.cond(config) then
                    log("INFO", string.format("Iniciando paso %d/%d: %s", idx, #steps, step.key))
                    local res = step.fn(config)

                    if step.key == "libs" and type(res) == "table" and not res.action then
                        res = { action = "next", value = res }
                    end

                    if not res or res.action == "cancel" then
                        log("WARN", "Operación cancelada por el usuario en: " .. step.key)
                        vim.notify("Operación cancelada. No se aplicaron cambios.", vim.log.levels.WARN)
                        return
                    elseif res.action == "prev" then
                        if res.value ~= nil and type(res.value) ~= "table" and res.value ~= "" then
                            config[step.key] = clean_value(res, step.key)
                        end
                        idx = idx - 1
                        direction = -1
                    elseif res.action == "next" then
                        if step.key == "libs" then
                            config.libs = res.value or res.libs or {}
                        elseif step.key == "psram" then
                            config.psram = res.mem_type or (res.item and res.item.id) or "none"
                            config.has_psram = (res.item and res.item.has_psram) or false
                            config.psram_lines = res.lines or {}
                        else
                            config[step.key] = clean_value(res, step.key)
                        end
                        log(
                            "INFO",
                            string.format("Paso %s completado. Config limpia: %s", step.key, vim.inspect(config))
                        )
                        idx = idx + 1
                        direction = 1
                    end
                else
                    log("INFO", string.format("Omitiendo paso %d (%s) por condición no cumplida.", idx, step.key))
                    idx = idx + direction
                end
            end

            local board_id = clean_value(config.board, "board")

            if board_id == "" then
                log("ERROR", "El ID de la placa quedó vacío.")
                vim.notify("Error: No se especificó un ID de placa válido.", vim.log.levels.ERROR)
                return
            end

            -- Registrar la placa en el historial permanente
            history.add(board_id)

            if mode == "create" then
                vim.fn.mkdir(project_path, "p")
                local cmd_args = { "project", "init", "--board", board_id }

                runner.run_cmd_with_terminal("pio", cmd_args, { cwd = project_path }, function(cmd_ok)
                    if not cmd_ok then
                        vim.notify("Error al inicializar el proyecto con PlatformIO.", vim.log.levels.ERROR)
                        return
                    end

                    ini_manager.update_platformio_ini(ini_path, config)
                    generator.ensure_main_cpp(project_path, clean_value(config.baud, "baud"))
                    generator.generate_compile_commands(project_path)
                end)
            elseif mode == "edit" then
                ini_manager.update_platformio_ini(ini_path, config)
                runner.run_cmd_with_terminal("pio", { "pkg", "install" }, { cwd = project_path }, function(cmd_ok)
                    if cmd_ok then
                        generator.generate_compile_commands(project_path)
                    end
                end)
            end
        end)

        if not ok then
            log("FATAL", "Error en pcall: " .. tostring(err))
            vim.notify("Error crítico: " .. tostring(err), vim.log.levels.ERROR)
        end
    end)()
end

--------------------------------------------------------------------------------
-- REGISTRO DEL COMANDO USUARIO :Pio
--------------------------------------------------------------------------------
vim.api.nvim_create_user_command("Pio", function(opts)
    local path = (opts.args and opts.args ~= "") and opts.args or vim.fn.getcwd()
    M.manage_project(path)
end, {
    nargs = "?",
    complete = "dir",
    desc = "Crear o editar un proyecto PlatformIO",
})

return M
