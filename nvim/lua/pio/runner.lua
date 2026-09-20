local M = {}

function M.run_cmd_with_terminal(cmd, args, opts, cb)
    opts = opts or {}
    args = args or {}

    -- 1. Crear el búfer y calcular dimensiones para la ventana flotante
    local buf = vim.api.nvim_create_buf(false, true)
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.6)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
        title = " PlatformIO Progress ",
        title_pos = "center",
    })

    -- 2. Construir la lista del comando para la terminal
    local cmd_list = { cmd }
    for _, arg in ipairs(args) do
        table.insert(cmd_list, arg)
    end

    -- Función auxiliar para cerrar la ventana limpiamente
    local function close_window()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    -- 3. Iniciar la terminal interactiva (PTY) con termopen
    local job_id = vim.fn.termopen(cmd_list, {
        cwd = opts.cwd,
        on_exit = function(_, exit_code, _)
            vim.schedule(function()
                local success = (exit_code == 0)
                if success then
                    vim.notify("Proceso finalizado correctamente.", vim.log.levels.INFO)
                    close_window()
                else
                    vim.notify(
                        "Proceso interrumpido o fallido (Código: "
                            .. exit_code
                            .. "). Presiona <Esc> o 'q' para cerrar.",
                        vim.log.levels.ERROR
                    )

                    -- Teclas para cerrar manualmente si hubo un error y se desea examinar el log
                    vim.keymap.set("n", "q", close_window, { buffer = buf })
                    vim.keymap.set("n", "<Esc>", close_window, { buffer = buf })
                end

                if cb then
                    cb(success)
                end
            end)
        end,
    })

    if job_id <= 0 then
        vim.notify("Error al iniciar el proceso en la terminal de Neovim.", vim.log.levels.ERROR)
        close_window()
        if cb then
            cb(false)
        end
        return
    end

    -- 4. Cancelación manual con <C-c> deteniendo el proceso activo
    vim.keymap.set("n", "<C-c>", function()
        if job_id > 0 then
            vim.fn.jobstop(job_id)
        end
        close_window()
        vim.notify("Proceso cancelado por el usuario.", vim.log.levels.WARN)
    end, { buffer = buf })
end

return M
