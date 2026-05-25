return {
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
            { "theHamsta/nvim-dap-virtual-text", opts = {} },
            "jay-babu/mason-nvim-dap.nvim",
        },
        keys = {
            {
                "<F5>",
                function()
                    require("dap").continue()
                end,
                desc = "DAP: Iniciar/Continuar",
            },
            {
                "<F10>",
                function()
                    require("dap").step_over()
                end,
                desc = "DAP: Saltar Línea (Step Over)",
            },
            {
                "<F11>",
                function()
                    require("dap").step_into()
                end,
                desc = "DAP: Entrar a Función (Step Into)",
            },
            {
                "<F12>",
                function()
                    require("dap").step_out()
                end,
                desc = "DAP: Salir de Función (Step Out)",
            },
            {
                "<leader>db",
                function()
                    require("dap").toggle_breakpoint()
                end,
                desc = "DAP: Alternar Breakpoint",
            },
            {
                "<leader>dB",
                function()
                    require("dap").set_breakpoint(vim.fn.input("Condición del Breakpoint: "))
                end,
                desc = "DAP: Breakpoint Condicional",
            },
            {
                "<leader>dc",
                function()
                    require("dap").terminate() 
                    require("dapui").close()   
                end,
                desc = "DAP: Detener Depuración",
            },
            {
                "<leader>dr",
                function()
                    require("dap").repl.open()
                end,
                desc = "DAP: Abrir Consola REPL",
            },
            -- ✨ NUEVO ATAJO: Permite abrir o cerrar la interfaz gráfica a voluntad
            {
                "<leader>du",
                function()
                    require("dapui").toggle()
                end,
                desc = "DAP: Alternar Interfaz Visual (DAP UI)",
            },
        },
        config = function()
            local dap = require("dap")
            local dapui = require("dapui")
            local is_windows = vim.fn.has("win32") == 1

            ------------------------------------------------------------------
            -- 🤫 SILENCIAR ERROR DE CPPTOOLS
            ------------------------------------------------------------------
            local dap_utils = require("dap.utils")
            local original_dap_notify = dap_utils.notify
            dap_utils.notify = function(msg, level, opts)
                if type(msg) == "string" and msg:match("cppdbg") and msg:match("exited with 1") then
                    return 
                end
                original_dap_notify(msg, level, opts)
            end

            ------------------------------------------------------------------
            -- 🖥️ CONFIGURACIÓN DE LA INTERFAZ VISUAL (DAP UI)
            ------------------------------------------------------------------
            dapui.setup({
                icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
                layouts = {
                    {
                        elements = {
                            { id = "scopes", size = 0.40 },
                            { id = "breakpoints", size = 0.20 },
                            { id = "stacks", size = 0.20 },
                            { id = "watches", size = 0.20 },
                        },
                        size = 40,
                        position = "left",
                    },
                    {
                        elements = { { id = "repl", size = 0.5 }, { id = "console", size = 0.5 } },
                        size = 10,
                        position = "bottom",
                    },
                },
            })

            ------------------------------------------------------------------
            -- 🔄 SINCRONIZACIÓN SEGURA (Apertura Automática Únicamente)
            ------------------------------------------------------------------
            -- Eliminamos el cierre automático para evitar que Neovim crashee 
            -- al destruir las ventanas de golpe cuando termina el programa.
            -- Usa <leader>du o <leader>dc para cerrar la interfaz cuando quieras.
            dap.listeners.before.attach.dapui_config = function()
                dapui.open()
            end
            dap.listeners.before.launch.dapui_config = function()
                dapui.open()
            end

            ------------------------------------------------------------------
            -- 🎨 ICONOS ESTÉTICOS
            ------------------------------------------------------------------
            vim.fn.sign_define("DapBreakpoint", { text = "🔴", texthl = "DapBreakpoint", linehl = "", numhl = "" })
            vim.fn.sign_define("DapBreakpointCondition", { text = "🟡", texthl = "DapBreakpointCondition", linehl = "", numhl = "" })
            vim.fn.sign_define("DapStopped", { text = "▶️", texthl = "DapStopped", linehl = "Visual", numhl = "DapStopped" })

            ------------------------------------------------------------------
            -- 📦 MASON: ASEGURAR DEPENDENCIAS MULTIPLATAFORMA
            ------------------------------------------------------------------
            require("mason-nvim-dap").setup({
                ensure_installed = { "codelldb", "cpptools" },
                automatic_installation = true,
                handlers = {
                    function(config)
                        require("mason-nvim-dap").default_setup(config)
                    end,
                    cppdbg = function(config) end,
                },
            })

            ------------------------------------------------------------------
            -- 🚀 ADAPTADORES MANUALES: RUTAS ESTRICTAS Y NORMALIZADAS
            ------------------------------------------------------------------
            local extension = is_windows and ".exe" or ""
            local mason_base = vim.fn.stdpath("data") .. "/mason/packages"

            local codelldb_path = mason_base .. "/codelldb/extension/adapter/codelldb" .. extension
            local cpptools_path = mason_base .. "/cpptools/extension/debugAdapters/bin/OpenDebugAD7" .. extension

            if is_windows then
                codelldb_path = codelldb_path:gsub("/", "\\")
                cpptools_path = cpptools_path:gsub("/", "\\")
            end

            dap.adapters.codelldb = {
                type = "server",
                port = "${port}",
                executable = {
                    command = codelldb_path,
                    args = { "--port", "${port}" },
                    options = { detached = true },
                },
            }

            dap.adapters.cppdbg = {
                id = "cppdbg",
                type = "executable",
                command = cpptools_path,
                options = {
                    detached = not is_windows,
                },
            }

            ------------------------------------------------------------------
            -- 🛡️ FUNCIÓN DE VALIDACIÓN SEGURA PARA EJECUTABLES
            ------------------------------------------------------------------
            local path_separator = is_windows and "\\" or "/"

            local function pedir_ejecutable_seguro()
                local path = vim.fn.input({
                    prompt = "Ruta del ejecutable: ",
                    default = vim.fn.getcwd() .. path_separator,
                    completion = "file",
                })

                if path == "" then
                    vim.notify(" Depuración cancelada por el usuario.", vim.log.levels.WARN)
                    return require("dap").ABORT
                end

                if vim.fn.filereadable(path) == 0 then
                    vim.notify(" Error: El archivo no existe -> " .. path, vim.log.levels.ERROR)
                    return require("dap").ABORT
                end

                if is_windows and not path:match("%.exe$") then
                    vim.notify(" Cuidado: El archivo seleccionado no termina en .exe", vim.log.levels.WARN)
                end

                return path
            end

            ------------------------------------------------------------------
            -- ⚙️ CONFIGURACIONES DE LENGUAJE DINÁMICAS
            ------------------------------------------------------------------
            local c_cpp_config = {
                {
                    name = "Lanzar Ejecutable (Multiplataforma)",
                    type = is_windows and "cppdbg" or "codelldb",
                    request = "launch",
                    program = pedir_ejecutable_seguro,
                    cwd = "${workspaceFolder}",
                    stopOnEntry = false,
                    args = {},
                    runInTerminal = false,
                    MIMode = is_windows and "gdb" or nil,
                    miDebuggerPath = is_windows and "gdb.exe" or nil,
                },
            }

            dap.configurations.c = c_cpp_config
            dap.configurations.cpp = c_cpp_config

            dap.configurations.rust = {
                {
                    name = "Lanzar Ejecutable Rust",
                    type = "codelldb",
                    request = "launch",
                    program = pedir_ejecutable_seguro,
                    cwd = "${workspaceFolder}",
                    stopOnEntry = false,
                },
            }
        end,
    },
}
