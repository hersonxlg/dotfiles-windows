return {
    ---------------------------------
    -- Install "Mason"
    ---------------------------------
    {
        "williamboman/mason.nvim",
        lazy = false,
        config = function()
            require("mason").setup()
        end
    },

    ---------------------------------
    -- Install "Mason LSP"
    ---------------------------------
    {
        "williamboman/mason-lspconfig.nvim",
        lazy = false,
        opts = {
            auto_install = true,
        },
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "lua_ls",
                    "pylsp",
                    "clangd",
                    "ts_ls",
                    "powershell_es",
                    "asm_lsp"
                },
            })
        end
    },

    ---------------------------------
    -- Install "nvim-lspconfig"
    ---------------------------------
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "folke/neodev.nvim",
        },
        lazy = false,
        config = function()
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            -- clangd
            vim.lsp.config.clangd = {
                default_config = {
                    cmd = { "clangd" },
                    capabilities = capabilities,
                }
            }
            vim.lsp.enable("clangd")

            -- asm_lsp
            vim.lsp.config.asm_lsp = {
                default_config = {
                    cmd = { "asm-lsp" },
                    filetypes = { "asm", "nasm", "gas", "armasm", "avr" },
                    root_dir = function(fname)
                        local path = vim.fs.dirname(fname)
                        local git = vim.fs.find({ ".git" }, { upward = true, path = path })[1]
                        if git then
                            return vim.fs.dirname(git)
                        end
                        local toml = vim.fs.find({ "asm_lsp.toml" }, { upward = true, path = path })[1]
                        if toml then
                            return vim.fs.dirname(toml)
                        end
                        return path
                    end,
                    on_attach = function(_, bufnr)
                        vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = bufnr })
                    end,
                }
            }
            vim.lsp.enable("asm_lsp")

            -- pylsp
            vim.lsp.config.pylsp = {
                default_config = {
                    cmd = { "pylsp" },
                    settings = {
                        pylsp = {
                            plugins = {
                                rope_rename = { enabled = false },
                                jedi_rename = { enabled = false },
                                pylsp_rope = { rename = true },
                            }
                        }
                    },
                    capabilities = capabilities,
                }
            }
            vim.lsp.enable("pylsp")

            -- lua_ls
            vim.lsp.config.lua_ls = {
                default_config = {
                    cmd = { "lua-language-server" },
                    capabilities = capabilities,
                }
            }
            vim.lsp.enable("lua_ls")

            -- ts_ls
            vim.lsp.config.ts_ls = {
                default_config = {
                    cmd = { "typescript-language-server", "--stdio" },
                    filetypes = {
                        "javascript", "javascript.jsx",
                        "typescript", "typescript.tsx",
                    },
                    init_options = {
                        hostInfo = "neovim",
                    },
                    capabilities = capabilities,
                }
            }
            vim.lsp.enable("ts_ls")

            -- vimls
            vim.lsp.config.vimls = {
                default_config = {
                    cmd = { "vim-language-server" },
                    capabilities = capabilities,
                }
            }
            vim.lsp.enable("vimls")

            ---------------------------------
            -- PowerShell LSP (Neovim 0.11+)
            ---------------------------------
            vim.lsp.config("powershell_es", {
                bundle_path = vim.fn.stdpath("data")
                    .. "/mason/packages/powershell-editor-services",

                settings = {
                    powershell = {
                        codeFormatting = {
                            Preset = "OTBS",
                        },
                    },
                },

                init_options = {
                    enableProfileLoading = false,
                },
            })

            vim.lsp.enable("powershell_es")

            ---------------------------------
            -- Matlab LSP
            ---------------------------------
            vim.lsp.config.matlab_ls = {
                default_config = {
                    cmd = { "matlab-ls" },
                    filetypes = { "matlab" },
                    root_dir = function(fname)
                        local path = vim.fs.dirname(fname)
                        local git = vim.fs.find({ ".git" }, { upward = true, path = path })[1]
                        if git then
                            return vim.fs.dirname(git)
                        end
                        local startup = vim.fs.find({ "startup.m" }, { upward = true, path = path })[1]
                        if startup then
                            return vim.fs.dirname(startup)
                        end
                        return path
                    end,
                    capabilities = capabilities,
                }
            }
            vim.lsp.enable("matlab_ls")

            ---------------------------------
            -- Global keymaps
            ---------------------------------
            vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, {})
            vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, {})
        end
    },
}

-- ***************************************************************************
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
