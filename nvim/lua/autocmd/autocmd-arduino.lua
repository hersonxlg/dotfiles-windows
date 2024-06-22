------------------------------------------------------------
-- Auto comandos:
------------------------------------------------------------


vim.g.data = 'hola'


function vim.g.read_file(file_path)
    local file = io.open(file_path, "r") -- Abrir el archivo en modo de lectura
    if not file then return nil end      -- Si el archivo no existe, retorna nil
    local content = file:read("*a")      -- Leer todo el contenido del archivo
    file:close()                         -- Cerrar el archivo
    return content                       -- Retornar el contenido del archivo
end

function vim.g.get_arduino_config()
    local current_buffer_dir = vim.fn.expand("%:p:h")
    local file = current_buffer_dir .. "\\config.json"
    if vim.fn.filereadable(file) == 0 then return nil end -- Si el archivo no existe, retorna nil
    local text_json = vim.g.read_file(file)
    local config = vim.fn.json_decode(text_json)
    return config
end



-- --------------------------------------------
--          config.json
-- --------------------------------------------
-- 
-- {
--     "board":"esp32:esp32",
--     "port":"COM3"
-- }
-- 
-- --------------------------------------------


function Compile(command)
    local comando = "" ..
        "echo '**************************';" ..
        "echo '         compilando...    ';" ..
        "echo '**************************';" ..
        "echo `n;" ..
        command
    Output_exec(comando)
end

function Upload(command)
    local comando = "" ..
        "echo '**************************';" ..
        "echo '         cargando...      ';" ..
        "echo '**************************';" ..
        "echo `n;" ..
        command
    Output_exec(comando)
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    pattern = { "*.ino" },
    callback = function(event)
        local current_buffer_dir = vim.fn.expand("%:p:h")
        local nombre = vim.fn.bufname("%")
        local config = vim.g.get_arduino_config()
        if (config) then
            vim.g.data = config
            local board = config['board']
            local puerto = config['port']
            local upload = string.format('arduino-cli upload -p %s --fqbn %s %s', puerto, board,
                nombre:gsub("\\", "\\\\"))
            local compilecmd = 'arduino-cli compile -b ' .. board .. " " .. nombre:gsub("\\", "\\\\")
            vim.g.compilecmd= compilecmd
            vim.keymap.set("n", "<leader>c", "<cmd>lua Compile(\"" .. compilecmd .. "\")<CR>", { noremap = true })
            vim.keymap.set("n", "<leader>u", "<cmd>lua Upload(\"" .. upload .. "\")<CR>", { noremap = true })
            --vim.keymap.set("n", "<leader>u", "<Cmd>TermExec cmd=\"clear && " .. upload .. "\"<CR>", { noremap = true })
            vim.keymap.set("n", "<leader>e", "<Cmd>new " .. current_buffer_dir .. "\\config.json<CR>", { noremap = true })
        end
    end
})
