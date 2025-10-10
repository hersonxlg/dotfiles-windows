return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "williamboman/mason.nvim",
    "folke/neodev.nvim",
  },
  lazy = false,
  config = function()
    local capabilities = require('cmp_nvim_lsp').default_capabilities()
    -- Helper para registrar y activar
    local function register_and_enable(name, opts)
      if opts then
        vim.lsp.config(name, opts)
      end
      vim.lsp.enable(name)
    end

    -- clangd
    register_and_enable("clangd", { capabilities = capabilities })

    -- asm_lsp (corrigiendo cmd_cwd)
    register_and_enable("asm_lsp", {
      cmd       = { "asm-lsp" },
      filetypes = { "asm", "nasm", "gas", "armasm", "avr" },
      root_dir  = (function()
        local util = require("lspconfig.util")
        return function(fname)
          return util.root_pattern("asm_lsp.toml", ".git")(fname)
        end
      end)(),
      on_attach = function(_, bufnr)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = bufnr })
      end,
    })

    -- pylsp
    register_and_enable("pylsp", {
      settings = {
        pylsp = {
          plugins = {
            rope_rename = { enabled = false },
            jedi_rename = { enabled = false },
            pylsp_rope = { rename = true },
          },
        },
      },
      capabilities = capabilities,
    })

    -- lua_ls
    register_and_enable("lua_ls", { capabilities = capabilities })

    -- ts_ls
    register_and_enable("ts_ls", {
      capabilities = capabilities,
      filetypes = {
        "javascript", "javascript.jsx",
        "typescript", "typescript.tsx",
      },
      init_options = {
        hostInfo = "neovim",
      },
    })

    -- vimls
    register_and_enable("vimls", { capabilities = capabilities })

    -- PowerShell Editor Services
    local caps = require("cmp_nvim_lsp").default_capabilities()
    register_and_enable("powershell_es", {
      capabilities = caps,
      filetypes    = { "ps1", "psm1", "psd1" },
      bundle_path  = vim.fn.stdpath("data") .. "\\mason\\packages\\powershell-editor-services",
      shell        = "pwsh",
      settings     = {
        powershell = {
          codeFormatting = { Preset = "OTBS" },
        },
      },
      init_options = { enableProfileLoading = false },
      root_dir = function(fname)
        local path = vim.fs.dirname(fname)
        local git  = vim.fs.find({ ".git" }, { upward = true, path = path })[1]
        return git and vim.fs.dirname(git) or path
      end,
    })

    -- matlab_ls
    register_and_enable("matlab_ls", {
      cmd = { "matlab-ls" },
      filetypes = { "matlab" },
      root_dir = (function()
        local util = require("lspconfig.util")
        return function(fname)
          return util.root_pattern(".git", "startup.m")(fname)
        end
      end)(),
      capabilities = require("cmp_nvim_lsp").default_capabilities(),
    })

    -- Mappings globales mínimos
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, {})
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, {})
    vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, {})
  end
}




--  return {
--      ---------------------------------
--      -- Install "Mason"
--      ---------------------------------
--      {
--          "williamboman/mason.nvim",
--          lazy = false,
--          config = function()
--              require("mason").setup()
--          end
--      },
--      ---------------------------------
--      -- Install "LSP de Mason"
--      ---------------------------------
--      {
--          "williamboman/mason-lspconfig.nvim",
--          lazy = false,
--          opts = {
--              auto_install = true,
--          },
--          config = function()
--              require("mason-lspconfig").setup({
--                  ensure_installed = {
--                      "lua_ls",
--                      "pylsp",
--                      "clangd",
--                      "ts_ls",
--                      "powershell_es",
--                      "asm_lsp" -- requiere "cargo.exe" (Rust).
--                  },
--              })
--          end
--      },
--  
--      ---------------------------------
--      -- Install "mason-lspconfig"
--      ---------------------------------
--      {
--          "neovim/nvim-lspconfig",
--          dependencies = {
--              "williamboman/mason.nvim",
--              "folke/neodev.nvim",
--          },
--          lazy = false,
--          config = function()
--              local capabilities = require('cmp_nvim_lsp').default_capabilities()
--              local lspconfig = require("lspconfig")
--  
--              lspconfig.clangd.setup({
--                  capabilities = capabilities
--              })
--  
--  
--              -- asm_lsp: remove cmd_cwd (must be a directory, not a file)
--              lspconfig.asm_lsp.setup({
--                  cmd       = { "asm-lsp" },
--                  filetypes = { "asm", "nasm", "gas", "armasm", "avr" },
--                  root_dir  = lspconfig.util.root_pattern("asm_lsp.toml", ".git"),
--                  on_attach = function(_, bufnr)
--                      vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = bufnr })
--                  end,
--              })
--  
--              lspconfig.pylsp.setup({
--                  settings = {
--                      pylsp = {
--                          plugins = {
--                              rope_rename = { enabled = false },
--                              jedi_rename = { enabled = false },
--                              pylsp_rope = { rename = true }
--                          }
--                      }
--                  },
--                  capabilities = capabilities
--              })
--  
--              lspconfig.lua_ls.setup({
--                  capabilities = capabilities
--              })
--              lspconfig.ts_ls.setup({
--                  capabilities = capabilities,
--                  filetypes = {
--                      "javascript", "javascript.jsx",
--                      "typescript", "typescript.tsx",
--                  },
--                  init_options = {
--                      hostInfo = "neovim",
--                  },
--              })
--              --lspconfig.arduino_language_server.setup({
--              --    capabilities = capabilities
--              --})
--              lspconfig.vimls.setup({
--                  capabilities = capabilities
--              })
--  
--              ---------------------------------
--              -- Configuración del LSP de PowerShell
--              ---------------------------------
--              local caps = require("cmp_nvim_lsp").default_capabilities()
--              -- POWERHELL EDITOR SERVICES
--              lspconfig.powershell_es.setup({
--                  capabilities = caps,
--                  filetypes    = { "ps1", "psm1", "psd1" },
--                  bundle_path  = vim.fn.stdpath("data")
--                      .. "\\mason\\packages\\powershell-editor-services",
--                  shell        = "pwsh", -- PowerShell 7
--                  settings     = {
--                      powershell = {
--                          codeFormatting = { Preset = "OTBS" },
--                      },
--                  },
--                  init_options = {
--                      enableProfileLoading = false,
--                  },
--                  root_dir     = function(fname)
--                      -- fname es la ruta completa al archivo que está abriendo el LSP
--                      local path = vim.fs.dirname(fname)
--                      local git  = vim.fs.find({ ".git" }, { upward = true, path = path })[1]
--                      return git and vim.fs.dirname(git) or path
--                  end,
--              })
--              ---------------------------------
--              -- Configuración del LSP de Matlab
--              ---------------------------------
--              lspconfig.matlab_ls.setup({
--                  cmd = { "matlab-ls" },                                       -- asegúrate de que esté en tu PATH, o usa la ruta completa
--                  filetypes = { "matlab" },
--                  root_dir = lspconfig.util.root_pattern(".git", "startup.m"), -- o lo que defina tu proyecto
--                  capabilities = require("cmp_nvim_lsp").default_capabilities(),
--              })
--              ---------------------------------
--              vim.keymap.set('n', 'K', vim.lsp.buf.hover, {})
--              vim.keymap.set('n', 'gd', vim.lsp.buf.definition, {})
--              vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, {})
--          end
--      },
--  
--  }
