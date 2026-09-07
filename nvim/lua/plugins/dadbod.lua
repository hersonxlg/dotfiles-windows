return {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
        { "tpope/vim-dadbod" },
        { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" } },
    },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection" },
    ft = { "sql", "mysql", "plsql" },
    init = function()
        vim.g.db_ui_use_nerd_fonts = 1
        vim.g.db_ui_auto_execute_table_helpers = 1
    end,
    config = function()
        local log_file = vim.fn.stdpath("cache") .. "/dadbod_debug.log"

        local function log(msg)
            local f = io.open(log_file, "a")
            if f then
                f:write(os.date("[%H:%M:%S] ") .. tostring(msg) .. "\n")
                f:close()
            end
        end

        -- Normalización segura de URLs para SQLite (Linux y Windows)
        local function fix_url(url)
            if type(url) ~= "string" or url:match("^%s*$") then
                return url
            end

            -- Reemplazar contrabarras de Windows por barras normales
            url = vim.trim(url):gsub("\\", "/")

            -- Si es otro motor de base de datos (Postgres, MySQL, etc.), no modificar
            if url:match("^[a-z0-9_]+:") and not url:match("^sqlite:") then
                return url
            end

            -- Extraer la ruta quitando el prefijo 'sqlite:' si existe
            local raw_path = url:gsub("^sqlite:", "")

            -- Comprobar si ya es una ruta absoluta (/home/... o C:/...)
            local is_absolute = raw_path:match("^/+") or raw_path:match("^[a-zA-Z]:")

            local clean_path = raw_path
            if not is_absolute then
                -- Solo convertir a absoluta si era una ruta relativa (ej. "a.db")
                clean_path = vim.fn.fnamemodify(raw_path, ":p"):gsub("\\", "/")
            end

            -- Limpiar barras iniciales para formatear sqlite:///
            clean_path = clean_path:gsub("^/+", "")

            return "sqlite:///" .. clean_path
        end

        local function set_buf_var(buf, name, value)
            vim.api.nvim_buf_set_var(buf, name, value)
        end

        local function get_buf_var(buf, name)
            local ok, val = pcall(vim.api.nvim_buf_get_var, buf, name)
            return ok and val or nil
        end

        local function save_connection(name, url)
            local save_loc = vim.g.db_ui_save_location or (vim.fn.stdpath("data") .. "/db_ui")
            save_loc = vim.fn.expand(save_loc)
            vim.fn.mkdir(save_loc, "p")
            local json_path = save_loc .. "/connections.json"

            local conns = {}
            if vim.fn.filereadable(json_path) == 1 then
                local content = table.concat(vim.fn.readfile(json_path), "\n")
                local ok, decoded = pcall(vim.json.decode, content)
                if ok and type(decoded) == "table" then
                    conns = decoded
                end
            end

            table.insert(conns, {
                name = name,
                url = url,
            })

            local ok, encoded = pcall(vim.json.encode, conns)
            if ok then
                vim.fn.writefile(vim.split(encoded, "\n"), json_path)
                log("Nueva conexión guardada: " .. name .. " -> " .. url)
                return true
            end
            return false
        end

        local function get_connections()
            local conns = {}
            local save_loc = vim.g.db_ui_save_location or (vim.fn.stdpath("data") .. "/db_ui")
            save_loc = vim.fn.expand(save_loc)
            local json_path = save_loc .. "/connections.json"

            if vim.fn.filereadable(json_path) == 1 then
                local content = table.concat(vim.fn.readfile(json_path), "\n")
                local ok, decoded = pcall(vim.json.decode, content)
                if ok and type(decoded) == "table" then
                    if #decoded > 0 then
                        for _, item in ipairs(decoded) do
                            if type(item) == "table" and item.name and (item.url or item.value) then
                                table.insert(conns, {
                                    name = tostring(item.name),
                                    url = fix_url(tostring(item.url or item.value)),
                                })
                            end
                        end
                    end
                end
            end

            return conns
        end

        local function setup_buffer(bufnr)
            local buf_name = vim.api.nvim_buf_get_name(bufnr)

            if vim.bo[bufnr].buftype ~= "" or buf_name:match("dbui") or vim.bo[bufnr].filetype == "dbui" then
                return
            end

            if get_buf_var(bufnr, "_dadbod_setup_running") then
                return
            end
            set_buf_var(bufnr, "_dadbod_setup_running", true)

            vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(bufnr) then
                    set_buf_var(bufnr, "_dadbod_setup_running", false)
                    return
                end

                local current_db = get_buf_var(bufnr, "db")
                if current_db and current_db ~= "" then
                    set_buf_var(bufnr, "_dadbod_setup_running", false)
                    return
                end

                local conns = get_connections()

                local OPT_NONE = "🚫 Ninguna conexión"
                local OPT_NEW = "➕ Crear nueva conexión..."

                local options = { OPT_NONE, OPT_NEW }
                local conn_map = {}

                for _, c in ipairs(conns) do
                    local label = c.name .. " (" .. c.url .. ")"
                    table.insert(options, label)
                    conn_map[label] = c
                end

                local sql_win = vim.api.nvim_get_current_win()

                vim.ui.select(options, {
                    prompt = "🔌 Selecciona la base de datos para este archivo SQL:",
                }, function(choice)
                    set_buf_var(bufnr, "_dadbod_setup_running", false)

                    if not choice or choice == OPT_NONE then
                        vim.notify("Buffer iniciado sin conexión.", vim.log.levels.INFO)
                        return
                    end

                    local function apply_connection(conn_name, conn_url)
                        set_buf_var(bufnr, "db", conn_url)
                        set_buf_var(bufnr, "db_name", conn_name)

                        vim.keymap.set("n", "<leader>r", "<cmd>%DB<CR>", { buffer = bufnr, desc = "Ejecutar SQL" })
                        vim.keymap.set(
                            "v",
                            "<leader>r",
                            ":DB<CR>",
                            { buffer = bufnr, desc = "Ejecutar selección SQL" }
                        )

                        if vim.api.nvim_win_is_valid(sql_win) then
                            vim.wo[sql_win].winbar = " 🔌 DB Activa: " .. conn_name
                        end

                        if vim.fn.bufwinnr("dbui") == -1 then
                            pcall(vim.cmd, "DBUI")
                        end

                        if vim.api.nvim_win_is_valid(sql_win) then
                            vim.api.nvim_set_current_win(sql_win)
                        end

                        vim.notify("🔌 Conectado a: " .. conn_name, vim.log.levels.INFO)
                    end

                    if choice == OPT_NEW then
                        vim.ui.input({ prompt = "Nombre de la nueva conexión: " }, function(name)
                            if not name or name:match("^%s*$") then
                                vim.notify("Creación cancelada.", vim.log.levels.WARN)
                                return
                            end

                            vim.ui.input({ prompt = "Ruta o URL (ej. a.db o sqlite:///ruta/a.db): " }, function(url)
                                if not url or url:match("^%s*$") then
                                    vim.notify("Creación cancelada.", vim.log.levels.WARN)
                                    return
                                end

                                local fixed_url = fix_url(url)
                                save_connection(name, fixed_url)
                                apply_connection(name, fixed_url)
                            end)
                        end)
                    elseif conn_map[choice] then
                        local selected = conn_map[choice]
                        apply_connection(selected.name, selected.url)
                    end
                end)
            end)
        end

        vim.api.nvim_create_autocmd("FileType", {
            pattern = { "sql", "mysql", "plsql" },
            callback = function(args)
                setup_buffer(args.buf)
            end,
        })

        local current_buf = vim.api.nvim_get_current_buf()
        local ft = vim.bo[current_buf].filetype
        if ft == "sql" or ft == "mysql" or ft == "plsql" then
            setup_buffer(current_buf)
        end
    end,
}
