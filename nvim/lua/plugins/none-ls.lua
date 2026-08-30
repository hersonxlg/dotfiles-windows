return {
    "nvimtools/none-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        local null_ls = require("null-ls")
        local helpers = require("null-ls.helpers")

        -- Ruta del script de MATLAB
        local matlab_script = vim.fn.stdpath("data") .. "/matlab-formatter/formatter/matlab_formatter.py"

        -- Crear builtin personalizado para MATLAB Formatter
        local matlab_formatter = helpers.make_builtin({
            name = "matlab-formatter",
            method = null_ls.methods.FORMATTING,
            filetypes = { "matlab" },
            generator_opts = {
                command = "python",
                args = {
                    matlab_script,
                    "$FILENAME",
                },
                to_stdin = false,
            },
            factory = helpers.generator_factory,
        })

        -- Crear builtin personalizado para ASM Formatter (asmfmt)
        local asm_formatter = {
            name = "asmfmt",
            method = null_ls.methods.FORMATTING,
            filetypes = { "asm", "nasm", "gas", "armasm", "avr" },
            generator = helpers.formatter_factory({
                command = "asmfmt",
                args = {},
                to_stdin = true,
            }),
        }

        null_ls.setup({
            sources = {
                ----------------------------------------------
                -- Formateadores integrados con reglas dinámicas
                ----------------------------------------------
                null_ls.builtins.formatting.stylua.with({
                    extra_args = function()
                        local is_windows = vim.fn.has("win32") == 1
                        local line_ending_value = is_windows and "Windows" or "Unix"

                        return {
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
                        }
                    end,
                }),

                null_ls.builtins.formatting.prettier,

                ----------------------------------------------
                -- Formateador para C / C++ (clang-format)
                ----------------------------------------------
                null_ls.builtins.formatting.clang_format.with({
                    extra_args = {
                        "--style={BasedOnStyle: LLVM, IndentWidth: 4, UseTab: Never, ColumnLimit: 120}",
                    },
                }),

                -- Formateador para Python
                null_ls.builtins.formatting.black,

                ----------------------------------------------
                -- kotlin: Formateador para Kotlin (ktlint)
                ----------------------------------------------
                null_ls.builtins.formatting.ktlint,

                asm_formatter,
                matlab_formatter,



            },
        })

        -- Mapeo para formatear (Null-ls)
        vim.keymap.set("n", "<leader>cf", function()
            local ft = vim.bo.filetype

            local preferred = {
                lua = "null-ls",
                cpp = "null-ls",
                c = "null-ls",
                matlab = "null-ls",
                asm = "null-ls",
                ps1 = "powershell_es",
                psm1 = "powershell_es",
                python = "null-ls",
                toml = "tombi",
                -- rust
                rust = "rust_analyzer",
                -- kotlin
                kt = "null-ls",
                kts = "null-ls",
            }

            local wanted = preferred[ft]

            vim.lsp.buf.format({
                bufnr = 0,
                async = false,
                timeout_ms = 3000,

                filter = function(client)
                    if wanted then
                        return client.name == wanted
                    end
                    return client.name == "null-ls" or client.name == "none-ls"
                end,
            })
        end, { desc = "Formatear código" })
    end,
}
