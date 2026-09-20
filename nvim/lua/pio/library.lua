-- ============================================================================
-- BASE OFICIAL: PLATFORMIO HELPER TOOLS PARA NEOVIM
-- Componentes puros de interfaz para generación de cadenas de platformio.ini
-- ============================================================================

local M = {}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS & CACHE COMPARTIDOS
--------------------------------------------------------------------------------
local curl_bin = vim.fn.executable("curl.exe") == 1 and "curl.exe" or "curl"
local uri_encode = function(str)
    if vim.uri and vim.uri.encode then
        return vim.uri.encode(str)
    end
    if vim.uri_encode then
        return vim.uri_encode(str)
    end
    return (
        tostring(str):gsub("[^%w_%.%-~]", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
    )
end

local pkg_cache = {}

local function parse_list(tbl)
    if not tbl or type(tbl) ~= "table" or #tbl == 0 then
        return "Todos / Sin restricción"
    end
    local res = {}
    for _, elem in ipairs(tbl) do
        if type(elem) == "table" then
            table.insert(res, elem.name or elem.title or elem.id or "N/A")
        elseif type(elem) == "string" then
            table.insert(res, elem)
        end
    end
    return #res > 0 and table.concat(res, ", ") or "Todos / Sin restricción"
end

local function extract_repo_url(search_item, pkg_detail)
    local candidates = {}
    if pkg_detail then
        if type(pkg_detail.repository) == "table" then
            table.insert(candidates, pkg_detail.repository.url)
        elseif type(pkg_detail.repository) == "string" then
            table.insert(candidates, pkg_detail.repository)
        end
        table.insert(candidates, pkg_detail.repository_url)
        table.insert(candidates, pkg_detail.homepage)
    end
    if search_item then
        if type(search_item.repository) == "table" then
            table.insert(candidates, search_item.repository.url)
        elseif type(search_item.repository) == "string" then
            table.insert(candidates, search_item.repository)
        end
        table.insert(candidates, search_item.repository_url)
        table.insert(candidates, search_item.homepage)
    end

    for _, url in ipairs(candidates) do
        if type(url) == "string" and url:match("^https?://") then
            return url:gsub("^git%+", ""):gsub("^git://", "https://")
        end
    end
    return "No disponible en API"
end

local function fetch_package_details(selected_item, callback)
    local owner = "desconocido"
    if type(selected_item.owner) == "table" then
        owner = selected_item.owner.username or "desconocido"
    elseif type(selected_item.owner) == "string" then
        owner = selected_item.owner
    end

    local name = selected_item.name or "sin-nombre"
    local pkg_type = selected_item.type or "library"
    local key = owner .. "/" .. name

    if pkg_cache[key] then
        callback(pkg_cache[key])
        return
    end

    local pkg_url = string.format(
        "https://api.registry.platformio.org/v3/packages/%s/%s/%s",
        uri_encode(owner),
        uri_encode(pkg_type),
        uri_encode(name)
    )
    vim.system({ curl_bin, "-s", pkg_url }, { text = true }, function(pkg_out)
        vim.schedule(function()
            if pkg_out.code == 0 and pkg_out.stdout then
                local ok_pkg, pkg_data = pcall(vim.json.decode, pkg_out.stdout)
                if ok_pkg and pkg_data then
                    pkg_cache[key] = pkg_data
                    callback(pkg_data)
                    return
                end
            end
            callback(nil)
        end)
    end)
end

--------------------------------------------------------------------------------
-- 1. BUSCADOR Y SELECTOR DE LIBRERÍAS
--------------------------------------------------------------------------------
-- Helper de respaldo para codificación URI en entornos antiguos de Neovim
local function safe_uri_encode(str)
    if vim.uri_encode then
        return vim.uri_encode(str)
    end
    return (
        str:gsub("\n", "\r\n")
            :gsub("([^%w %-%_%.%~])", function(c)
                return string.format("%%%02X", string.byte(c))
            end)
            :gsub(" ", "%%20")
    )
end

--------------------------------------------------------------------------------
-- 1. BUSCADOR Y SELECTOR DE LIBRERÍAS (NAVEGACIÓN COMPLETA Y RE-BÚSQUEDA)
--------------------------------------------------------------------------------
function M.pio_wildcard_nvim12_search(installed_libs, on_select)
    local curl_bin_cmd = rawget(_G, "curl_bin") or "curl"
    local encode_fn = rawget(_G, "uri_encode")
        or function(str)
            return (
                str:gsub("\n", "\r\n")
                    :gsub("([^%w %-%_%.%~])", function(c)
                        return string.format("%%%02X", string.byte(c))
                    end)
                    :gsub(" ", "%%20")
            )
        end

    local cb = on_select
        or function(res)
            if res then
                vim.notify("Librería seleccionada: " .. res, vim.log.levels.INFO)
            else
                vim.notify("Búsqueda cancelada", vim.log.levels.WARN)
            end
        end

    local function parse_semver(v)
        local clean = tostring(v):gsub("^v", ""):gsub("[%^%~%s]", "")
        local maj, min, patch, extra = clean:match("^(%d+)%.?(%d*)%.?(%d*)(.-)$")
        maj = tonumber(maj) or 0
        min = tonumber(min) or 0
        patch = tonumber(patch) or 0
        local is_stable = (extra == "" or extra == nil) and 1 or 0
        return maj, min, patch, is_stable, extra or ""
    end

    local function semver_compare_desc(v1, v2)
        local maj1, min1, p1, stable1, ex1 = parse_semver(v1)
        local maj2, min2, p2, stable2, ex2 = parse_semver(v2)

        if maj1 ~= maj2 then
            return maj1 > maj2
        end
        if min1 ~= min2 then
            return min1 > min2
        end
        if p1 ~= p2 then
            return p1 > p2
        end
        if stable1 ~= stable2 then
            return stable1 > stable2
        end
        return ex1 > ex2
    end

    local installed_map = {}
    if type(installed_libs) == "table" then
        for k, v in pairs(installed_libs) do
            if type(k) == "string" and type(v) == "string" then
                installed_map[k:lower()] = v
            elseif type(v) == "string" then
                local full_name, ver = v:match("^([^@]+)@?(.*)$")
                if full_name then
                    installed_map[full_name:lower()] = (ver ~= "" and ver) or "instalada"
                end
            end
        end
    end

    local hl_palette = {
        { name = "PioMatch1", fg = "#E5C07B", bold = true },
        { name = "PioMatch2", fg = "#56B6C2", bold = true },
        { name = "PioMatch3", fg = "#98C379", bold = true },
        { name = "PioMatch4", fg = "#C678DD", bold = true },
        { name = "PioMatch5", fg = "#D19A66", bold = true },
    }

    for _, hl in ipairs(hl_palette) do
        vim.api.nvim_set_hl(0, hl.name, { fg = hl.fg, bold = hl.bold, default = true })
    end
    vim.api.nvim_set_hl(0, "PioMatchPerfect", { fg = "#98C379", bold = true, default = true })
    vim.api.nvim_set_hl(0, "PioMatchPartial", { fg = "#E5C07B", default = true })
    vim.api.nvim_set_hl(0, "PioBullet", { fg = "#61AFEF", default = true })
    vim.api.nvim_set_hl(0, "PioInstalled", { fg = "#98C379", bold = true, default = true })

    local function fetch_direct_versions(owner, name, callback)
        if owner == "" or name == "" then
            callback({})
            return
        end
        local url = string.format(
            "https://api.registry.platformio.org/v3/packages/%s/library/%s",
            encode_fn(owner),
            encode_fn(name)
        )
        vim.system({ curl_bin_cmd, "-s", url }, { text = true }, function(out)
            vim.schedule(function()
                local v_list = {}
                if out.code == 0 and out.stdout then
                    local ok, parsed = pcall(vim.json.decode, out.stdout)
                    if ok and parsed and type(parsed.versions) == "table" then
                        for _, v in ipairs(parsed.versions) do
                            local vname = (type(v) == "table" and v.name) or tostring(v)
                            table.insert(v_list, vname)
                        end
                    end
                end
                callback(v_list)
            end)
        end)
    end

    local function fetch_all_versions(item, callback)
        local owner = (type(item.owner) == "table" and item.owner.username) or item.owner or ""
        local name = item.name or ""

        local fetch_fn = rawget(_G, "fetch_package_details") or M.fetch_package_details
        if type(fetch_fn) == "function" then
            fetch_fn(item, function(pkg_detail)
                if pkg_detail and type(pkg_detail.versions) == "table" and #pkg_detail.versions > 0 then
                    local v_list = {}
                    for _, v in ipairs(pkg_detail.versions) do
                        local vname = (type(v) == "table" and v.name) or tostring(v)
                        table.insert(v_list, vname)
                    end
                    callback(v_list)
                else
                    fetch_direct_versions(owner, name, callback)
                end
            end)
        else
            fetch_direct_versions(owner, name, callback)
        end
    end

    -- Función principal de búsqueda re-ejecutable
    local function start_search_flow()
        vim.ui.input({ prompt = "Buscador PIO: " }, function(query)
            if not query or query:match("^%s*$") then
                cb(nil)
                return
            end

            local tokens = {}
            for token in query:gmatch("%S+") do
                table.insert(tokens, token:lower())
            end
            local total_tokens = #tokens
            if total_tokens == 0 then
                cb(nil)
                return
            end

            local search_terms = {}
            if total_tokens == 1 then
                table.insert(search_terms, "*" .. tokens[1] .. "*")
                table.insert(search_terms, tokens[1] .. "*")
            elseif total_tokens == 2 then
                table.insert(search_terms, string.format("*%s*%s*", tokens[1], tokens[2]))
                table.insert(search_terms, string.format("*%s*%s*", tokens[2], tokens[1]))
                table.insert(search_terms, string.format("*%s* *%s*", tokens[1], tokens[2]))
            else
                table.insert(search_terms, "*" .. table.concat(tokens, "*") .. "*")
                table.insert(search_terms, "*" .. table.concat(tokens, "* *") .. "*")
            end

            local raw_items = {}
            local seen_ids = {}
            local pending = #search_terms

            vim.notify(string.format("Buscando patrones PIO: %s", query), vim.log.levels.INFO)

            for _, term in ipairs(search_terms) do
                local url =
                    string.format("https://api.registry.platformio.org/v3/search?query=%s&limit=50", encode_fn(term))

                vim.system({ curl_bin_cmd, "-s", url }, { text = true }, function(out)
                    vim.schedule(function()
                        if out.code == 0 and out.stdout then
                            local ok, parsed = pcall(vim.json.decode, out.stdout)
                            if ok and parsed and parsed.items then
                                for _, item in ipairs(parsed.items) do
                                    if item.id and not seen_ids[item.id] then
                                        seen_ids[item.id] = true
                                        table.insert(raw_items, item)
                                    end
                                end
                            end
                        end

                        pending = pending - 1
                        if pending == 0 then
                            local scored_results = {}
                            for _, item in ipairs(raw_items) do
                                local owner = (type(item.owner) == "table" and item.owner.username)
                                    or item.owner
                                    or "desconocido"
                                local name = item.name or "sin-nombre"
                                local full_name = owner .. "/" .. name

                                local score = 0
                                local fn_lower = full_name:lower()
                                for _, token in ipairs(tokens) do
                                    if fn_lower:find(token, 1, true) then
                                        score = score + 1
                                    end
                                end

                                if score > 0 then
                                    table.insert(scored_results, {
                                        full_name = full_name,
                                        score = score,
                                        is_perfect = (score == total_tokens),
                                        item = item,
                                        is_installed = installed_map[full_name:lower()] ~= nil,
                                        installed_ver = installed_map[full_name:lower()],
                                    })
                                end
                            end

                            table.sort(scored_results, function(a, b)
                                if a.score ~= b.score then
                                    return a.score > b.score
                                end
                                return a.full_name < b.full_name
                            end)

                            if #scored_results == 0 then
                                vim.notify("Sin coincidencias para: " .. query, vim.log.levels.WARN)
                                start_search_flow() -- Reintenta si no hubo resultados
                                return
                            end

                            local display_lines = {
                                string.format("  Resultados para: '%s' (%d encontradas)", query, #scored_results),
                                string.rep("─", 56),
                            }

                            for _, res in ipairs(scored_results) do
                                local tag = res.is_perfect and " [100%]"
                                    or string.format(" [%d/%d]", res.score, total_tokens)
                                local inst_tag = res.is_installed and " ✔ [Instalada]" or ""
                                table.insert(
                                    display_lines,
                                    string.format(" • %-36s %s%s", res.full_name, tag, inst_tag)
                                )
                            end

                            local buf = vim.api.nvim_create_buf(false, true)
                            vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
                            vim.bo[buf].filetype = "markdown"
                            vim.bo[buf].bufhidden = "hide"

                            local width = math.floor(vim.o.columns * 0.65)
                            local height = math.min(#display_lines + 2, math.floor(vim.o.lines * 0.75))
                            local title_main = " PIO Search - <CR>/l Versiones | h Nueva Búsqueda | i Info "

                            local win = vim.api.nvim_open_win(buf, true, {
                                relative = "editor",
                                width = width,
                                height = height,
                                row = math.floor((vim.o.lines - height) / 2),
                                col = math.floor((vim.o.columns - width) / 2),
                                style = "minimal",
                                border = "rounded",
                                title = title_main,
                                title_pos = "center",
                            })

                            vim.wo[win].cursorline = true
                            vim.wo[win].cursorlineopt = "both"
                            pcall(vim.api.nvim_win_set_cursor, win, { 3, 0 })

                            local closed = false
                            local is_researching = false

                            local function finish(selection)
                                if closed or is_researching then
                                    return
                                end
                                closed = true
                                if vim.api.nvim_win_is_valid(win) then
                                    vim.api.nvim_win_close(win, true)
                                end
                                if vim.api.nvim_buf_is_valid(buf) then
                                    vim.api.nvim_buf_delete(buf, { force = true })
                                end
                                cb(selection)
                            end

                            local function re_trigger_search()
                                is_researching = true
                                if vim.api.nvim_win_is_valid(win) then
                                    vim.api.nvim_win_close(win, true)
                                end
                                if vim.api.nvim_buf_is_valid(buf) then
                                    vim.api.nvim_buf_delete(buf, { force = true })
                                end
                                start_search_flow()
                            end

                            local group = vim.api.nvim_create_augroup("PioSearchWipe_" .. buf, { clear = true })
                            vim.api.nvim_create_autocmd("BufWipeout", {
                                group = group,
                                buffer = buf,
                                once = true,
                                callback = function()
                                    finish(nil)
                                end,
                            })

                            local ns_id = vim.api.nvim_create_namespace("pio_search_hl")
                            local prefix_bytes = string.len(" • ")

                            for idx, res in ipairs(scored_results) do
                                local line_idx = idx + 1
                                local full_name_lower = res.full_name:lower()

                                vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, 1, {
                                    end_col = 4,
                                    hl_group = "PioBullet",
                                })

                                for token_idx, token in ipairs(tokens) do
                                    local hl_group = hl_palette[((token_idx - 1) % #hl_palette) + 1].name
                                    local s, e = 0, 0
                                    while true do
                                        s, e = full_name_lower:find(token, e + 1, true)
                                        if not s then
                                            break
                                        end
                                        vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, prefix_bytes + (s - 1), {
                                            end_col = prefix_bytes + e,
                                            hl_group = hl_group,
                                        })
                                    end
                                end

                                if res.is_installed then
                                    local line_str = display_lines[line_idx + 1]
                                    local inst_s, inst_e = line_str:find("✔ %[[^%]]+%]")
                                    if inst_s then
                                        vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, inst_s - 1, {
                                            end_col = inst_e,
                                            hl_group = "PioInstalled",
                                        })
                                    end
                                end
                            end

                            local function open_details(res)
                                local details_fn = rawget(_G, "fetch_package_details") or M.show_library_details
                                if details_fn then
                                    details_fn(res.item, win, buf)
                                else
                                    vim.notify("Detalles de paquete no disponibles", vim.log.levels.INFO)
                                end
                            end

                            local function open_version_selector(res)
                                fetch_all_versions(res.item, function(versions_list)
                                    if #versions_list == 0 then
                                        local fallback_ver = (
                                            type(res.item.version) == "table" and res.item.version.name
                                        )
                                            or res.item.version
                                            or "1.0.0"
                                        table.insert(versions_list, fallback_ver)
                                    end

                                    table.sort(versions_list, semver_compare_desc)

                                    local ver_lines = {
                                        string.format("  Versiones disponibles para: %s", res.full_name),
                                        string.rep("─", 56),
                                    }

                                    local current_installed = res.installed_ver
                                    local clean_installed = current_installed and current_installed:gsub("[%^%~%s]", "")
                                    local target_line = 3

                                    for v_idx, ver in ipairs(versions_list) do
                                        local clean_ver = ver:gsub("[%^%~%s]", "")
                                        local is_this_installed = current_installed
                                            and (
                                                clean_installed == clean_ver
                                                or current_installed == ver
                                                or current_installed == "^" .. ver
                                            )

                                        local tags = {}
                                        if v_idx == 1 then
                                            table.insert(tags, "[Última]")
                                        end
                                        if is_this_installed then
                                            table.insert(tags, "✔ [Instalada actualmente]")
                                            target_line = v_idx + 2
                                        end

                                        local tag_str = #tags > 0 and ("  " .. table.concat(tags, " ")) or ""
                                        table.insert(ver_lines, string.format(" • %-15s %s", ver, tag_str))
                                    end

                                    local ver_buf = vim.api.nvim_create_buf(false, true)
                                    vim.bo[ver_buf].filetype = "markdown"
                                    vim.bo[ver_buf].bufhidden = "wipe"
                                    vim.api.nvim_buf_set_lines(ver_buf, 0, -1, false, ver_lines)

                                    local ver_ns = vim.api.nvim_create_namespace("pio_ver_hl")
                                    for v_idx, ver in ipairs(versions_list) do
                                        local line_idx = v_idx + 1
                                        local line_str = ver_lines[line_idx + 1]

                                        vim.api.nvim_buf_set_extmark(ver_buf, ver_ns, line_idx, 1, {
                                            end_col = 4,
                                            hl_group = "PioBullet",
                                        })

                                        local ult_s, ult_e = line_str:find("%[Última%]")
                                        if ult_s then
                                            vim.api.nvim_buf_set_extmark(ver_buf, ver_ns, line_idx, ult_s - 1, {
                                                end_col = ult_e,
                                                hl_group = "PioMatch1",
                                            })
                                        end

                                        local inst_s, inst_e = line_str:find("✔ %[[^%]]+%]")
                                        if inst_s then
                                            vim.api.nvim_buf_set_extmark(ver_buf, ver_ns, line_idx, inst_s - 1, {
                                                end_col = inst_e,
                                                hl_group = "PioInstalled",
                                            })
                                        end
                                    end

                                    if vim.api.nvim_win_is_valid(win) then
                                        vim.api.nvim_win_set_config(win, {
                                            title = " Versiones - <CR>/l Seleccionar | h/BS Volver ",
                                            title_pos = "center",
                                        })
                                        vim.wo[win].wrap = false
                                        vim.api.nvim_win_set_buf(win, ver_buf)

                                        vim.wo[win].cursorline = true
                                        vim.wo[win].cursorlineopt = "both"

                                        pcall(
                                            vim.api.nvim_win_set_cursor,
                                            win,
                                            { math.min(target_line, #ver_lines), 0 }
                                        )
                                    end

                                    local map_opts = { buffer = ver_buf, silent = true, noremap = true, nowait = true }

                                    local function select_current_version()
                                        local cursor = vim.api.nvim_win_get_cursor(win)
                                        local v_idx = cursor[1] - 2
                                        if v_idx < 1 then
                                            v_idx = 1
                                        end
                                        if v_idx > #versions_list then
                                            v_idx = #versions_list
                                        end
                                        finish(string.format("%s@^%s", res.full_name, versions_list[v_idx]))
                                    end

                                    local function go_back()
                                        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf) then
                                            vim.api.nvim_win_set_config(
                                                win,
                                                { title = title_main, title_pos = "center" }
                                            )
                                            vim.wo[win].wrap = false
                                            vim.api.nvim_win_set_buf(win, buf)
                                            vim.wo[win].cursorline = true
                                            vim.wo[win].cursorlineopt = "both"
                                        end
                                    end

                                    -- Mapeos en panel de versiones
                                    vim.keymap.set("n", "<CR>", select_current_version, map_opts)
                                    vim.keymap.set("n", "l", select_current_version, map_opts)
                                    vim.keymap.set("n", "<BS>", go_back, map_opts)
                                    vim.keymap.set("n", "b", go_back, map_opts)
                                    vim.keymap.set("n", "h", go_back, map_opts)
                                    vim.keymap.set("n", "i", function()
                                        open_details(res)
                                    end, map_opts)
                                    vim.keymap.set("n", "K", function()
                                        open_details(res)
                                    end, map_opts)
                                    vim.keymap.set("n", "q", function()
                                        finish(nil)
                                    end, map_opts)
                                    vim.keymap.set("n", "<Esc>", function()
                                        finish(nil)
                                    end, map_opts)
                                end)
                            end

                            local list_opts = { buffer = buf, silent = true, noremap = true, nowait = true }

                            local function enter_version_view()
                                local cursor = vim.api.nvim_win_get_cursor(win)
                                local res_idx = cursor[1] - 2
                                if res_idx >= 1 and res_idx <= #scored_results then
                                    open_version_selector(scored_results[res_idx])
                                end
                            end

                            local function view_details()
                                local cursor = vim.api.nvim_win_get_cursor(win)
                                local res_idx = cursor[1] - 2
                                if res_idx >= 1 and res_idx <= #scored_results then
                                    open_details(scored_results[res_idx])
                                end
                            end

                            -- Mapeos principales en lista de resultados
                            vim.keymap.set("n", "<CR>", enter_version_view, list_opts)
                            vim.keymap.set("n", "l", enter_version_view, list_opts)
                            vim.keymap.set("n", "i", view_details, list_opts)
                            vim.keymap.set("n", "K", view_details, list_opts)

                            -- Retroceder en la lista principal te lleva a un nuevo prompt de búsqueda
                            vim.keymap.set("n", "h", re_trigger_search, list_opts)
                            vim.keymap.set("n", "<BS>", re_trigger_search, list_opts)
                            vim.keymap.set("n", "b", re_trigger_search, list_opts)

                            -- Salida limpia con cancelación
                            vim.keymap.set("n", "q", function()
                                finish(nil)
                            end, list_opts)
                            vim.keymap.set("n", "<Esc>", function()
                                finish(nil)
                            end, list_opts)
                        end
                    end)
                end)
            end
        end)
    end

    start_search_flow()
end

--------------------------------------------------------------------------------
-- 2. SELECTOR DE PUERTOS SERIE (TIEMPO REAL CON NAVEGACIÓN DE FLUKO)
--------------------------------------------------------------------------------
function M.pio_select_serial_port(default_port, on_select)
    default_port = (type(default_port) == "string" and default_port:gsub("^[%w_]+%s*=%s*", ""):gsub("%s+", ""):lower())
        or ""
    if default_port == "auto" then
        default_port = ""
    end

    on_select = on_select
        or function(res)
            vim.notify("Acción: " .. res.action .. " | Puerto: " .. tostring(res.port), vim.log.levels.INFO)
        end

    vim.api.nvim_set_hl(0, "PioPortBullet", { fg = "#61AFEF", bold = true })
    vim.api.nvim_set_hl(0, "PioPortAuto", { fg = "#C678DD", bold = true })
    vim.api.nvim_set_hl(0, "PioPortInstalled", { fg = "#98C379", bold = true })
    vim.api.nvim_set_hl(0, "PioPortNew", { fg = "#E5C07B", bold = true })

    local is_win = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
    local known_ports_set = {}
    local new_ports_set = {}
    local is_first_scan = true
    local finished = false

    local function scan_ports(callback)
        local found_ports = {}
        if not is_win then
            local handle = vim.uv.fs_scandir("/dev")
            if handle then
                while true do
                    local name = vim.uv.fs_scandir_next(handle)
                    if not name then
                        break
                    end
                    if name:match("^ttyUSB%d+$") or name:match("^ttyACM%d+$") or name:match("^ttyS%d+$") then
                        table.insert(found_ports, "/dev/" .. name)
                    end
                end
            end
            table.sort(found_ports)
            callback(found_ports)
        else
            vim.system({ "reg", "query", "HKLM\\HARDWARE\\DEVICEMAP\\SERIALCOMM" }, { text = true }, function(out)
                if out.code == 0 and out.stdout then
                    for line in out.stdout:gmatch("[^\r\n]+") do
                        local port = line:match("REG_SZ%s+(COM%d+)")
                        if port then
                            table.insert(found_ports, port)
                        end
                    end
                end
                table.sort(found_ports, function(a, b)
                    local na = tonumber(a:match("%d+")) or 0
                    local nb = tonumber(b:match("%d+")) or 0
                    return na < nb
                end)
                vim.schedule(function()
                    callback(found_ports)
                end)
            end)
        end
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].bufhidden = "wipe"

    local width = math.floor(vim.o.columns * 0.60)
    local height = 10
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
        title = " Selector de Puertos Serie (Tiempo Real) ",
        title_pos = "center",
    })

    vim.wo[win].cursorline = true
    vim.wo[win].cursorlineopt = "both"

    local timer = vim.uv.new_timer()

    local function close_and_finish(action, raw_port)
        if finished then
            return
        end
        finished = true

        if timer then
            timer:stop()
            if not timer:is_closing() then
                timer:close()
            end
            timer = nil
        end
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end

        local response = {
            action = action or "cancel",
            value = nil,
            port = nil,
        }

        if action == "next" then
            if raw_port and raw_port ~= "" then
                response.value = "upload_port = " .. raw_port
                response.port = raw_port
            else
                response.value = ""
                response.port = "auto"
            end
        end

        on_select(response)
    end

    local function render(current_ports)
        if not vim.api.nvim_buf_is_valid(buf) then
            return
        end

        local is_auto_default = (default_port == "")
        local lines = {
            "  Escaneando puertos serie del sistema en tiempo real...",
            string.rep("─", width - 4),
            string.format(
                " ⚡ Auto-detectar (Predeterminado de PIO)%s",
                is_auto_default and "  ✔ [Seleccionado]" or ""
            ),
            " ────────── Puertos Físicos Detectados ──────────",
        }

        local newly_connected_port = nil
        local port_line_map = {}

        if #current_ports == 0 then
            table.insert(lines, " (No se detectaron dispositivos conectados)")
        else
            for _, port in ipairs(current_ports) do
                local line_num = #lines + 1
                port_line_map[line_num] = port

                if not is_first_scan and not known_ports_set[port] then
                    newly_connected_port = port
                    new_ports_set[port] = true
                end

                local is_default = (default_port == port:lower())
                local is_new = new_ports_set[port]

                local tag = ""
                if is_default then
                    tag = "  ✔ [Seleccionado actualmente]"
                elseif is_new then
                    tag = "  ✨ [Nuevo dispositivo]"
                end

                table.insert(lines, string.format(" • %-25s %s", port, tag))
            end
        end

        local next_known = {}
        for _, p in ipairs(current_ports) do
            next_known[p] = true
        end
        known_ports_set = next_known

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        local ns_id = vim.api.nvim_create_namespace("pio_port_hl")
        vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

        vim.api.nvim_buf_set_extmark(buf, ns_id, 2, 0, {
            end_col = string.len(" ⚡ Auto-detectar"),
            hl_group = "PioPortAuto",
        })

        for l_idx, port in pairs(port_line_map) do
            local line_str = lines[l_idx]

            vim.api.nvim_buf_set_extmark(buf, ns_id, l_idx - 1, 1, {
                end_col = 4,
                hl_group = "PioPortBullet",
            })

            if default_port == port:lower() then
                local tag_s = line_str:find("✔")
                if tag_s then
                    vim.api.nvim_buf_set_extmark(buf, ns_id, l_idx - 1, tag_s - 1, {
                        end_col = string.len(line_str),
                        hl_group = "PioPortInstalled",
                    })
                end
            end

            if new_ports_set[port] then
                local tag_s = line_str:find("✨")
                if tag_s then
                    vim.api.nvim_buf_set_extmark(buf, ns_id, l_idx - 1, tag_s - 1, {
                        end_col = string.len(line_str),
                        hl_group = "PioPortNew",
                    })
                end
            end
        end

        if newly_connected_port then
            for line_num, port in pairs(port_line_map) do
                if port == newly_connected_port then
                    vim.api.nvim_win_set_cursor(win, { line_num, 0 })
                    vim.notify("🔌 Nuevo dispositivo detectado: " .. newly_connected_port, vim.log.levels.INFO)
                    break
                end
            end
        elseif is_first_scan then
            local cursor_set = false
            for line_num, port in pairs(port_line_map) do
                if default_port == port:lower() then
                    vim.api.nvim_win_set_cursor(win, { line_num, 0 })
                    cursor_set = true
                    break
                end
            end
            if not cursor_set then
                vim.api.nvim_win_set_cursor(win, { 3, 0 })
            end
        end

        is_first_scan = false
    end

    scan_ports(function(initial_ports)
        render(initial_ports)
        timer:start(
            1000,
            1000,
            vim.schedule_wrap(function()
                if not vim.api.nvim_win_is_valid(win) then
                    return
                end
                scan_ports(function(updated_ports)
                    render(updated_ports)
                end)
            end)
        )
    end)

    local opts = { buffer = buf, silent = true, noremap = true, nowait = true }

    local function select_current_port()
        local cursor = vim.api.nvim_win_get_cursor(win)
        local line_num = cursor[1]
        local current_line = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1] or ""

        if line_num == 3 then
            close_and_finish("next", "")
        elseif current_line:match("^ • ") then
            local selected_port = current_line:match("^ • (%S+)")
            if selected_port then
                close_and_finish("next", selected_port)
            end
        end
    end

    -- Confirmar y avanzar (next)
    vim.keymap.set("n", "<CR>", select_current_port, opts)
    vim.keymap.set("n", "l", select_current_port, opts)

    -- Retroceder en el flujo (prev)
    vim.keymap.set("n", "h", function()
        close_and_finish("prev")
    end, opts)
    vim.keymap.set("n", "b", function()
        close_and_finish("prev")
    end, opts)
    vim.keymap.set("n", "<BS>", function()
        close_and_finish("prev")
    end, opts)

    -- Cancelar todo el proceso (cancel)
    vim.keymap.set("n", "q", function()
        close_and_finish("cancel")
    end, opts)
    vim.keymap.set("n", "<Esc>", function()
        close_and_finish("cancel")
    end, opts)

    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = buf,
        once = true,
        callback = function()
            close_and_finish("cancel")
        end,
    })
end

--------------------------------------------------------------------------------
-- 3. SELECTOR DE PLACAS PLATFORMIO (SNACKS.PICKER + CACHÉ ESTÁTICA)
--------------------------------------------------------------------------------
local CACHE_FILE = vim.fn.stdpath("cache") .. "/pio_boards_cache.json"
local BOARDS_CACHE = nil

local FALLBACK_BOARDS = {
    {
        id = "esp32dev",
        name = "Espressif ESP32 Dev Module",
        mcu = "ESP32",
        platform = "espressif32",
        vendor = "Espressif",
        fcpu = "240MHz",
        ram = "320KB",
        flash = "4MB",
    },
    {
        id = "uno",
        name = "Arduino Uno",
        mcu = "ATmega328P",
        platform = "atmelavr",
        vendor = "Arduino",
        fcpu = "16MHz",
        ram = "2KB",
        flash = "32KB",
    },
    {
        id = "pico",
        name = "Raspberry Pi Pico",
        mcu = "RP2040",
        platform = "raspberrypi",
        vendor = "Raspberry Pi",
        fcpu = "133MHz",
        ram = "264KB",
        flash = "2MB",
    },
}

local DEFAULT_PREFERRED = { "esp32dev", "uno", "pico", "nodemcuv2" }

local function format_bytes(bytes)
    if type(bytes) ~= "number" then
        return tostring(bytes or "N/A")
    end
    if bytes >= 1024 * 1024 then
        return string.format("%.0fMB", bytes / (1024 * 1024))
    elseif bytes >= 1024 then
        return string.format("%.0fKB", bytes / 1024)
    end
    return tostring(bytes) .. " B"
end

local function format_hz(hz)
    if type(hz) ~= "number" then
        return tostring(hz or "N/A")
    end
    if hz >= 1000000 then
        return string.format("%.0fMHz", hz / 1000000)
    elseif hz >= 1000 then
        return string.format("%.0fkHz", hz / 1000)
    end
    return tostring(hz) .. " Hz"
end

local function load_disk_cache()
    if vim.fn.filereadable(CACHE_FILE) == 1 then
        local lines = vim.fn.readfile(CACHE_FILE)
        local content = table.concat(lines, "\n")
        local ok, parsed = pcall(vim.json.decode, content)
        if ok and type(parsed) == "table" and #parsed > 0 then
            return parsed
        end
    end
    return nil
end

local function save_disk_cache(data)
    local ok, encoded = pcall(vim.json.encode, data)
    if ok and encoded then
        vim.fn.writefile({ encoded }, CACHE_FILE)
    end
end

local function prepare_board_items(raw_list, default_board, preferred_boards)
    preferred_boards = preferred_boards or DEFAULT_PREFERRED

    local pref_map = {}
    for idx, board_id in ipairs(preferred_boards) do
        pref_map[board_id:lower()] = idx
    end

    local items = {}

    for _, b in ipairs(raw_list) do
        local id = b.id or b.name or "desconocido"
        local id_lower = id:lower()
        local name = b.name or b.title or id
        local is_def = (default_board ~= "" and id_lower == default_board)
        local pref_rank = pref_map[id_lower]

        local item = {
            id = id,
            name = name,
            mcu = b.mcu or "N/A",
            platform = b.platform or "N/A",
            frameworks = b.frameworks or {}, -- 👈 Lista de frameworks (ej: {"arduino", "espidf"})
            vendor = b.vendor or "N/A",
            fcpu = format_hz(b.fcpu),
            ram = format_bytes(b.ram),
            flash = format_bytes(b.flash),
            is_default = is_def,
            is_preferred = (pref_rank ~= nil),
            pref_rank = pref_rank or 999999,
            text = string.format("%s %s %s %s", id, name, b.mcu or "", b.platform or ""),
        }
        table.insert(items, item)
    end

    table.sort(items, function(a, b)
        if a.is_default ~= b.is_default then
            return a.is_default
        end
        if a.is_preferred ~= b.is_preferred then
            return a.is_preferred
        end
        if a.is_preferred and b.is_preferred then
            return a.pref_rank < b.pref_rank
        end
        return a.id < b.id
    end)

    return items
end

function M.pio_select_board_snacks(default_board, preferred_boards, on_select)
    if type(preferred_boards) == "function" then
        on_select = preferred_boards
        preferred_boards = nil
    end

    on_select = on_select
        or function(res)
            vim.notify("Acción: " .. res.action .. " | Placa: " .. tostring(res.board), vim.log.levels.INFO)
        end

    local snacks_ok, snacks = pcall(require, "snacks")
    if not snacks_ok or not snacks.picker then
        vim.notify("`snacks.nvim` no está instalado o cargado", vim.log.levels.ERROR)
        on_select({ action = "cancel", value = nil, board = nil, item = nil })
        return
    end

    default_board = (
        type(default_board) == "string" and default_board:gsub("^board%s*=%s*", ""):gsub("%s+", ""):lower()
    ) or ""
    BOARDS_CACHE = BOARDS_CACHE or load_disk_cache()

    local handled_action = false

    local picker = snacks.picker.pick({
        source = "pio_boards",
        prompt = "⚡ Placas PlatformIO ",
        focus = "list",

        finder = function()
            local raw = BOARDS_CACHE or FALLBACK_BOARDS
            return prepare_board_items(raw, default_board, preferred_boards)
        end,

        -- Registro de la acción personalizada
        actions = {
            go_prev = function(p)
                handled_action = true
                p:close()
                on_select({
                    action = "prev",
                    value = default_board ~= "" and ("board = " .. default_board) or nil,
                    board = default_board ~= "" and default_board or nil,
                    item = nil,
                })
            end,
        },

        -- Mapeos vinculados directamente a la ventana activa (list e input)
        win = {
            input = {
                keys = {
                    ["l"] = { "confirm", mode = { "n" } },
                    ["h"] = { "go_prev", mode = { "n" } },
                },
            },
            list = {
                keys = {
                    ["l"] = "confirm",
                    ["h"] = "go_prev",
                },
            },
        },

        layout = {
            layout = {
                box = "vertical",
                width = 0.85,
                height = 0.85,
                { win = "input", height = 1, border = "rounded" },
                { win = "list", border = "rounded" },
                { win = "preview", height = 0.40, border = "rounded" },
            },
        },

        format = function(item)
            local tag = ""
            local id_hl = "DiagnosticInfo"

            if item.is_default then
                tag = " ✔ [Actual]"
                id_hl = "String"
            elseif item.is_preferred then
                tag = " ⭐ [Frecuente]"
                id_hl = "WarningMsg"
            end

            return {
                { string.format("%-36s", item.id), id_hl },
                { " │ " },
                { string.format("%-45s", item.name:sub(1, 45)), "Comment" },
                { tag, item.is_default and "String" or "Special" },
            }
        end,

        preview = function(ctx)
            local item = ctx.item
            if not item then
                return
            end

            local badge = item.is_preferred and " ⭐ *(Placa Frecuente)*" or ""

            local lines = {
                "# " .. item.name .. badge,
                "",
                "> **ID Oficial (board):** `" .. item.id .. "`",
                "",
                "## 🛠️ Configuración platformio.ini",
                "```ini",
                "[env]",
                "board = " .. item.id,
                "platform = " .. item.platform,
                "```",
                "",
                "## ⚙️ Especificaciones de Hardware",
                "- **MCU:** " .. tostring(item.mcu) .. "  |  **Plataforma:** " .. tostring(item.platform),
                "- **Fabricante:** " .. tostring(item.vendor) .. "  |  **Reloj:** " .. tostring(item.fcpu),
                "- **Memoria RAM:** " .. tostring(item.ram) .. "  |  **Memoria Flash:** " .. tostring(item.flash),
            }

            -- Se habilita escritura temporal en el buffer de vista previa
            vim.bo[ctx.buf].modifiable = true
            vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
            vim.bo[ctx.buf].modifiable = false
            vim.bo[ctx.buf].filetype = "markdown"
        end,

        confirm = function(p, item)
            handled_action = true
            p:close()
            if item then
                on_select({
                    action = "next",
                    value = "board = " .. item.id,
                    board = item.id,
                    item = item,
                })
            else
                on_select({
                    action = "cancel",
                    value = nil,
                    board = nil,
                    item = nil,
                })
            end
        end,

        on_close = function()
            if not handled_action then
                handled_action = true
                on_select({
                    action = "cancel",
                    value = nil,
                    board = nil,
                    item = nil,
                })
            end
        end,
    })

    if not BOARDS_CACHE then
        vim.notify("⏳ Descargando catálogo global por primera vez...", vim.log.levels.INFO)
        if vim.fn.executable("pio") == 1 then
            vim.system({ "pio", "boards", "--json-output" }, { text = true }, function(out)
                if out.code == 0 and out.stdout then
                    local ok, parsed = pcall(vim.json.decode, out.stdout)
                    if ok and type(parsed) == "table" and #parsed > 0 then
                        vim.schedule(function()
                            BOARDS_CACHE = parsed
                            save_disk_cache(parsed)
                            vim.notify(
                                string.format("✅ Catálogo global guardado (%d placas).", #parsed),
                                vim.log.levels.INFO
                            )
                            if picker and not picker.closed then
                                picker:find()
                            end
                        end)
                    end
                end
            end)
        end
    end
end

--------------------------------------------------------------------------------
-- 4. SELECTOR DE VELOCIDAD SERIAL / MONITOR SPEED (SNACKS.PICKER)
--------------------------------------------------------------------------------
local DEFAULT_BAUD_RATES = {
    { rate = "115200", desc = "Estándar recomendado (ESP32, ESP8266, STM32)" },
    { rate = "9600", desc = "Estándar clásico (Arduino Uno, Nano, Mega)" },
    { rate = "57600", desc = "Común en transmisiones RF y bootloaders AVR" },
    { rate = "19200", desc = "Uso general / Comunicaciones industriales" },
    { rate = "38400", desc = "Módulos Bluetooth HC-05 / Módulos GPS" },
    { rate = "74880", desc = "Velocidad Bootloader ESP8266 (Logs de arranque)" },
    { rate = "230400", desc = "Alta velocidad (Transferencias rápidas)" },
    { rate = "460800", desc = "Muy alta velocidad (ESP32 Flash/Debug)" },
    { rate = "921600", desc = "Máxima velocidad estándar (Monitoreo pesado)" },
    { rate = "1500000", desc = "Alta velocidad dedicada (1.5 Mbps)" },
    { rate = "2000000", desc = "Alta velocidad dedicada (2.0 Mbps)" },
}

function M.pio_select_baud_rate(default_speed, custom_speeds, on_select)
    if type(custom_speeds) == "function" then
        on_select = custom_speeds
        custom_speeds = nil
    end

    on_select = on_select
        or function(res)
            vim.notify("Acción: " .. res.action .. " | Velocidad: " .. tostring(res.rate), vim.log.levels.INFO)
        end

    local snacks_ok, snacks = pcall(require, "snacks")
    if not snacks_ok or not snacks.picker then
        vim.notify("`snacks.nvim` no está instalado o cargado", vim.log.levels.ERROR)
        on_select({ action = "cancel", value = nil, rate = nil, item = nil })
        return
    end

    local raw_speed = tostring(default_speed or "115200")
    default_speed = raw_speed:gsub("^[%w_]+%s*=%s*", ""):gsub("%s+", "")

    local rate_list = DEFAULT_BAUD_RATES
    if type(custom_speeds) == "table" and #custom_speeds > 0 then
        rate_list = {}
        for _, entry in ipairs(custom_speeds) do
            if type(entry) == "table" then
                table.insert(
                    rate_list,
                    { rate = tostring(entry.rate or entry[1]), desc = entry.desc or entry[2] or "Personalizado" }
                )
            else
                table.insert(rate_list, { rate = tostring(entry), desc = "Personalizado" })
            end
        end
    end

    local items = {}
    local found_default = false

    for _, item in ipairs(rate_list) do
        local is_def = (item.rate == default_speed)
        if is_def then
            found_default = true
        end
        table.insert(items, {
            rate = item.rate,
            desc = item.desc,
            is_default = is_def,
            text = string.format("%s baud %s", item.rate, item.desc),
        })
    end

    if not found_default and default_speed ~= "" then
        table.insert(items, {
            rate = default_speed,
            desc = "Velocidad configurada (Personalizada)",
            is_default = true,
            text = string.format("%s baud Velocidad configurada (Personalizada)", default_speed),
        })
    end

    table.sort(items, function(a, b)
        if a.is_default ~= b.is_default then
            return a.is_default
        end
        local num_a = tonumber(a.rate) or 0
        local num_b = tonumber(b.rate) or 0
        return num_a < num_b
    end)

    local handled_action = false

    snacks.picker.pick({
        source = "pio_baud_rates",
        prompt = "🚀 Velocidad Serial (monitor_speed) ",
        focus = "list",

        finder = function()
            return items
        end,

        -- Registro de la acción personalizada para retroceder
        actions = {
            go_prev = function(p)
                handled_action = true
                p:close()
                on_select({
                    action = "prev",
                    value = default_speed ~= "" and ("monitor_speed = " .. default_speed) or nil,
                    rate = default_speed ~= "" and default_speed or nil,
                    item = nil,
                })
            end,
        },

        -- Mapeo explícito de teclas en modo normal para input y list
        win = {
            input = {
                keys = {
                    ["l"] = { "confirm", mode = { "n" } },
                    ["h"] = { "go_prev", mode = { "n" } },
                },
            },
            list = {
                keys = {
                    ["l"] = "confirm",
                    ["h"] = "go_prev",
                },
            },
        },

        layout = {
            layout = {
                box = "vertical",
                width = 0.60,
                height = 0.50,
                { win = "input", height = 1, border = "rounded" },
                { win = "list", border = "rounded" },
            },
        },

        format = function(item)
            local tag = item.is_default and " ✔ [Actual]" or ""
            local hl_rate = item.is_default and "String" or "DiagnosticInfo"

            return {
                { string.format("%-12s", item.rate .. " baud"), hl_rate },
                { " │ " },
                { item.desc, "Comment" },
                { tag, "String" },
            }
        end,

        confirm = function(p, item)
            handled_action = true
            p:close()
            if item then
                on_select({
                    action = "next",
                    value = "monitor_speed = " .. item.rate,
                    rate = item.rate,
                    item = item,
                })
            else
                on_select({
                    action = "cancel",
                    value = nil,
                    rate = nil,
                    item = nil,
                })
            end
        end,

        on_close = function()
            if not handled_action then
                handled_action = true
                on_select({
                    action = "cancel",
                    value = nil,
                    rate = nil,
                    item = nil,
                })
            end
        end,
    })
end

--------------------------------------------------------------------------------
-- 5. SELECTOR DE FRAMEWORK (SNACKS.PICKER + FILTRADO POR PLACA)
--------------------------------------------------------------------------------
local DEFAULT_FRAMEWORKS = {
    { id = "arduino", desc = "Framework clásico Arduino (Amplia compatibilidad)" },
    { id = "espressif32", desc = "ESP-IDF oficial para ESP32" },
    { id = "mbed", desc = "Arm Mbed OS para microcontroladores ARM" },
    { id = "stm32cube", desc = "HAL/LL oficial de STMicroelectronics" },
    { id = "zephyr", desc = "RTOS escalable para múltiples arquitecturas" },
    { id = "pico-sdk", desc = "SDK nativo C/C++ de Raspberry Pi Pico" },
    { id = "cmsis", desc = "ARM CMSIS Cortex Microcontroller Software Interface" },
    { id = "freertos", desc = "Sistema Operativo en Tiempo Real" },
    { id = "libopencm3", desc = "Librería Open Source para ARM Cortex-M" },
}

function M.pio_select_framework(selected_board, default_framework, on_select)
    if type(default_framework) == "function" then
        on_select = default_framework
        default_framework = nil
    end

    on_select = on_select
        or function(res)
            vim.notify("Acción: " .. res.action .. " | Framework: " .. tostring(res.framework), vim.log.levels.INFO)
        end

    local snacks_ok, snacks = pcall(require, "snacks")
    if not snacks_ok or not snacks.picker then
        vim.notify("`snacks.nvim` no está instalado o cargado", vim.log.levels.ERROR)
        on_select({ action = "cancel", value = nil, framework = nil, item = nil })
        return
    end

    local board_id = (
        type(selected_board) == "string" and selected_board:gsub("^board%s*=%s*", ""):gsub("%s+", ""):lower()
    ) or ""
    default_framework = (
        type(default_framework) == "string" and default_framework:gsub("^framework%s*=%s*", ""):gsub("%s+", ""):lower()
    ) or "arduino"

    BOARDS_CACHE = BOARDS_CACHE or load_disk_cache()

    local available_frameworks = nil
    if board_id ~= "" and BOARDS_CACHE then
        for _, b in ipairs(BOARDS_CACHE) do
            if b.id and b.id:lower() == board_id then
                if type(b.frameworks) == "table" and #b.frameworks > 0 then
                    available_frameworks = b.frameworks
                end
                break
            end
        end
    end

    local items = {}
    if available_frameworks then
        local desc_map = {}
        for _, f in ipairs(DEFAULT_FRAMEWORKS) do
            desc_map[f.id] = f.desc
        end

        for _, fw in ipairs(available_frameworks) do
            local fw_str = tostring(fw)
            local is_def = (fw_str:lower() == default_framework)
            table.insert(items, {
                id = fw_str,
                desc = desc_map[fw_str] or ("Framework compatible con " .. board_id),
                is_default = is_def,
                text = fw_str .. " " .. (desc_map[fw_str] or ""),
            })
        end
    else
        for _, f in ipairs(DEFAULT_FRAMEWORKS) do
            local is_def = (f.id:lower() == default_framework)
            table.insert(items, {
                id = f.id,
                desc = f.desc,
                is_default = is_def,
                text = f.id .. " " .. f.desc,
            })
        end
    end

    table.sort(items, function(a, b)
        if a.is_default ~= b.is_default then
            return a.is_default
        end
        return a.id < b.id
    end)

    local handled_action = false
    local prompt_title = board_id ~= "" and string.format("⚙️ Framework (%s) ", board_id)
        or "⚙️ Framework (Global) "

    snacks.picker.pick({
        source = "pio_frameworks",
        prompt = prompt_title,
        focus = "list",

        finder = function()
            return items
        end,

        -- Registro de la acción personalizada para retroceder
        actions = {
            go_prev = function(p)
                handled_action = true
                p:close()
                on_select({
                    action = "prev",
                    value = default_framework ~= "" and ("framework = " .. default_framework) or nil,
                    framework = default_framework ~= "" and default_framework or nil,
                    item = nil,
                })
            end,
        },

        -- Mapeo explícito de teclas en modo normal para input y list
        win = {
            input = {
                keys = {
                    ["l"] = { "confirm", mode = { "n" } },
                    ["h"] = { "go_prev", mode = { "n" } },
                },
            },
            list = {
                keys = {
                    ["l"] = "confirm",
                    ["h"] = "go_prev",
                },
            },
        },

        layout = {
            layout = {
                box = "vertical",
                width = 0.60,
                height = 0.50,
                { win = "input", height = 1, border = "rounded" },
                { win = "list", border = "rounded" },
            },
        },

        format = function(item)
            local tag = item.is_default and " ✔ [Actual]" or ""
            local hl_id = item.is_default and "String" or "DiagnosticInfo"

            return {
                { string.format("%-16s", item.id), hl_id },
                { " │ " },
                { item.desc, "Comment" },
                { tag, "String" },
            }
        end,

        confirm = function(p, item)
            handled_action = true
            p:close()
            if item then
                on_select({
                    action = "next",
                    value = "framework = " .. item.id,
                    framework = item.id,
                    item = item,
                })
            else
                on_select({
                    action = "cancel",
                    value = nil,
                    framework = nil,
                    item = nil,
                })
            end
        end,

        on_close = function()
            if not handled_action then
                handled_action = true
                on_select({
                    action = "cancel",
                    value = nil,
                    framework = nil,
                    item = nil,
                })
            end
        end,
    })
end

--------------------------------------------------------------------------------
-- 6. SELECTOR DE FLASH ESP32-S3 (SNACKS.PICKER)
--------------------------------------------------------------------------------
local ESP32S3_FLASH_OPTIONS = {
    { size = "8MB", desc = "8MB Flash (Estándar DevKitC-1 N8)" },
    { size = "16MB", desc = "16MB Flash Alta Capacidad (DevKitC-1 N16)" },
    { size = "4MB", desc = "4MB Flash Básico (Quad SPI)" },
    { size = "32MB", desc = "32MB Flash Máxima Capacidad (Personalizado)" },
}

function M.pio_select_esp32s3_flash(default_size, on_select)
    on_select = on_select
        or function(res)
            vim.notify("Acción: " .. res.action .. " | Flash: " .. tostring(res.flash_size), vim.log.levels.INFO)
        end

    local snacks_ok, snacks = pcall(require, "snacks")
    if not snacks_ok or not snacks.picker then
        vim.notify("`snacks.nvim` no está instalado", vim.log.levels.ERROR)
        on_select({ action = "cancel", value = nil, flash_size = nil, item = nil })
        return
    end

    local clean_def = (
        type(default_size) == "string" and default_size:gsub("^[%w_%.]+%s*=%s*", ""):gsub("%s+", ""):upper()
    ) or "8MB"

    local items = {}
    for _, f in ipairs(ESP32S3_FLASH_OPTIONS) do
        local is_def = (f.size:upper() == clean_def)
        table.insert(items, {
            size = f.size,
            desc = f.desc,
            is_default = is_def,
            text = f.size .. " " .. f.desc,
        })
    end

    table.sort(items, function(a, b)
        if a.is_default ~= b.is_default then
            return a.is_default
        end
        return a.size < b.size
    end)

    local handled_action = false

    snacks.picker.pick({
        source = "pio_esp32s3_flash",
        prompt = "💾 Flash Size (ESP32-S3) ",
        focus = "list",

        finder = function()
            return items
        end,

        actions = {
            go_prev = function(p)
                handled_action = true
                p:close()
                on_select({
                    action = "prev",
                    value = clean_def ~= "" and ("board_upload.flash_size = " .. clean_def) or nil,
                    flash_size = clean_def ~= "" and clean_def or nil,
                    item = nil,
                })
            end,
        },

        win = {
            input = {
                keys = {
                    ["l"] = { "confirm", mode = { "n" } },
                    ["h"] = { "go_prev", mode = { "n" } },
                },
            },
            list = {
                keys = {
                    ["l"] = "confirm",
                    ["h"] = "go_prev",
                },
            },
        },

        layout = {
            layout = {
                box = "vertical",
                width = 0.60,
                height = 0.45,
                { win = "input", height = 1, border = "rounded" },
                { win = "list", border = "rounded" },
            },
        },

        format = function(item)
            local tag = item.is_default and " ✔ [Actual]" or ""
            local hl = item.is_default and "String" or "DiagnosticInfo"

            return {
                { string.format("%-10s", item.size), hl },
                { " │ " },
                { item.desc, "Comment" },
                { tag, "String" },
            }
        end,

        confirm = function(p, item)
            handled_action = true
            p:close()
            if item then
                on_select({
                    action = "next",
                    value = "board_upload.flash_size = " .. item.size,
                    flash_size = item.size,
                    item = item,
                })
            else
                on_select({
                    action = "cancel",
                    value = nil,
                    flash_size = nil,
                    item = nil,
                })
            end
        end,

        on_close = function()
            if not handled_action then
                handled_action = true
                on_select({
                    action = "cancel",
                    value = nil,
                    flash_size = nil,
                    item = nil,
                })
            end
        end,
    })
end

--------------------------------------------------------------------------------
-- 7. SELECTOR DE PSRAM ESP32-S3 (SNACKS.PICKER)
--------------------------------------------------------------------------------
local ESP32S3_PSRAM_OPTIONS = {
    {
        id = "none",
        name = "Sin PSRAM",
        ram_size = "0MB",
        desc = "Variantes N4 / N8 / N16 (Sin RAM externa)",
        mem_type = "qio_qspi",
        has_psram = false,
    },
    {
        id = "qspi",
        name = "PSRAM Quad SPI",
        ram_size = "2MB",
        desc = "Variante R2 (PSRAM en modo QSPI)",
        mem_type = "qio_qspi",
        has_psram = true,
    },
    {
        id = "opi",
        name = "PSRAM Octal SPI",
        ram_size = "8MB",
        desc = "Variante R8 / R8V (PSRAM en modo OPI - N8R8, N16R8)",
        mem_type = "qio_opi",
        has_psram = true,
    },
    {
        id = "opi_opi",
        name = "PSRAM Octal + Flash Octal",
        ram_size = "8MB",
        desc = "Variante OPI Flash + OPI PSRAM (N16R8V, N32R8V)",
        mem_type = "opi_opi",
        has_psram = true,
    },
}

--- Helper para determinar de forma unívoca si una opción es la activa
local function is_option_default(item, clean_val, has_psram_flag)
    -- 1. Coincidencia directa por ID único ("none", "qspi", "opi", "opi_opi", "disabled")
    if clean_val == item.id or (clean_val == "disabled" and item.id == "none") then
        return true
    end

    -- 2. Coincidencia por tipo de memoria (mem_type: "qio_qspi", "qio_opi", "opi_opi")
    if item.mem_type:lower() == clean_val then
        if has_psram_flag ~= nil then
            return item.has_psram == has_psram_flag
        end
        if clean_val == "qio_qspi" then
            return not item.has_psram
        end
        return true
    end

    return false
end

function M.pio_select_esp32s3_psram(default_val, has_psram_flag, on_select)
    -- Soporte para sobrecarga de argumentos: (default_val, on_select) o (default_val, has_psram_flag, on_select)
    if type(has_psram_flag) == "function" then
        on_select = has_psram_flag
        has_psram_flag = nil
    end

    on_select = on_select
        or function(res)
            vim.notify("Acción: " .. res.action .. " | RAM: " .. tostring(res.ram_size), vim.log.levels.INFO)
        end

    local snacks_ok, snacks = pcall(require, "snacks")
    if not snacks_ok or not snacks.picker then
        vim.notify("`snacks.nvim` no está instalado", vim.log.levels.ERROR)
        on_select({ action = "cancel", value = nil, lines = nil, ram_size = nil, mem_type = nil, item = nil })
        return
    end

    local clean_def = (
        type(default_val) == "string" and default_val:gsub("^[%w_%.]+%s*=%s*", ""):gsub("%s+", ""):lower()
    ) or "none"
    if clean_def == "" then
        clean_def = "none"
    end

    local items = {}
    for _, p in ipairs(ESP32S3_PSRAM_OPTIONS) do
        local is_def = is_option_default(p, clean_def, has_psram_flag)
        table.insert(items, {
            id = p.id,
            name = p.name,
            ram_size = p.ram_size,
            desc = p.desc,
            mem_type = p.mem_type,
            has_psram = p.has_psram,
            is_default = is_def,
            text = string.format("%s %s %s %s", p.ram_size, p.name, p.mem_type, p.desc),
        })
    end

    table.sort(items, function(a, b)
        if a.is_default ~= b.is_default then
            return a.is_default
        end
        return a.id < b.id
    end)

    local handled_action = false

    snacks.picker.pick({
        source = "pio_esp32s3_psram",
        prompt = "🧠 Configuración PSRAM (ESP32-S3) ",
        focus = "list",

        finder = function()
            return items
        end,

        actions = {
            go_prev = function(p)
                handled_action = true
                p:close()
                on_select({
                    action = "prev",
                    value = clean_def,
                    mem_type = clean_def,
                    ram_size = nil,
                    lines = nil,
                    item = nil,
                })
            end,
        },

        win = {
            input = {
                keys = {
                    ["l"] = { "confirm", mode = { "n" } },
                    ["h"] = { "go_prev", mode = { "n" } },
                },
            },
            list = {
                keys = {
                    ["l"] = "confirm",
                    ["h"] = "go_prev",
                },
            },
        },

        layout = {
            layout = {
                box = "vertical",
                width = 0.75,
                height = 0.50,
                { win = "input", height = 1, border = "rounded" },
                { win = "list", border = "rounded" },
            },
        },

        format = function(item)
            local tag = item.is_default and " ✔ [Actual]" or ""
            local hl = item.is_default and "String" or "DiagnosticInfo"

            return {
                { string.format("%-6s", item.ram_size), "WarningMsg" },
                { " │ " },
                { string.format("%-26s", item.name), hl },
                { " │ " },
                { item.desc, "Comment" },
                { tag, "String" },
            }
        end,

        confirm = function(p, item)
            handled_action = true
            p:close()
            if item then
                local config_lines = {}
                local mem_type_val = "none"

                -- Solo generamos líneas de configuración si la opción realmente TIENE PSRAM
                if item.id ~= "none" and item.has_psram then
                    table.insert(config_lines, "board_build.arduino.memory_type = " .. item.mem_type)
                    table.insert(config_lines, "build_flags = -DBOARD_HAS_PSRAM")
                    mem_type_val = item.mem_type
                end

                on_select({
                    action = "next",
                    value = #config_lines > 0 and table.concat(config_lines, "\n") or "none",
                    lines = config_lines, -- Retorna {} si seleccionó "none"
                    ram_size = item.ram_size,
                    mem_type = mem_type_val,
                    item = item,
                })
            else
                on_select({
                    action = "cancel",
                    value = nil,
                    lines = nil,
                    ram_size = nil,
                    mem_type = nil,
                    item = nil,
                })
            end
        end,

        on_close = function()
            if not handled_action then
                handled_action = true
                on_select({
                    action = "cancel",
                    value = nil,
                    lines = nil,
                    ram_size = nil,
                    mem_type = nil,
                    item = nil,
                })
            end
        end,
    })
end

--------------------------------------------------------------------------------
-- 8.1 HELPER: COMPARADOR DE VERSIONES (SEMVER DESCENDENTE)
--------------------------------------------------------------------------------
local function parse_semver(v_str)
    local maj, min, pat = v_str:match("^v?(%d+)%.?(%d*)%.?(%d*)")
    return {
        major = tonumber(maj) or 0,
        minor = tonumber(min) or 0,
        patch = tonumber(pat) or 0,
    }
end

local function compare_semver_desc(a_str, b_str)
    local a = parse_semver(a_str)
    local b = parse_semver(b_str)

    if a.major ~= b.major then
        return a.major > b.major
    end
    if a.minor ~= b.minor then
        return a.minor > b.minor
    end
    if a.patch ~= b.patch then
        return a.patch > b.patch
    end
    return a_str > b_str
end

--------------------------------------------------------------------------------
-- 8.2 SELECTOR / CAMBIO DE VERSIÓN DE LIBRERÍA
--------------------------------------------------------------------------------
function M.pio_select_lib_version(lib_input, on_select)
    on_select = on_select
        or function(res)
            vim.notify(
                string.format("Acción: %s | Versión: %s", res.action, tostring(res.version)),
                vim.log.levels.INFO
            )
        end

    if not lib_input or lib_input:match("^%s*$") then
        on_select({ action = "cancel", value = nil, version = nil, lib_name = nil, item = nil })
        return
    end

    local clean_input = lib_input:gsub("%s+", "")
    local raw_lib, current_ver = clean_input:match("^([^@]+)@?(.*)$")
    if not raw_lib or raw_lib == "" then
        vim.notify("Formato de librería no válido: " .. tostring(lib_input), vim.log.levels.ERROR)
        on_select({ action = "cancel", value = nil, version = nil, lib_name = nil, item = nil })
        return
    end

    local owner, name = raw_lib:match("^([^/]+)/(.*)$")
    if not owner then
        name = raw_lib
    end

    vim.notify(string.format("🔍 Buscando versiones para: %s...", raw_lib), vim.log.levels.INFO)

    local handled_action = false

    local function show_versions_ui(pkg_data, full_lib_name)
        local versions_list = {}
        if pkg_data and type(pkg_data.versions) == "table" then
            for _, v in ipairs(pkg_data.versions) do
                local vname = (type(v) == "table" and v.name) or tostring(v)
                table.insert(versions_list, vname)
            end
        end

        if #versions_list == 0 then
            vim.notify("No se encontró la librería '" .. full_lib_name .. "' en el registro", vim.log.levels.WARN)
            if not handled_action then
                handled_action = true
                on_select({ action = "cancel", value = nil, version = nil, lib_name = full_lib_name, item = nil })
            end
            return
        end

        -- ORDENAR VERSIONES DE MAYOR A MENOR (SEMVER)
        table.sort(versions_list, compare_semver_desc)

        local clean_curr_ver = current_ver:gsub("[^%d%.%-]", "")
        local ver_lines = {
            string.format("  Versiones disponibles para: %s", full_lib_name),
            string.rep("─", 58),
        }

        local initial_line = 3

        for v_idx, ver in ipairs(versions_list) do
            local tags = {}
            local is_current = false

            if v_idx == 1 then
                table.insert(tags, "[Última]")
            end

            if current_ver ~= "" and (ver == clean_curr_ver or ver == current_ver) then
                table.insert(tags, "✔ [Instalada actualmente]")
                is_current = true
            end

            if is_current then
                initial_line = v_idx + 2
            end

            local tag_str = #tags > 0 and ("  " .. table.concat(tags, " ")) or ""
            table.insert(ver_lines, string.format(" • %-15s %s", ver, tag_str))
        end

        local buf = vim.api.nvim_create_buf(false, true)
        vim.bo[buf].filetype = "markdown"
        vim.bo[buf].bufhidden = "wipe"
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, ver_lines)

        local width = math.floor(vim.o.columns * 0.60)
        local height = math.min(#ver_lines + 2, math.floor(vim.o.lines * 0.70))
        local win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            row = math.floor((vim.o.lines - height) / 2),
            col = math.floor((vim.o.columns - width) / 2),
            style = "minimal",
            border = "rounded",
            title = " Seleccionar Versión - l/<CR> Confirmar | h Anterior | q/<Esc> Cancelar ",
            title_pos = "center",
        })

        vim.wo[win].cursorline = true
        vim.wo[win].cursorlineopt = "both"
        vim.api.nvim_win_set_cursor(win, { initial_line, 0 })

        local function finish(response)
            if not handled_action then
                handled_action = true
                if vim.api.nvim_win_is_valid(win) then
                    vim.api.nvim_win_close(win, true)
                end
                if vim.api.nvim_buf_is_valid(buf) then
                    vim.api.nvim_buf_delete(buf, { force = true })
                end
                on_select(response)
            end
        end

        local map_opts = { buffer = buf, silent = true, noremap = true, nowait = true }

        local function confirm_selection()
            local cursor = vim.api.nvim_win_get_cursor(win)
            local v_idx = cursor[1] - 2
            if v_idx >= 1 and v_idx <= #versions_list then
                local sel_ver = versions_list[v_idx]
                local formatted_val = string.format("%s@^%s", full_lib_name, sel_ver)
                finish({
                    action = "next",
                    value = formatted_val,
                    version = sel_ver,
                    lib_name = full_lib_name,
                    item = {
                        version = sel_ver,
                        full_name = full_lib_name,
                        raw_data = pkg_data,
                    },
                })
            end
        end

        local function go_prev()
            finish({
                action = "prev",
                value = lib_input,
                version = current_ver ~= "" and current_ver or nil,
                lib_name = full_lib_name,
                item = nil,
            })
        end

        local function cancel()
            finish({
                action = "cancel",
                value = nil,
                version = nil,
                lib_name = full_lib_name,
                item = nil,
            })
        end

        vim.keymap.set("n", "<CR>", confirm_selection, map_opts)
        vim.keymap.set("n", "l", confirm_selection, map_opts)
        vim.keymap.set("n", "h", go_prev, map_opts)
        vim.keymap.set("n", "q", cancel, map_opts)
        vim.keymap.set("n", "<Esc>", cancel, map_opts)

        vim.api.nvim_create_autocmd("BufWipeout", {
            buffer = buf,
            once = true,
            callback = function()
                if not handled_action then
                    finish({
                        action = "cancel",
                        value = nil,
                        version = nil,
                        lib_name = full_lib_name,
                        item = nil,
                    })
                end
            end,
        })
    end

    if owner then
        local pkg_url = string.format(
            "https://api.registry.platformio.org/v3/packages/%s/library/%s",
            uri_encode(owner),
            uri_encode(name)
        )
        vim.system({ curl_bin, "-s", pkg_url }, { text = true }, function(pkg_out)
            vim.schedule(function()
                if pkg_out.code == 0 and pkg_out.stdout then
                    local ok_pkg, pkg_data = pcall(vim.json.decode, pkg_out.stdout)
                    if ok_pkg and pkg_data and pkg_data.versions then
                        show_versions_ui(pkg_data, owner .. "/" .. name)
                        return
                    end
                end
                show_versions_ui(nil, owner .. "/" .. name)
            end)
        end)
    else
        local search_url =
            string.format("https://api.registry.platformio.org/v3/search?query=%s&limit=5", uri_encode(name))
        vim.system({ curl_bin, "-s", search_url }, { text = true }, function(s_out)
            vim.schedule(function()
                if s_out.code == 0 and s_out.stdout then
                    local ok_s, s_data = pcall(vim.json.decode, s_out.stdout)
                    if ok_s and s_data and s_data.items and #s_data.items > 0 then
                        local match_item = s_data.items[1]
                        local matched_owner = (type(match_item.owner) == "table" and match_item.owner.username)
                            or match_item.owner
                        local matched_name = match_item.name

                        if matched_owner and matched_name then
                            local pkg_url = string.format(
                                "https://api.registry.platformio.org/v3/packages/%s/library/%s",
                                uri_encode(matched_owner),
                                uri_encode(matched_name)
                            )
                            vim.system({ curl_bin, "-s", pkg_url }, { text = true }, function(pkg_out)
                                vim.schedule(function()
                                    if pkg_out.code == 0 and pkg_out.stdout then
                                        local ok_pkg, pkg_data = pcall(vim.json.decode, pkg_out.stdout)
                                        if ok_pkg and pkg_data then
                                            show_versions_ui(pkg_data, matched_owner .. "/" .. matched_name)
                                            return
                                        end
                                    end
                                    show_versions_ui(nil, name)
                                end)
                            end)
                            return
                        end
                    end
                end
                show_versions_ui(nil, name)
            end)
        end)
    end
end

--------------------------------------------------------------------------------
-- 9.1 HELPER: GENERAR MARKDOWN DE DETALLES DE LIBRERÍA
--------------------------------------------------------------------------------
local function build_detail_markdown(search_item, pkg_detail)
    search_item = search_item or {}
    pkg_detail = pkg_detail or {}

    local function get_prop(key)
        local val = pkg_detail[key] or search_item[key]
        return (type(val) == "string" or type(val) == "number") and val or nil
    end

    local owner = (type(pkg_detail.owner) == "table" and pkg_detail.owner.username)
        or (type(pkg_detail.owner) == "string" and pkg_detail.owner)
        or (type(search_item.owner) == "table" and search_item.owner.username)
        or get_prop("owner")
        or "desconocido"

    local name = get_prop("name") or "sin-nombre"

    local raw_version = (type(pkg_detail.version) == "table" and pkg_detail.version.name)
        or (type(search_item.version) == "table" and search_item.version.name)
        or get_prop("version")
        or "1.0.0"
    local version = tostring(raw_version):gsub("[^%d%.%-]", "")
    if version == "" then
        version = "1.0.0"
    end

    local desc = get_prop("description") or "Sin descripción disponible."

    local license = (type(pkg_detail.license) == "table" and pkg_detail.license.name)
        or (type(search_item.license) == "table" and search_item.license.name)
        or get_prop("license")
        or "No especificada"

    local keywords = "Ninguna"
    local kw_table = (type(pkg_detail.keywords) == "table" and #pkg_detail.keywords > 0 and pkg_detail.keywords)
        or (type(search_item.keywords) == "table" and #search_item.keywords > 0 and search_item.keywords)
    if kw_table then
        keywords = table.concat(kw_table, ", ")
    end

    local pio_web_url = string.format("https://registry.platformio.org/libraries/%s/%s", owner, name)

    local download_url = "N/A"
    local files = (pkg_detail.version and type(pkg_detail.version.files) == "table" and pkg_detail.version.files)
        or (search_item.version and type(search_item.version.files) == "table" and search_item.version.files)
    if files and files[1] and files[1].download_url then
        download_url = files[1].download_url
    end

    local repo_url = (type(extract_repo_url) == "function" and extract_repo_url(search_item, pkg_detail))
        or "No disponible"
    local homepage = pio_web_url
    local frameworks = "Todos / Sin restricción"
    local platforms = "Todos / Sin restricción"
    local headers = "Todos / Sin restricción"

    if next(pkg_detail) then
        if type(pkg_detail.homepage) == "string" and pkg_detail.homepage:match("^https?://") then
            homepage = pkg_detail.homepage
        elseif repo_url ~= "No disponible en API" and repo_url ~= "No disponible" then
            homepage = repo_url
        end

        if type(parse_list) == "function" then
            frameworks = parse_list(pkg_detail.frameworks)
            platforms = parse_list(pkg_detail.platforms)
            headers = parse_list(pkg_detail.headers)
        end
    end

    local stars = get_prop("stars_count") or 0

    return {
        "# " .. owner .. "/" .. name,
        "",
        "> " .. desc,
        "",
        "## 🛠️ Sintaxis de referencia",
        "```ini",
        "lib_deps =",
        "    " .. owner .. "/" .. name .. " @ ^" .. version,
        "```",
        "",
        "## 🔗 Enlaces Directos",
        "- **Web Oficial Registry:** " .. pio_web_url,
        "- **Repositorio Git / GitHub:** " .. repo_url,
        "- **Página Web:** " .. homepage,
        "- **Descarga (.tar.gz):** " .. download_url,
        "",
        "## ⚙️ Compatibilidad y Metadatos",
        "- **Última Versión:** " .. version,
        "- **Licencia:** " .. tostring(license),
        "- **Estrellas:** ⭐ " .. tostring(stars),
        "- **Frameworks:** " .. frameworks,
        "- **Plataformas:** " .. platforms,
        "- **Headers (.h):** " .. headers,
        "- **Keywords:** " .. keywords,
        "",
        "─" .. string.rep("─", 54),
        "* Presiona `<CR>` o `gx` sobre una URL para abrirla *",
        "* Presiona `<BS>`, `b` o `h` para volver | `q` o `<Esc>` para cerrar *",
    }
end

--------------------------------------------------------------------------------
-- 9.2 MOSTRAR PANEL DE DETALLES DE LIBRERÍA
--------------------------------------------------------------------------------
function M.show_library_details(lib_identifier, target_win, parent_buf)
    local raw_owner, raw_name

    if type(lib_identifier) == "string" then
        -- Sanitizar removiendo sufijos de versión (@^1.2.3 o @6.21.3)
        local clean_id = lib_identifier:gsub("@.*$", ""):gsub("%s+", "")
        raw_owner, raw_name = clean_id:match("^([^/]+)/(.+)$")
        if not raw_owner then
            raw_name = clean_id
        end
    elseif type(lib_identifier) == "table" then
        raw_owner = (type(lib_identifier.owner) == "table" and lib_identifier.owner.username) or lib_identifier.owner
        raw_name = lib_identifier.name
    else
        vim.notify("Identificador de librería inválido", vim.log.levels.ERROR)
        return
    end

    local detail_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[detail_buf].filetype = "markdown"
    vim.bo[detail_buf].bufhidden = "wipe"

    local win = target_win
    local title_text = string.format(" PIO - %s ", raw_owner and (raw_owner .. "/" .. raw_name) or raw_name)

    -- 1. Dimensiones ampliadas calculadas para ambas ramas
    local width = math.floor(vim.o.columns * 0.85)
    local height = math.floor(vim.o.lines * 0.80)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    if not win or not vim.api.nvim_win_is_valid(win) then
        win = vim.api.nvim_open_win(detail_buf, true, {
            relative = "editor",
            width = width,
            height = height,
            row = row,
            col = col,
            style = "minimal",
            border = "rounded",
            title = title_text,
            title_pos = "center",
        })
    else
        vim.api.nvim_win_set_buf(win, detail_buf)
        -- 2. Redimensionar y recentrar la ventana existente
        vim.api.nvim_win_set_config(win, {
            relative = "editor",
            width = width,
            height = height,
            row = row,
            col = col,
            title = title_text,
            title_pos = "center",
        })
    end
    vim.wo[win].wrap = true
    vim.wo[win].linebreak = true

    local function set_buf_lines(lines)
        if vim.api.nvim_buf_is_valid(detail_buf) then
            vim.bo[detail_buf].modifiable = true
            vim.api.nvim_buf_set_lines(detail_buf, 0, -1, false, lines)
            vim.bo[detail_buf].modifiable = false
        end
    end

    local search_item = type(lib_identifier) == "table" and lib_identifier
        or { owner = raw_owner or "Buscando...", name = raw_name }

    set_buf_lines(build_detail_markdown(search_item, nil))

    local function update_ui(item, details)
        set_buf_lines(build_detail_markdown(item, details))
        if details and details.name and vim.api.nvim_win_is_valid(win) then
            local final_owner = (type(item.owner) == "table" and item.owner.username) or item.owner or raw_owner
            if final_owner then
                vim.api.nvim_win_set_config(win, {
                    title = string.format(" PIO - %s/%s ", final_owner, details.name),
                    title_pos = "center",
                })
            end
        end
    end

    if raw_owner and raw_owner ~= "desconocido" and raw_owner ~= "Buscando..." then
        fetch_package_details({ owner = raw_owner, name = raw_name }, function(pkg_data)
            vim.schedule(function()
                if pkg_data and pkg_data.name then
                    update_ui({ owner = raw_owner, name = raw_name }, pkg_data)
                else
                    vim.notify("No se encontraron detalles para: " .. raw_owner .. "/" .. raw_name, vim.log.levels.WARN)
                end
            end)
        end)
    else
        local search_url =
            string.format("https://api.registry.platformio.org/v3/search?query=%s&limit=1", uri_encode(raw_name))
        vim.system({ curl_bin, "-s", search_url }, { text = true }, function(out)
            vim.schedule(function()
                if out.code == 0 and out.stdout then
                    local ok, parsed = pcall(vim.json.decode, out.stdout)
                    if ok and parsed and parsed.items and #parsed.items > 0 then
                        local found_item = parsed.items[1]
                        fetch_package_details(found_item, function(pkg_data)
                            vim.schedule(function()
                                update_ui(found_item, pkg_data or found_item)
                            end)
                        end)
                        return
                    end
                end
                vim.notify(
                    "Librería no encontrada en PlatformIO Registry: " .. tostring(raw_name),
                    vim.log.levels.ERROR
                )
            end)
        end)
    end

    local map_opts = { buffer = detail_buf, silent = true, noremap = true, nowait = true }

    local function close_panel()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    local function go_back()
        if parent_buf and vim.api.nvim_buf_is_valid(parent_buf) and vim.api.nvim_win_is_valid(win) then
            vim.wo[win].wrap = false
            vim.wo[win].linebreak = false

            -- Encoger la ventana de nuevo al tamaño estándar del menú principal
            local width = math.floor(vim.o.columns * 0.60)
            local lines = vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false)
            local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.70))

            vim.api.nvim_win_set_config(win, {
                relative = "editor",
                width = width,
                height = height,
                row = math.floor((vim.o.lines - height) / 2),
                col = math.floor((vim.o.columns - width) / 2),
            })

            vim.api.nvim_win_set_buf(win, parent_buf)
        else
            close_panel()
        end
    end
    local function open_link()
        local line = vim.api.nvim_get_current_line()
        local url = line:match("(https?://[%w_.~!*';:@&=+$,/?%%#%-]+)")
        if url then
            vim.ui.open(url)
            vim.notify("Abriendo URL: " .. url, vim.log.levels.INFO)
        else
            vim.notify("No hay una URL válida en esta línea", vim.log.levels.WARN)
        end
    end

    vim.keymap.set("n", "<BS>", go_back, map_opts)
    vim.keymap.set("n", "b", go_back, map_opts)
    vim.keymap.set("n", "h", go_back, map_opts)
    vim.keymap.set("n", "q", go_back, map_opts) -- Cambiado de close_panel a go_back
    vim.keymap.set("n", "<Esc>", go_back, map_opts) -- Cambiado de close_panel a go_back
    vim.keymap.set("n", "<CR>", open_link, map_opts)
    vim.keymap.set("n", "gx", open_link, map_opts)
end

--------------------------------------------------------------------------------
-- 10.1 HELPER: NORMALIZAR NOMBRE BASE DE LIBRERÍA
--------------------------------------------------------------------------------
local function get_lib_base_name(lib_str)
    if not lib_str then
        return ""
    end
    return lib_str:gsub("@.*$", ""):gsub("%s+", ""):lower()
end

--------------------------------------------------------------------------------
-- 10.1 HELPER: CALCULAR CAMBIOS EN LA LISTA DE LIBRERÍAS
--------------------------------------------------------------------------------
local function calculate_lib_changes(initial_list, current_list)
    local init_map, curr_map = {}, {}
    for _, item in ipairs(initial_list or {}) do
        local name = get_lib_base_name(item)
        init_map[name] = item
    end
    for _, item in ipairs(current_list or {}) do
        local name = get_lib_base_name(item)
        curr_map[name] = item
    end

    local added, removed, modified, unchanged = {}, {}, {}, {}

    for name, full in pairs(curr_map) do
        if not init_map[name] then
            table.insert(added, full)
        elseif init_map[name] ~= full then
            table.insert(modified, { name = name, old = init_map[name], new = full })
        else
            table.insert(unchanged, full)
        end
    end

    for name, full in pairs(init_map) do
        if not curr_map[name] then
            table.insert(removed, full)
        end
    end

    return {
        added = added,
        removed = removed,
        modified = modified,
        unchanged = unchanged,
    }
end

--------------------------------------------------------------------------------
-- 10.2 GESTOR DE LIBRERÍAS INSTALADAS
--------------------------------------------------------------------------------
function M.pio_manage_installed_libs(installed_libs, on_finish)
    installed_libs = installed_libs or {}
    on_finish = on_finish
        or function(res)
            vim.notify(
                string.format("Gestión finalizada: %s (%d librerías)", res.action, #(res.value or {})),
                vim.log.levels.INFO
            )
        end

    local initial_copy = vim.deepcopy(installed_libs)
    local current_libs = vim.deepcopy(installed_libs)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].bufhidden = "hide"

    local win = nil

    local function render_ui()
        local lines = {
            "  [+]  Agregar nueva librería",
            "  [✓]  Confirmar y aplicar cambios",
            string.rep("─", 58),
        }

        if #current_libs == 0 then
            table.insert(lines, "  (Sin librerías instaladas)")
        else
            for _, lib in ipairs(current_libs) do
                table.insert(lines, string.format(" • %s", lib))
            end
        end

        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modifiable = false

        if win and vim.api.nvim_win_is_valid(win) then
            local height = math.min(#current_libs + 6, math.floor(vim.o.lines * 0.70))
            vim.api.nvim_win_set_config(win, { height = height })
        end
    end

    render_ui()

    local width = math.floor(vim.o.columns * 0.60)
    local height = math.min(#current_libs + 6, math.floor(vim.o.lines * 0.70))
    win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
        title = " Gestión de Librerías - l/<CR> Cambiar Versión | a Agregar | i Info | d Eliminar | h Anterior ",
        title_pos = "center",
    })

    vim.cmd("stopinsert")
    vim.wo[win].cursorline = true
    vim.wo[win].cursorlineopt = "both"
    vim.api.nvim_win_set_cursor(win, { 1, 0 })

    local handled_action = false
    local function finish(response)
        if not handled_action then
            handled_action = true
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
            if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
            on_finish(response)
        end
    end

    local function get_lib_idx_under_cursor()
        local cursor = vim.api.nvim_win_get_cursor(win)
        local line_num = cursor[1]
        if line_num >= 4 and #current_libs > 0 then
            local idx = line_num - 3
            if idx <= #current_libs then
                return idx
            end
        end
        return nil
    end

    -- Búsqueda e inserción/actualización de librerías
    local function add_new_library()
        M.pio_wildcard_nvim12_search(current_libs, function(selected_lib)
            if selected_lib and selected_lib ~= "" then
                local sel_base = get_lib_base_name(selected_lib)
                local existing_idx = nil

                for idx, lib in ipairs(current_libs) do
                    if get_lib_base_name(lib) == sel_base then
                        existing_idx = idx
                        break
                    end
                end

                if existing_idx then
                    if current_libs[existing_idx] == selected_lib then
                        vim.notify(
                            "La librería ya está presente con la misma versión: " .. selected_lib,
                            vim.log.levels.WARN
                        )
                    else
                        local old_ver = current_libs[existing_idx]
                        current_libs[existing_idx] = selected_lib
                        vim.notify(
                            string.format("Versión actualizada: %s ➔ %s", old_ver, selected_lib),
                            vim.log.levels.INFO
                        )
                    end
                else
                    table.insert(current_libs, selected_lib)
                    vim.notify("Librería agregada: " .. selected_lib, vim.log.levels.INFO)
                end

                render_ui()

                if win and vim.api.nvim_win_is_valid(win) then
                    vim.api.nvim_set_current_win(win)
                end
            end
        end)
    end

    -- Selector de versión usando M.pio_select_lib_version
    local function change_version_at_cursor()
        local idx = get_lib_idx_under_cursor()
        if not idx then
            return
        end

        local target_lib = current_libs[idx]
        M.pio_select_lib_version(target_lib, function(res)
            if res and res.action == "next" and res.value then
                current_libs[idx] = res.value
                render_ui()
                if win and vim.api.nvim_win_is_valid(win) then
                    vim.api.nvim_set_current_win(win)
                end
            end
        end)
    end

    local function show_info_at_cursor()
        local idx = get_lib_idx_under_cursor()
        if not idx then
            return
        end
        M.show_library_details(current_libs[idx], win, buf)
    end

    local function delete_at_cursor()
        local idx = get_lib_idx_under_cursor()
        if not idx then
            return
        end
        table.remove(current_libs, idx)
        render_ui()
    end

    local function handle_enter_or_l()
        local cursor = vim.api.nvim_win_get_cursor(win)
        local line_num = cursor[1]

        if line_num == 1 then
            add_new_library()
        elseif line_num == 2 then
            local changes = calculate_lib_changes(initial_copy, current_libs)
            finish({
                action = "next",
                value = current_libs,
                item = changes,
            })
        elseif line_num >= 4 and #current_libs > 0 then
            change_version_at_cursor()
        end
    end

    local function go_prev()
        finish({
            action = "prev",
            value = initial_copy,
            item = nil,
        })
    end

    local function cancel()
        finish({
            action = "cancel",
            value = nil,
            item = nil,
        })
    end

    local map_opts = { buffer = buf, silent = true, noremap = true, nowait = true }

    vim.keymap.set("n", "<CR>", handle_enter_or_l, map_opts)
    vim.keymap.set("n", "l", handle_enter_or_l, map_opts)
    vim.keymap.set("n", "a", add_new_library, map_opts)
    vim.keymap.set("n", "v", change_version_at_cursor, map_opts)
    vim.keymap.set("n", "i", show_info_at_cursor, map_opts)
    vim.keymap.set("n", "K", show_info_at_cursor, map_opts)
    vim.keymap.set("n", "d", delete_at_cursor, map_opts)
    vim.keymap.set("n", "x", delete_at_cursor, map_opts)
    vim.keymap.set("n", "h", go_prev, map_opts)
    vim.keymap.set("n", "q", cancel, map_opts)
    vim.keymap.set("n", "<Esc>", cancel, map_opts)
end
--------------------------------------------------------------------------------
-- COMANDOS Y TECLAS DE PRUEBA INTEGRADOS
--------------------------------------------------------------------------------
vim.api.nvim_create_user_command("PioSearch", function()
    M.pio_wildcard_nvim12_search({}, nil)
end, {})

vim.api.nvim_create_user_command("PioSearchTest", function()
    local mock_installed = {
        ["knolleary/PubSubClient"] = "2.8.0",
        ["bblanchon/ArduinoJson"] = "6.21.3",
    }
    M.pio_wildcard_nvim12_search(mock_installed, function(res)
        if res then
            vim.notify("✅ Librería: " .. res, vim.log.levels.INFO)
        end
    end)
end, {})

vim.api.nvim_create_user_command("PioSelectPortTest", function()
    M.pio_select_serial_port("COM3", function(res)
        if res then
            vim.notify("✅ Puerto: " .. (res == "" and "Auto" or res), vim.log.levels.INFO)
        else
            vim.notify("❌ Cancelado por el usuario", vim.log.levels.WARN)
        end
    end)
end, {})

vim.api.nvim_create_user_command("PioSelectBoardTest", function()
    local mis_favoritas = { "esp32dev", "uno", "pico", "nanoatmega328" }
    M.pio_select_board_snacks("esp32doit-devkit-v1", mis_favoritas, function(res)
        if res then
            vim.notify("✅ Placa: " .. res, vim.log.levels.INFO)
        end
    end)
end, {})

vim.api.nvim_create_user_command("PioClearBoardCache", function()
    BOARDS_CACHE = nil
    if vim.fn.filereadable(CACHE_FILE) == 1 then
        vim.fn.delete(CACHE_FILE)
    end
    vim.notify("🗑️ Caché eliminada. Se regenerará en la próxima ejecución.", vim.log.levels.WARN)
end, {})

vim.api.nvim_create_user_command("PioSelectBaudTest", function()
    M.pio_select_baud_rate("115200", function(res)
        if res then
            vim.notify("✅ Resultado:\n" .. res, vim.log.levels.INFO)
        else
            vim.notify("❌ Cancelado por el usuario", vim.log.levels.WARN)
        end
    end)
end, {})

vim.api.nvim_create_user_command("PioSelectFrameworkTest", function()
    M.pio_select_framework("esp32dev", "espidf", function(res)
        if res then
            vim.notify("✅ Resultado:\n" .. res, vim.log.levels.INFO)
        else
            vim.notify("❌ Cancelado por el usuario", vim.log.levels.WARN)
        end
    end)
end, {})

vim.api.nvim_create_user_command("PioTestESP32S3Flash", function()
    M.pio_select_esp32s3_flash("16MB", function(res)
        if res then
            vim.notify("✅ Selección de Flash:\n" .. res, vim.log.levels.INFO)
        else
            vim.notify("❌ Cancelado por el usuario", vim.log.levels.WARN)
        end
    end)
end, {})

vim.api.nvim_create_user_command("PioTestESP32S3Psram", function()
    M.pio_select_esp32s3_psram("qio_opi", function(res)
        if res then
            vim.notify("✅ Selección de PSRAM:\n" .. table.concat(res, "\n"), vim.log.levels.INFO)
        else
            vim.notify("❌ Cancelado por el usuario", vim.log.levels.WARN)
        end
    end)
end, {})

vim.api.nvim_create_user_command("PioTestESP32S3Config", function()
    M.pio_select_esp32s3_flash("8MB", function(flash_res)
        if not flash_res then
            vim.notify("❌ Flujo cancelado en Flash", vim.log.levels.WARN)
            return
        end

        M.pio_select_esp32s3_psram("qio_opi", function(psram_res)
            if not psram_res then
                vim.notify("❌ Flujo cancelado en PSRAM", vim.log.levels.WARN)
                return
            end

            local lines = { flash_res }
            for _, line in ipairs(psram_res) do
                table.insert(lines, line)
            end

            vim.notify(
                "⚙️ Líneas generadas para platformio.ini:\n\n" .. table.concat(lines, "\n"),
                vim.log.levels.INFO
            )
        end)
    end)
end, {})

vim.api.nvim_create_user_command("PioTestChangeLibVersion", function()
    M.pio_select_lib_version("bblanchon/ArduinoJson@^6.21.3", function(res)
        if res then
            vim.notify("✅ Nueva línea para lib_deps:\n  " .. res, vim.log.levels.INFO)
        else
            vim.notify("❌ Selección de versión cancelada", vim.log.levels.WARN)
        end
    end)
end, {})

--------------------------------------------------------------------------------
-- COMANDOS DE PRUEBA (TESTING)
--------------------------------------------------------------------------------
vim.api.nvim_create_user_command("PioTest", function()
    -- Encapsulamos la ejecución en una corrutina
    coroutine.wrap(function()
        local current_co = coroutine.running()

        local mock_installed = {
            ["bblanchon/arduinojson"] = "6.21.2",
            ["knolleary/pubsubclient"] = "2.8.0",
        }

        print("1. Ejecutando búsqueda...")

        -- Lanzamos la búsqueda y congelamos SOLO esta corrutina (no Neovim)
        M.pio_wildcard_nvim12_search(mock_installed, function(res)
            coroutine.resume(current_co, res)
        end)

        -- EL CÓDIGO SE DETIENE AQUÍ HASTA QUE EL USUARIO SELECCIONE ALGO EN LA UI
        local resultado = coroutine.yield()

        -- A partir de aquí todo ocurre de forma estrictamente LINEL
        print("2. Respuesta recibida")

        if resultado then
            vim.notify("✅ Resultado devuelto: " .. resultado, vim.log.levels.INFO)
        else
            vim.notify("⚠️ Proceso cancelado o sin selección", vim.log.levels.WARN)
        end
    end)()
end, { desc = "Probar buscador de librerías PIO de forma secuencial" })

--------------------------------------------------------------------------------
-- COMANDO DE PRUEBA: SELECTOR DE PUERTOS (SECUENCIAL CON ESTRUCTURA)
--------------------------------------------------------------------------------
vim.api.nvim_create_user_command("TestPioPort", function()
    coroutine.wrap(function()
        local current_co = coroutine.running()

        print("1. Abriendo selector de puertos serie...")

        -- Se abre la UI y la tabla de respuesta se envía al resume
        M.pio_select_serial_port("auto", function(res)
            coroutine.resume(current_co, res)
        end)

        -- EL CÓDIGO SE DETIENE AQUÍ HASTA QUE SE PRESIONE UNA TECLA DE NAVEGACIÓN O ACCIÓN
        local res = coroutine.yield()

        print("2. Respuesta recibida")

        if not res then
            vim.notify("⚠️ Error: No se recibió ninguna tabla de respuesta", vim.log.levels.ERROR)
            return
        end

        -- Evaluamos la acción solicitada por el usuario
        if res.action == "next" then
            vim.notify(
                string.format("✅ [Siguiente]\nPuerto: [%s]\nValor ini: [%s]", res.port, res.value),
                vim.log.levels.INFO
            )
        elseif res.action == "prev" then
            vim.notify("⬅️ [Anterior] Regresar al paso anterior en el flujo", vim.log.levels.WARN)
        elseif res.action == "cancel" then
            vim.notify("🚫 [Cancelar] Proceso abortado o panel cerrado", vim.log.levels.WARN)
        end
    end)()
end, { desc = "Probar selector de puertos serie con objeto de respuesta estructurado" })

--------------------------------------------------------------------------------
-- COMANDO DE PRUEBA: SELECTOR DE PLACAS (SECUENCIAL CON ESTRUCTURA)
--------------------------------------------------------------------------------
vim.api.nvim_create_user_command("TestPioBoard", function()
    coroutine.wrap(function()
        local current_co = coroutine.running()

        print("1. Abriendo selector de placas PlatformIO...")

        -- Se abre la UI y la tabla de respuesta se envía al resume
        M.pio_select_board_snacks("esp32dev", function(res)
            coroutine.resume(current_co, res)
        end)

        -- EL CÓDIGO SE DETIENE AQUÍ HASTA QUE SE PRESIONE UNA TECLA DE NAVEGACIÓN O SELECCIÓN
        local res = coroutine.yield()

        print("2. Respuesta recibida")

        if not res then
            vim.notify("⚠️ Error: No se recibió ninguna tabla de respuesta", vim.log.levels.ERROR)
            return
        end

        print(vim.inspect(res.item))

        -- Evaluamos la acción solicitada por el usuario
        if res.action == "next" then
            local details = res.item and string.format("\nMCU: %s | Plataforma: %s", res.item.mcu, res.item.platform)
                or ""
            vim.notify(
                string.format(
                    "✅ [Siguiente]\nPlaca: [%s]\nValor ini: [%s]%s",
                    tostring(res.board),
                    tostring(res.value),
                    details
                ),
                vim.log.levels.INFO
            )
        elseif res.action == "prev" then
            vim.notify(
                string.format(
                    "⬅️ [Anterior] Regresar al paso anterior en el flujo\nPlaca previa retenida: [%s]",
                    tostring(res.board)
                ),
                vim.log.levels.WARN
            )
        elseif res.action == "cancel" then
            vim.notify("🚫 [Cancelar] Proceso abortado o picker cerrado", vim.log.levels.WARN)
        end
    end)()
end, { desc = "Probar selector de placas PlatformIO con objeto de respuesta estructurado" })

--------------------------------------------------------------------------------
-- COMANDO DE PRUEBA: SELECTOR DE VELOCIDAD SERIAL (SECUENCIAL CON ESTRUCTURA)
--------------------------------------------------------------------------------
vim.api.nvim_create_user_command("TestPioBaudRate", function()
    coroutine.wrap(function()
        local current_co = coroutine.running()

        print("1. Abriendo selector de velocidad serial...")

        -- Se abre la UI y la tabla de respuesta se envía al resume
        M.pio_select_baud_rate("115200", function(res)
            coroutine.resume(current_co, res)
        end)

        -- EL CÓDIGO SE DETIENE AQUÍ HASTA QUE SE PRESIONE UNA TECLA DE NAVEGACIÓN O SELECCIÓN
        local res = coroutine.yield()

        print("2. Respuesta recibida")

        if not res then
            vim.notify("⚠️ Error: No se recibió ninguna tabla de respuesta", vim.log.levels.ERROR)
            return
        end

        if res.item then
            print("Detalles del item seleccionado:")
            print(vim.inspect(res.item))
        end

        -- Evaluamos la acción solicitada por el usuario
        if res.action == "next" then
            local details = res.item and string.format("\nDescripción: %s", res.item.desc) or ""
            vim.notify(
                string.format(
                    "✅ [Siguiente]\nVelocidad: [%s baud]\nValor ini: [%s]%s",
                    tostring(res.rate),
                    tostring(res.value),
                    details
                ),
                vim.log.levels.INFO
            )
        elseif res.action == "prev" then
            vim.notify(
                string.format(
                    "⬅️ [Anterior] Regresar al paso anterior en el flujo\nVelocidad previa retenida: [%s baud]",
                    tostring(res.rate)
                ),
                vim.log.levels.WARN
            )
        elseif res.action == "cancel" then
            vim.notify("🚫 [Cancelar] Proceso abortado o picker cerrado", vim.log.levels.WARN)
        end
    end)()
end, { desc = "Probar selector de velocidad serial con objeto de respuesta estructurado" })

--------------------------------------------------------------------------------
-- COMANDO DE PRUEBA: SELECTOR DE FRAMEWORK (SECUENCIAL CON ESTRUCTURA)
--------------------------------------------------------------------------------
vim.api.nvim_create_user_command("TestPioFramework", function()
    coroutine.wrap(function()
        local current_co = coroutine.running()

        print("1. Abriendo selector de framework...")

        -- Se abre la UI indicando la placa 'esp32dev' y 'arduino' como framework por defecto
        M.pio_select_framework("esp32dev", "arduino", function(res)
            coroutine.resume(current_co, res)
        end)

        -- EL CÓDIGO SE DETIENE AQUÍ HASTA QUE SE PRESIONE UNA TECLA DE NAVEGACIÓN O SELECCIÓN
        local res = coroutine.yield()

        print("2. Respuesta recibida")

        if not res then
            vim.notify("⚠️ Error: No se recibió ninguna tabla de respuesta", vim.log.levels.ERROR)
            return
        end

        if res.item then
            print("Detalles del item seleccionado:")
            print(vim.inspect(res.item))
        end

        -- Evaluamos la acción solicitada por el usuario
        if res.action == "next" then
            local details = res.item and string.format("\nDescripción: %s", res.item.desc) or ""
            vim.notify(
                string.format(
                    "✅ [Siguiente]\nFramework: [%s]\nValor ini: [%s]%s",
                    tostring(res.framework),
                    tostring(res.value),
                    details
                ),
                vim.log.levels.INFO
            )
        elseif res.action == "prev" then
            vim.notify(
                string.format(
                    "⬅️ [Anterior] Regresar al paso anterior en el flujo\nFramework previo retenido: [%s]",
                    tostring(res.framework)
                ),
                vim.log.levels.WARN
            )
        elseif res.action == "cancel" then
            vim.notify("🚫 [Cancelar] Proceso abortado o picker cerrado", vim.log.levels.WARN)
        end
    end)()
end, { desc = "Probar selector de framework con objeto de respuesta estructurado" })

--------------------------------------------------------------------------------
-- COMANDO DE PRUEBA: SELECTOR DE FLASH ESP32-S3 (SECUENCIAL CON ESTRUCTURA)
--------------------------------------------------------------------------------
vim.api.nvim_create_user_command("TestPioEsp32s3Flash", function()
    coroutine.wrap(function()
        local current_co = coroutine.running()

        print("1. Abriendo selector de memoria Flash ESP32-S3...")

        -- Se abre la UI indicando '8MB' como tamaño por defecto
        M.pio_select_esp32s3_flash("8MB", function(res)
            coroutine.resume(current_co, res)
        end)

        -- EL CÓDIGO SE DETIENE AQUÍ HASTA QUE SE PRESIONE UNA TECLA DE NAVEGACIÓN O SELECCIÓN
        local res = coroutine.yield()

        print("2. Respuesta recibida")

        if not res then
            vim.notify("⚠️ Error: No se recibió ninguna tabla de respuesta", vim.log.levels.ERROR)
            return
        end

        if res.item then
            print("Detalles del item seleccionado:")
            print(vim.inspect(res.item))
        end

        -- Evaluamos la acción solicitada por el usuario
        if res.action == "next" then
            local details = res.item and string.format("\nDescripción: %s", res.item.desc) or ""
            vim.notify(
                string.format(
                    "✅ [Siguiente]\nFlash Size: [%s]\nValor ini: [%s]%s",
                    tostring(res.flash_size),
                    tostring(res.value),
                    details
                ),
                vim.log.levels.INFO
            )
        elseif res.action == "prev" then
            vim.notify(
                string.format(
                    "⬅️ [Anterior] Regresar al paso anterior en el flujo\nFlash previa retenida: [%s]",
                    tostring(res.flash_size)
                ),
                vim.log.levels.WARN
            )
        elseif res.action == "cancel" then
            vim.notify("🚫 [Cancelar] Proceso abortado o picker cerrado", vim.log.levels.WARN)
        end
    end)()
end, { desc = "Probar selector de Flash ESP32-S3 con objeto de respuesta estructurado" })

--------------------------------------------------------------------------------
-- COMANDO DE PRUEBA: SELECTOR DE PSRAM ESP32-S3 (SECUENCIAL CON ESTRUCTURA)
--------------------------------------------------------------------------------
vim.api.nvim_create_user_command("TestPioEsp32s3Psram", function()
    coroutine.wrap(function()
        local current_co = coroutine.running()

        print("1. Abriendo selector de memoria PSRAM ESP32-S3...")

        -- Se abre la UI indicando 'qio_opi' como tipo por defecto
        M.pio_select_esp32s3_psram("qio_opi", function(res)
            coroutine.resume(current_co, res)
        end)

        -- EL CÓDIGO SE DETIENE AQUÍ HASTA QUE SE PRESIONE UNA TECLA DE NAVEGACIÓN O SELECCIÓN
        local res = coroutine.yield()

        print("2. Respuesta recibida")

        if not res then
            vim.notify("⚠️ Error: No se recibió ninguna tabla de respuesta", vim.log.levels.ERROR)
            return
        end

        if res.item then
            print("Detalles del item seleccionado:")
            print(vim.inspect(res.item))
        end

        -- Evaluamos la acción solicitada por el usuario
        if res.action == "next" then
            local details = res.item and string.format("\nNombre: %s\nDescripción: %s", res.item.name, res.item.desc)
                or ""
            vim.notify(
                string.format(
                    "✅ [Siguiente]\nRAM: [%s] | Tipo: [%s]\nLíneas ini:\n%s%s",
                    tostring(res.ram_size),
                    tostring(res.mem_type),
                    tostring(res.value),
                    details
                ),
                vim.log.levels.INFO
            )
        elseif res.action == "prev" then
            vim.notify(
                string.format(
                    "⬅️ [Anterior] Regresar al paso anterior en el flujo\nTipo PSRAM previo retenido: [%s]",
                    tostring(res.mem_type)
                ),
                vim.log.levels.WARN
            )
        elseif res.action == "cancel" then
            vim.notify("🚫 [Cancelar] Proceso abortado o picker cerrado", vim.log.levels.WARN)
        end
    end)()
end, { desc = "Probar selector de PSRAM ESP32-S3 con objeto de respuesta estructurado" })

--------------------------------------------------------------------------------
-- COMANDO DE PRUEBA: SELECTOR / CAMBIO DE VERSIÓN DE LIBRERÍA (SECUENCIAL CON ESTRUCTURA)
--------------------------------------------------------------------------------
vim.api.nvim_create_user_command("TestPioSelectLibVersion", function()
    coroutine.wrap(function()
        local current_co = coroutine.running()

        print("1. Buscando versiones para la librería de prueba...")

        -- Se abre la UI consultando 'bblanchon/ArduinoJson@6.21.3'
        M.pio_select_lib_version("bblanchon/ArduinoJson@6.21.3", function(res)
            coroutine.resume(current_co, res)
        end)

        -- EL CÓDIGO SE DETIENE AQUÍ HASTA QUE SE PRESIONE UNA TECLA DE NAVEGACIÓN O SELECCIÓN
        local res = coroutine.yield()

        print("2. Respuesta recibida")

        if not res then
            vim.notify("⚠️ Error: No se recibió ninguna tabla de respuesta", vim.log.levels.ERROR)
            return
        end

        if res.item then
            print("Detalles del item seleccionado:")
            print(vim.inspect(res.item))
        end

        -- Evaluamos la acción solicitada por el usuario
        if res.action == "next" then
            vim.notify(
                string.format(
                    "✅ [Siguiente]\nLibrería: [%s]\nVersión: [%s]\nValor ini: [%s]",
                    tostring(res.lib_name),
                    tostring(res.version),
                    tostring(res.value)
                ),
                vim.log.levels.INFO
            )
        elseif res.action == "prev" then
            vim.notify(
                string.format(
                    "⬅️ [Anterior] Regresar al paso anterior en el flujo\nLibrería/versión previa retenida: [%s]",
                    tostring(res.lib_name or res.value)
                ),
                vim.log.levels.WARN
            )
        elseif res.action == "cancel" then
            vim.notify("🚫 [Cancelar] Proceso abortado o selector cerrado", vim.log.levels.WARN)
        end
    end)()
end, { desc = "Probar selector de versión de librería con objeto de respuesta estructurado" })

--------------------------------------------------------------------------------
-- COMANDO DE PRUEBA: MOSTRAR DETALLES DE LIBRERÍA
--------------------------------------------------------------------------------
vim.api.nvim_create_user_command("TestPioShowLibDetails", function()
    print("1. Cargando panel de detalles para 'bblanchon/ArduinoJson@6.21.3'...")

    -- Se abre el panel pasando el identificador completo de la librería
    M.show_library_details("bblanchon/ArduinoJson@6.21.3")
end, { desc = "Probar vista detallada de información de librería PlatformIO" })

--------------------------------------------------------------------------------
-- COMANDO DE PRUEBA: GESTOR DE LIBRERÍAS INSTALADAS
--------------------------------------------------------------------------------
vim.api.nvim_create_user_command("TestPioManageInstalledLibs", function()
    coroutine.wrap(function()
        local current_co = coroutine.running()

        local initial_test_list = {
            "bblanchon/ArduinoJson@^6.21.3",
            "knolleary/PubSubClient@^2.8",
        }

        print("Abriendo gestor de librerías...")

        M.pio_manage_installed_libs(initial_test_list, function(res)
            coroutine.resume(current_co, res)
        end)

        local res = coroutine.yield()

        print("\n--- Resultado del Gestor ---")
        print("Acción realizada:", res and res.action)
        print("Lista final de librerías:")
        print(vim.inspect(res and res.value))

        if res and res.item then
            print("\nDetalle de cambios (item):")
            print(vim.inspect(res.item))
        end
    end)()
end, { desc = "Probar gestor interactivo de librerías instaladas" })

--------------------------------------------------------------------------------
-- COMANDO DE PRUEBA: BUSCADOR DE LIBRERÍAS PLATFORMIO
--------------------------------------------------------------------------------
vim.api.nvim_create_user_command("TestPioSearchLibs", function()
    coroutine.wrap(function()
        local current_co = coroutine.running()

        local initial_test_list = {
            "bblanchon/ArduinoJson@6.21.3",
            "knolleary/PubSubClient@2.8",
        }

        print("Iniciando buscador de librerías PlatformIO...")

        M.pio_wildcard_nvim12_search(initial_test_list, function(res)
            coroutine.resume(current_co, res)
        end)

        local res = coroutine.yield()

        print("\n--- Resultado de la Búsqueda ---")
        if res then
            print("Librería elegida (lista devuelta):")
            print(vim.inspect(res))
        else
            print("Operación cancelada o sin selección.")
        end
    end)()
end, { desc = "Probar buscador interactivo de librerías PlatformIO" })

return M
