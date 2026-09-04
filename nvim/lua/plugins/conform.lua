return {
    -- 1. Descarga automática de formateadores con Mason
    {
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        dependencies = { "williamboman/mason.nvim" },
        opts = {
            ensure_installed = {
                "stylua",
                "clang-format",
                "black",
                "isort",
                "ktlint",
                "prettier",
                "asmfmt",
                "shfmt",
                "taplo",
                "gersemi",
                "xmlformatter",
            },
            auto_update = true,
            run_on_start = true,
        },
    },

    -- 2. Motor de formateo (Conform)
    {
        "stevearc/conform.nvim",
        event = { "BufWritePre" },
        cmd = { "ConformInfo" },

        opts = function()
            local is_windows = vim.fn.has("win32") == 1
            local line_ending_value = is_windows and "Windows" or "Unix"

            return {
                formatters_by_ft = {
                    lua = { "stylua" },
                    c = { "clang-format" },
                    cpp = { "clang-format" },
                    cmake = { "gersemi" },

                    python = { "isort", "black" },

                    kotlin = { "ktlint" },
                    xml = { "xmlformatter" },

                    -- Prettier (JS, TS, HTML, CSS, JSON, YAML, Markdown)
                    javascript = { "prettier" },
                    typescript = { "prettier" },
                    html = { "prettier" },
                    css = { "prettier" },
                    json = { "prettier" },
                    yaml = { "prettier" },
                    markdown = { "prettier" },

                    -- Configuración / Shell
                    sh = { "shfmt" },
                    bash = { "shfmt" },
                    zsh = { "shfmt" },
                    toml = { "taplo" },

                    -- Ensamblador
                    asm = { "asmfmt" },
                    nasm = { "asmfmt" },
                    gas = { "asmfmt" },
                    armasm = { "asmfmt" },
                    avr = { "asmfmt" },

                    -- MATLAB
                    matlab = { "matlab_formatter" },
                },

                formatters = {
                    -- Stylua (4 espacios)
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

                    -- Prettier (Forzado a 4 espacios)
                    prettier = {
                        prepend_args = { "--tab-width", "4" },
                    },

                    -- Clang-format (4 espacios)
                    ["clang-format"] = {
                        prepend_args = {
                            "--style={BasedOnStyle: LLVM, IndentWidth: 4, UseTab: Never, ColumnLimit: 120}",
                        },
                    },

                    -- Shell Scripts (4 espacios)
                    shfmt = {
                        prepend_args = { "-i", "4", "-ci" },
                    },

                    -- TOML (Forzar arreglos y tablas inline en una sola línea)
                    -- TOML (Equilibrio: Líneas cortas en 1 fila, reglas complejas multilínea)
                    taplo = {
                        args = (function()
                            local opts = {
                                indent_string = "    ", -- Indentación de 4 espacios
                                indent_entries = true, -- Indentar entradas en tablas
                                indent_tables = true, -- Indentar sub-tablas
                                column_width = 120, -- Ancho estándar para colapsar solo lo que quepa
                                align_entries = false, -- No alinear signos '='
                                align_comments = true, -- Alinear comentarios
                                reorder_keys = false, -- Conservar orden de claves
                                array_auto_expand = true, -- Expande si la línea supera los 120 caracteres
                                array_auto_collapse = false, -- Respeta los saltos de línea manuales que hagas
                                compact_arrays = false, -- Espacios dentro de corchetes
                                compact_inline_tables = false, -- Espacios dentro de llaves
                            }

                            local args = { "fmt" }
                            for key, val in pairs(opts) do
                                table.insert(args, "-o")
                                table.insert(args, string.format("%s=%s", key, tostring(val)))
                            end
                            table.insert(args, "-")

                            return args
                        end)(),
                    },

                    -- XML (4 espacios)
                    xmlformatter = {
                        prepend_args = { "--indent", "4" },
                    },

                    asmfmt = {
                        command = "asmfmt",
                        stdin = true,
                    },

                    matlab_formatter = {
                        command = "python",
                        args = {
                            vim.fn.stdpath("data") .. "/matlab-formatter/formatter/matlab_formatter.py",
                            "$FILENAME",
                        },
                        stdin = false,
                    },
                },

                format_on_save = {
                    timeout_ms = 3000,
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
    },
}
