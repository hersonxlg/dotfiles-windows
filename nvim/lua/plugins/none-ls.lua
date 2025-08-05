-- lua/plugins/none-ls.lua
return {
    "nvimtools/none-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        local null_ls = require("null-ls")
        local helpers = require("null-ls.helpers")

        -- Crear builtin personalizado para MATLAB Formatter
        local matlab_formatter = helpers.make_builtin({
            name           = "matlab-formatter",
            method         = null_ls.methods.FORMATTING,
            filetypes      = { "matlab" },
            generator_opts = {
                command  = "python",
                args     = {
                    vim.fn.stdpath("data") .. "/matlab-formatter/formatter/matlab_formatter.py",
                    "$FILENAME",
                },
                to_stdin = false,
            },
            factory        = helpers.generator_factory,
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
                -- Formateadores integrados
                ----------------------------------------------
                null_ls.builtins.formatting.stylua,
                null_ls.builtins.formatting.prettier,
                ----------------------------------------------
                -- Formateador de ASM (asmfmt)
                ----------------------------------------------
                asm_formatter,
                ----------------------------------------------
                -- Formateador de MATLAB
                ----------------------------------------------
                matlab_formatter,
            },
        })

        -- Mapeo para formatear (Null-ls)
        vim.keymap.set("n", "<leader>gf", function()
            vim.lsp.buf.format({ async = true })
        end, { desc = "Formatear código (ASM/MATLAB/otros)" })
    end,
}



--    -- lua/plugins/none-ls.lua
--    return {
--      "nvimtools/none-ls.nvim",
--      dependencies = { "nvim-lua/plenary.nvim" },
--      config = function()
--        local null_ls = require("null-ls")
--        local helpers = require("null-ls.helpers")
--
--        -- Crear builtin personalizado para MATLAB Formatter
--        local matlab_formatter = helpers.make_builtin({
--          name        = "matlab-formatter",
--          method      = null_ls.methods.FORMATTING,
--          filetypes   = { "matlab" },
--          generator_opts = {
--            command  = "python",
--            args     = {
--              vim.fn.stdpath("data") .. "/matlab-formatter/formatter/matlab_formatter.py",
--              -- Aseguramos que la ruta use '/formatter/matlab_formatter.py'
--              "$FILENAME",
--            },
--            to_stdin = false,
--          },
--          factory = helpers.generator_factory,
--        })
--
--        null_ls.setup({
--          sources = {
--            ----------------------------------------------
--            -- Añadimos el formateador de LUA
--            ----------------------------------------------
--            null_ls.builtins.formatting.stylua,
--            ----------------------------------------------
--            -- Añadimos el formateador de prettier
--            -- soporta muchos lenguajes
--            ----------------------------------------------
--            null_ls.builtins.formatting.prettier,
--            -- null_ls.builtins.formatting.black,
--            -- null_ls.builtins.formatting.isort,
--            -- --null_ls.builtins.diagnostics.rubocop,
--            -- null_ls.builtins.diagnostics.eslint_d
--            --null_ls.builtins.formatting.rubocop,
--            ----------------------------------------------
--            -- Añadimos el formateador MATLAB
--            ----------------------------------------------
--            matlab_formatter,
--          },
--        })
--
--        -- Mapeo para formatear (Null-ls)
--        vim.keymap.set("n", "<leader>gf", function()
--          vim.lsp.buf.format({ async = true })
--        end, { desc = "Formatear código (MATLAB/otros)" })
--      end,
--    }
--
