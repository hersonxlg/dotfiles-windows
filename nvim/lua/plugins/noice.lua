-- =============================================================================
-- CONFIGURACIÓN DE BÚSQUEDA Y CONTADOR FLOTANTE (NOICE.NVIM + SNACKS.SCROLL)
-- =============================================================================

-- 🛠️ VARIABLES DE CONFIGURACIÓN PERSONALIZABLES
local CONFIG = {
    -- Prompt principal de búsqueda (cmdline centrado)
    cmdline = {
        row = "40%", -- Ubicación vertical centrada
        col = "50%", -- Ubicación horizontal centrada
        width = 60, -- Ancho de la ventana flotante
    },

    -- Panel flotante de contador sobre el cursor
    popup = {
        icon = " ", -- Ícono mostrado dentro del panel
        row = -3, -- Desfase vertical (-3 flota por encima sin tapar el texto)
        col = 0, -- Desfase horizontal respecto al cursor
        timeout = 2000, -- Tiempo en ms antes de ocultar el panel (2 segundos)
        scroll_debounce = 40, -- Tiempo en ms tras finalizar snacks.scroll para dibujar el panel
    },
}

return {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
        -- ---------------------------------------------------------------------
        -- 1. CONFIGURACIÓN DEL CMDLINE (PROMPT CENTRADO)
        -- ---------------------------------------------------------------------
        cmdline = {
            enabled = true,
            view = "cmdline_popup",
            format = {
                search_down = { kind = "search", pattern = "^/", icon = CONFIG.popup.icon, lang = "regex" },
                search_up = { kind = "search", pattern = "^%?", icon = CONFIG.popup.icon, lang = "regex" },
            },
        },

        -- ---------------------------------------------------------------------
        -- 2. VISTAS Y PANELES FLOTANTES
        -- ---------------------------------------------------------------------
        views = {
            -- Cuadro de entrada principal para / y ?
            cmdline_popup = {
                position = { row = CONFIG.cmdline.row, col = CONFIG.cmdline.col },
                size = { width = CONFIG.cmdline.width, height = "auto" },
                border = { style = "rounded" },
            },
            -- Panel del contador que persigue al cursor
            search_count_popup = {
                backend = "popup",
                relative = "cursor",
                position = { row = CONFIG.popup.row, col = CONFIG.popup.col },
                size = { width = "auto", height = "auto" },
                border = { style = "rounded", padding = { 0, 1 } },
                win_options = {
                    winhighlight = { Normal = "NormalFloat", FloatBorder = "FloatBorder" },
                },
            },
        },

        -- ---------------------------------------------------------------------
        -- 3. RUTAS DE MENSAJES Y FILTROS
        -- ---------------------------------------------------------------------
        routes = {
            -- Enruta nuestro mensaje personalizado al panel que persigue al cursor
            {
                filter = {
                    event = "msg_show",
                    find = CONFIG.popup.icon,
                },
                view = "search_count_popup",
            },
            -- Omite el conteo por defecto para evitar mensajes nativos duplicados
            {
                filter = { event = "msg_show", kind = "search_count" },
                opts = { skip = true },
            },
        },

        lsp = {
            override = {
                ["vim.lsp.util.convert_input_to_markdown_lines"] = false,
                ["vim.lsp.util.stylize_markdown"] = false,
                ["cmp.entry.get_documentation"] = false,
            },
        },
        presets = {
            command_palette = true,
            long_message_to_split = true,
            lsp_doc_border = true,
        },
    },

    -- -------------------------------------------------------------------------
    -- 4. LÓGICA DE EVENTOS Y MAPEOS DE TECLAS
    -- -------------------------------------------------------------------------
    config = function(_, opts)
        require("noice").setup(opts)

        local timer_id = 0

        --- Dispara el panel flotante y lo sincroniza con las animaciones de snacks.scroll
        local function trigger_search_popup()
            require("noice").cmd("dismiss")

            local augroup_id = vim.api.nvim_create_augroup("NoiceSearchScrollWait", { clear = true })
            local timer = vim.uv.new_timer()
            local done = false

            --- Obtiene los datos de búsqueda y renderiza el texto en el panel
            local function render()
                if done then
                    return
                end
                done = true

                if timer then
                    timer:stop()
                    timer:close()
                end
                pcall(vim.api.nvim_del_augroup_by_id, augroup_id)

                local pattern = vim.fn.getreg("/")
                local count = vim.fn.searchcount({ recompute = 1 })

                if count and count.total > 0 then
                    local text = string.format("%s %s  [%d/%d]", CONFIG.popup.icon, pattern, count.current, count.total)
                    vim.api.nvim_echo({ { text, "Normal" } }, false, {})
                end
            end

            --- Reinicia el temporizador mientras la pantalla se esté moviendo
            local function reset_timer()
                if timer and not timer:is_closing() then
                    timer:stop()
                    timer:start(CONFIG.popup.scroll_debounce, 0, vim.schedule_wrap(render))
                end
            end

            -- Captura cada fotograma de desplazamiento generado por snacks.scroll
            vim.api.nvim_create_autocmd("WinScrolled", {
                group = augroup_id,
                callback = reset_timer,
            })

            -- Ejecución inicial para saltos instantáneos donde no hay scroll
            reset_timer()

            -- Auto-cierre del panel flotante tras inactividad
            timer_id = timer_id + 1
            local current_id = timer_id
            vim.defer_fn(function()
                if timer_id == current_id then
                    -- Previene cerrar el cmdline si el usuario volvió a presionar '/'
                    if vim.fn.getcmdtype() == "" then
                        require("noice").cmd("dismiss")
                    end
                end
            end, CONFIG.popup.timeout)
        end

        --- Wrapper para remapar la navegación entre coincidencias (n / N)
        local function clean_search_jump(key)
            return function()
                trigger_search_popup()
                return key
            end
        end

        -- Mapeos en modo normal (Navegación)
        vim.keymap.set(
            "n",
            "n",
            clean_search_jump("n"),
            { expr = true, silent = true, desc = "Siguiente coincidencia" }
        )
        vim.keymap.set("n", "N", clean_search_jump("N"), { expr = true, silent = true, desc = "Anterior coincidencia" })

        -- Mapeo en línea de comandos (Confirmación con Enter)
        vim.keymap.set("c", "<CR>", function()
            local cmd_type = vim.fn.getcmdtype()
            if cmd_type == "/" or cmd_type == "?" then
                trigger_search_popup()
            end
            return "<CR>"
        end, { expr = true, silent = true, desc = "Confirmar búsqueda y mostrar panel" })
    end,
}

--return {

--    "folke/noice.nvim",
--    event = "VeryLazy",
--    -- Ya no requiere nui.nvim ni nvim-notify como dependencias
--    opts = {
--        lsp = {
--            override = {
--                ["vim.lsp.util.convert_input_to_markdown_lines"] = false,
--                ["vim.lsp.util.stylize_markdown"] = false,
--                ["cmp.entry.get_documentation"] = false,
--            },
--        },
--        presets = {
--            command_palette = true, -- Mantiene la barra flotante de ':'
--            long_message_to_split = true,
--            lsp_doc_border = true,
--        },
--    },
--}
