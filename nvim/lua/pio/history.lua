local M = {}

-- Ubicación nativa multiplataforma de Neovim
local HISTORY_FILE = vim.fn.stdpath("data") .. "/pio_board_history.json"
local MAX_HISTORY = 10

--- Carga el historial desde el archivo JSON
--- @return table Lista de IDs de placas usadas recientemente
function M.load()
    local f = io.open(HISTORY_FILE, "r")
    if not f then
        return {}
    end

    local content = f:read("*a")
    f:close()

    if not content or content == "" then
        return {}
    end

    local ok, decoded = pcall(vim.json.decode, content)
    if ok and type(decoded) == "table" then
        return decoded
    end

    return {}
end

--- Agrega o mueve una placa al inicio del historial
--- @param board string|table Puede ser el ID ("esp32-s3-devkitc-1") o una tabla devuelta por la UI
function M.add(board)
    if not board then
        return
    end

    local board_id = type(board) == "table" and (board.id or board.value or board[1]) or tostring(board)
    board_id = board_id:gsub("^%s+", ""):gsub("%s+$", "")

    if board_id == "" then
        return
    end

    local current = M.load()
    local new_history = { board_id }

    -- Filtrar duplicados y mantener solo las últimas N placas
    for _, item in ipairs(current) do
        local item_id = type(item) == "table" and (item.id or item.value or item[1]) or tostring(item)
        if item_id ~= board_id and #new_history < MAX_HISTORY then
            table.insert(new_history, item_id)
        end
    end

    -- Guardar de forma atómica en disco
    local ok, json_str = pcall(vim.json.encode, new_history)
    if ok then
        local f = io.open(HISTORY_FILE, "w")
        if f then
            f:write(json_str)
            f:close()
        end
    end
end

return M
