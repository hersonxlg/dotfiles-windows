--  return {
--    "nvimtools/none-ls.nvim",
--    dependencies = { "nvim-lua/plenary.nvim" },
--    config = function()
--      local null_ls = require("null-ls")
--      local helpers = require("null-ls.helpers")
--  
--      -- Creamos un “builtin” de MATLAB
--      local matlab_formatter = helpers.make_builtin({
--        name        = "matlab-formatter",
--        method      = null_ls.methods.FORMATTING,
--        filetypes   = { "matlab" },
--        generator_opts = {
--          command  = "python",
--          args     = {
--            vim.fn.stdpath("data") .. "\\matlab-formatter\\formatter\\matlab_formatter.py",
--            "$FILENAME",
--          },
--          to_stdin = false,
--        },
--        factory = helpers.generator_factory,
--      })
--  
--      null_ls.setup({
--        sources = {
--          null_ls.builtins.formatting.stylua,
--          null_ls.builtins.formatting.prettier,
--          -- añadimos nuestro formateador:
--          matlab_formatter,
--        },
--      })
--  
--      vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, { desc = "Format code" })
--    end,
--  }
--  

-- lua/plugins/none-ls.lua
return {
  "nvimtools/none-ls.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local null_ls = require("null-ls")
    local helpers = require("null-ls.helpers")

    -- Crear builtin personalizado para MATLAB Formatter
    local matlab_formatter = helpers.make_builtin({
      name        = "matlab-formatter",
      method      = null_ls.methods.FORMATTING,
      filetypes   = { "matlab" },
      generator_opts = {
        command  = "python",
        args     = {
          vim.fn.stdpath("data") .. "/matlab-formatter/formatter/matlab_formatter.py",
          -- Aseguramos que la ruta use '/formatter/matlab_formatter.py'
          "$FILENAME",
        },
        to_stdin = false,
      },
      factory = helpers.generator_factory,
    })

    null_ls.setup({
      sources = {
        ----------------------------------------------
        -- Añadimos el formateador de LUA
        ----------------------------------------------
        null_ls.builtins.formatting.stylua,
        ----------------------------------------------
        -- Añadimos el formateador de prettier 
        -- soporta muchos lenguajes
        ----------------------------------------------
        null_ls.builtins.formatting.prettier,
        -- null_ls.builtins.formatting.black,
        -- null_ls.builtins.formatting.isort,
        -- --null_ls.builtins.diagnostics.rubocop,
        -- null_ls.builtins.diagnostics.eslint_d
        --null_ls.builtins.formatting.rubocop,
        ----------------------------------------------
        -- Añadimos el formateador MATLAB
        ----------------------------------------------
        matlab_formatter,
      },
    })

    -- Mapeo para formatear (Null-ls)
    vim.keymap.set("n", "<leader>gf", function()
      vim.lsp.buf.format({ async = true })
    end, { desc = "Formatear código (MATLAB/otros)" })
  end,
}


--  return {
--      "nvimtools/none-ls.nvim",
--      config = function()
--          local null_ls = require("null-ls")
--  
--          null_ls.setup({
--              sources = {
--                  null_ls.builtins.formatting.stylua,
--                  null_ls.builtins.formatting.prettier,
--                  -- null_ls.builtins.formatting.black,
--                  -- null_ls.builtins.formatting.isort,
--                  -- --null_ls.builtins.diagnostics.rubocop,
--                  -- null_ls.builtins.diagnostics.eslint_d
--                  --null_ls.builtins.formatting.rubocop,
--                  -- ✅ Formateador MATLAB:
--                  null_ls.builtins.formatting.formatter.with({
--                      name      = "matlab-formatter",
--                      method    = null_ls.methods.FORMATTING,
--                      filetypes = { "matlab" },
--                      generator = null_ls.generator({
--                          command = "python",
--                          args = {
--                              vim.fn.stdpath("data") ..
--                                  "\\matlab-formatter\\formatter\\matlab_formatter.py",
--                              "$FILENAME",
--                          },
--                          to_stdin = false,
--                          from_stderr = true,
--                          format = "raw",
--                      }),
--                  }),
--              },
--          })
--  
--          vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, {})
--      end,
--  }
