local M = {}

local function parse_ini(filepath)
    local sections = {}
    local section_order = {}
    local current_section = nil

    local f = io.open(filepath, "r")
    if not f then
        return sections, section_order
    end

    for line in f:lines() do
        if line:match("^%s*;") or line:match("^%s*#") then
            goto continue
        end

        local s = line:match("^%s*%[([^%]]+)%]%s*$")
        if s then
            current_section = s:match("^%s*(.-)%s*$")
            if not sections[current_section] then
                sections[current_section] = { order = {}, values = {} }
                table.insert(section_order, current_section)
            end
            goto continue
        end

        if current_section then
            local k, v = line:match("^%s*([^=]+)=(.+)$")
            if k and v then
                k = k:match("^%s*(.-)%s*$"):lower()
                v = v:match("^%s*(.-)%s*$")

                local sec = sections[current_section]
                local found = false
                for _, existing_k in ipairs(sec.order) do
                    if existing_k == k then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(sec.order, k)
                end

                sec.values[k] = v
            end
        end
        ::continue::
    end
    f:close()

    return sections, section_order
end

local function map_config_to_pio_keys(config)
    local pio_keys = {
        board = config.board,
        framework = config.framework,
    }

    if config.port and config.port ~= "auto" and config.port ~= "" then
        pio_keys.upload_port = config.port
        pio_keys.monitor_port = config.port
    end

    if config.baud and config.baud ~= "" then
        pio_keys.monitor_speed = config.baud
    end

    if config.board and config.board:match("esp32%-s3") then
        if config.flash and config.flash ~= "default" and config.flash ~= "" then
            pio_keys["board_build.flash_size"] = config.flash
        end

        local flags = {}
        if config.psram and config.psram ~= "disabled" and config.psram ~= "none" and config.psram ~= "" then
            table.insert(flags, "-DBOARD_HAS_PSRAM")

            local clean_psram = tostring(config.psram):match("^%s*([a-z0-9_]+)")
            if clean_psram and clean_psram ~= "none" then
                pio_keys["board_build.arduino.memory_type"] = clean_psram
            end
        end

        -- Formateamos build_flags como lista multilínea si hay al menos un flag
        if #flags > 0 then
            pio_keys["build_flags"] = "\n    " .. table.concat(flags, "\n    ")
        end
    end

    if config.libs and type(config.libs) == "table" and #config.libs > 0 then
        pio_keys["lib_deps"] = "\n    " .. table.concat(config.libs, "\n    ")
    end

    return pio_keys
end

function M.update_platformio_ini(filepath, config)
    local sections, section_order = parse_ini(filepath)
    local target_env = "env:" .. (config.board or "unknown")

    local clean_order = {}
    local clean_sections = {}

    for _, sname in ipairs(section_order) do
        if not sname:match("^env:") or sname == target_env then
            table.insert(clean_order, sname)
            clean_sections[sname] = sections[sname]

            if clean_sections[sname].values then
                clean_sections[sname].values["libs"] = nil
                clean_sections[sname].values["port"] = nil
            end
        end
    end

    sections = clean_sections
    section_order = clean_order

    if not sections[target_env] then
        sections[target_env] = { order = {}, values = {} }
        local platform = "espressif32"
        if config.board:match("uno") or config.board:match("nano") or config.board:match("mega") then
            platform = "atmelavr"
        end
        table.insert(sections[target_env].order, "platform")
        sections[target_env].values["platform"] = platform
        table.insert(section_order, target_env)
    end

    if config.port == "auto" then
        sections[target_env].values["upload_port"] = nil
        sections[target_env].values["monitor_port"] = nil
    end

    -- PURGA EXTREMA: Destruimos cualquier rastro anterior de PSRAM (flags y memory_type)
    local sec = sections[target_env]
    local keys_to_purge = {
        ["build_flags"] = true,
        ["board_build.arduino.memory_type"] = true,
    }

    local new_order = {}
    for _, k in ipairs(sec.order) do
        if not keys_to_purge[k] then
            table.insert(new_order, k)
        end
    end
    sec.order = new_order
    sec.values["build_flags"] = nil
    sec.values["board_build.arduino.memory_type"] = nil

    local new_keys = map_config_to_pio_keys(config)
    for k, v in pairs(new_keys) do
        local found = false
        for _, existing_k in ipairs(sec.order) do
            if existing_k == k then
                found = true
                break
            end
        end
        if not found then
            table.insert(sec.order, k)
        end
        sec.values[k] = v
    end

    local out = io.open(filepath, "w")
    if not out then
        return false
    end

    out:write("; PlatformIO Project Configuration File\n")
    out:write("; Generado por Neovim PIO Plugin\n\n")

    local printed_sections = {}
    for _, sname in ipairs(section_order) do
        if not printed_sections[sname] then
            out:write(string.format("[%s]\n", sname))
            local current_sec = sections[sname]

            local printed_keys = {}
            for _, k in ipairs(current_sec.order) do
                local v = current_sec.values[k]
                if v and v ~= "" and not printed_keys[k] then
                    -- Si la clave es multilínea (empieza por \n), no le quitamos los saltos de línea
                    if tostring(v):sub(1, 1) == "\n" then
                        out:write(string.format("%s =%s\n", k, v))
                    else
                        local clean_v = tostring(v):gsub("[\r\n]+", " ")
                        out:write(string.format("%s = %s\n", k, clean_v))
                    end
                    printed_keys[k] = true
                end
            end

            out:write("\n")
            printed_sections[sname] = true
        end
    end

    out:close()
    return true
end

return M
