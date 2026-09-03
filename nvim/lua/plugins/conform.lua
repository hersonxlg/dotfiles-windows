return {
    "stevearc/conform.nvim",
    -- 👇 ESTAS DOS LÍNEAS SON LA CLAVE 👇
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },

    opts = function()
        -- Evaluamos el SO una sola vez para las reglas de Stylua
        local is_windows = vim.fn.has("win32") == 1
        local line_ending_value = is_windows and "Windows" or "Unix"

        return {
            -- 1. Asignación de formateadores por tipo de archivo
            formatters_by_ft = {
                lua = { "stylua" },
                c = { "clang-format" },
                cpp = { "clang-format" },
                python = { "black" },
                kotlin = { "ktlint" },

                -- Prettier general
                javascript = { "prettier" },
                typescript = { "prettier" },
                html = { "prettier" },
                css = { "prettier" },
                json = { "prettier" },

                -- Ensamblador
                asm = { "asmfmt" },
                nasm = { "asmfmt" },
                gas = { "asmfmt" },
                armasm = { "asmfmt" },
                avr = { "asmfmt" },

                -- MATLAB
                matlab = { "matlab_formatter" },
            },

            -- 2. Configuración específica y formateadores personalizados
            formatters = {
                -- Reglas de Stylua (dinámicas según el OS)
                stylua = {
                    prepend_args = {
                        "--indent-type",
                        "Spaces",
                        "--indent-width",
                        "4",
                        "--column-width",
                        "120",
                        "--quote-style",
                        "AutoPreferDouble",
                        "--line-endings",
                        line_ending_value,
                    },
                },

                -- Reglas de C/C++
                ["clang-format"] = {
                    prepend_args = {
                        "--style={BasedOnStyle: LLVM, IndentWidth: 4, UseTab: Never, ColumnLimit: 120}",
                    },
                },

                -- Formateador personalizado para Ensamblador
                asmfmt = {
                    command = "asmfmt",
                    stdin = true,
                },

                -- Formateador personalizado para MATLAB
                matlab_formatter = {
                    command = "python",
                    args = {
                        vim.fn.stdpath("data") .. "/matlab-formatter/formatter/matlab_formatter.py",
                        "$FILENAME",
                    },
                    stdin = false,
                },
            },

            -- 3. Formateo al guardar
            format_on_save = {
                -- Tiempo máximo que Conform esperará al formateador antes de rendirse
                timeout_ms = 3000,
                -- Si no hay un formateador externo, usa el del servidor LSP
                lsp_fallback = true,
            },
        }
    end,
    keys = {
        {
            "<leader>cf",
            function()
                require("conform").format({
                    async = false,
                    timeout_ms = 3000,
                    lsp_fallback = true,
                })
            end,
            mode = { "n", "v" },
            desc = "Formatear código",
        },
    },
}
