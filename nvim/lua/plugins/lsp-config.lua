return {
    ---------------------------------
    -- Install "Mason"
    ---------------------------------
    {
        "williamboman/mason.nvim",
        cmd = "Mason",
        opts = {
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗",
                },
            },
        },
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
                    -- 🔧 Tus LSPs actuales (Intactos)
                    "lua_ls",
                    "pylsp",
                    "pyright",
                    "clangd",
                    "ts_ls",
                    "tombi",
                    "powershell_es",
                    "arduino_language_server",
                    "asm_lsp",
                    "vimls",
                    "emmet_ls",

                    -- 🌐 Desarrollo Web y Datos
                    "html",
                    "cssls",
                    "jsonls",

                    -- 🛠️ Scripting y Configuración
                    "bashls",
                    "yamlls",
                    "marksman",

                    -- 🚀 Herramientas Avanzadas
                    "ast_grep",

                    -- Kotlin LSP
                    "kotlin_lsp",

                    -- Rust
                    "rust_analyzer",
                },
            })
            vim.diagnostic.config({
                virtual_text = true,
                virtual_lines = false,
                underline = false,
            })
        end,
    },

    ---------------------------------
    -- Install "nvim-lspconfig"
    ---------------------------------
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "folke/neodev.nvim",
            "saghen/blink.cmp",
        },
        lazy = false,
        config = function()
            local uv = vim.uv or vim.loop

            -- FIX 1: Agregar Mason al PATH usando el separador correcto para cada SO
            local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
            local is_windows = vim.fn.has("win32") == 1
            local separator = is_windows and ";" or ":"

            if not string.find(vim.env.PATH, mason_bin, 1, true) then
                vim.env.PATH = mason_bin .. separator .. vim.env.PATH
            end

            -- Reemplaza: require("cmp_nvim_lsp").default_capabilities()
            -- Por esto:
            local capabilities = require("blink.cmp").get_lsp_capabilities()

            capabilities.textDocument.foldingRange = {
                dynamicRegistration = false,
                lineFoldingOnly = true,
            }

            local function notify_missing(name)
                vim.notify(name .. " no está instalado o no está en PATH", vim.log.levels.WARN)
            end

            -- FIX 2: Función multiplataforma para detectar ejecutables (.cmd / .exe en Windows)
            local function has_exe(name)
                if is_windows then
                    return vim.fn.executable(name) == 1
                        or vim.fn.executable(name .. ".cmd") == 1
                        or vim.fn.executable(name .. ".exe") == 1
                end
                return vim.fn.executable(name) == 1
            end

            local function os_home()
                return (uv.os_homedir() or vim.fn.expand("~")):gsub("\\", "/")
            end

            local function find_pio()
                if has_exe("pio") then
                    return "pio"
                end

                local home = os_home()
                local candidates = {
                    home .. "/.platformio/penv/bin/pio",
                    home .. "/.platformio/penv/Scripts/pio.exe",
                    home .. "/.local/bin/pio",
                    home .. "/AppData/Roaming/Python/Python311/Scripts/pio.exe",
                    home .. "/AppData/Roaming/Python/Python312/Scripts/pio.exe",
                }

                for _, path in ipairs(candidates) do
                    if vim.fn.filereadable(path) == 1 then
                        return path:gsub("\\", "/")
                    end
                end

                return nil
            end

            local function get_mason_binary(package, binary)
                local mason_path = vim.fn.stdpath("data") .. "/mason"
                local ext = is_windows and ".exe" or ""

                local path = mason_path .. "/bin/" .. binary .. ext
                if vim.fn.filereadable(path) == 0 then
                    path = mason_path .. "/packages/" .. package .. "/" .. binary .. ext
                end

                if vim.fn.filereadable(path) == 1 then
                    return path:gsub("\\", "/")
                end

                return binary
            end

            -----------------------------------------------------------------
            -- TOML (Tombi)
            --------------------------------------------------------
            if has_exe("taplo") or has_exe("tombi") then
                -- 1. Determinamos la ruta de configuración global según el SO
                local tombi_config_dir
                if is_windows then
                    local appdata = vim.env.APPDATA or (os_home() .. "/AppData/Roaming")
                    tombi_config_dir = vim.fs.normalize(appdata .. "/tombi")
                else
                    local xdg_config = vim.env.XDG_CONFIG_HOME
                    tombi_config_dir = (xdg_config and xdg_config ~= "") and vim.fs.normalize(xdg_config .. "/tombi")
                        or (os_home() .. "/.config/tombi")
                end

                local tombi_config_file = tombi_config_dir .. "/config.toml"

                -- Crear directorio si no existe (funciona de forma transparente en Linux/macOS/Windows)
                if vim.fn.isdirectory(tombi_config_dir) == 0 then
                    vim.fn.mkdir(tombi_config_dir, "p")
                end

                local config_content = [[
[format.rules]
indent-width = 4
indent-table-key-value-pairs = true
indent-sub-tables = true
]]

                local f = io.open(tombi_config_file, "w")
                if f then
                    f:write(config_content)
                    f:close()
                end

                -- 2. Configuración e inicio de Tombi LSP
                vim.lsp.config.tombi = {
                    default_config = {
                        cmd = { "tombi", "lsp" },
                        filetypes = { "toml" },
                        single_file_support = true,
                        root_dir = function(bufnr_or_fname)
                            local fname = type(bufnr_or_fname) == "number" and vim.api.nvim_buf_get_name(bufnr_or_fname)
                                or bufnr_or_fname

                            if fname and fname ~= "" then
                                local abs_path = vim.fs.normalize(vim.fn.fnamemodify(fname, ":p"))
                                local root = vim.fs.root(
                                    abs_path,
                                    { ".git", "pyproject.toml", "Cargo.toml", "tombi.toml", "config.toml" }
                                )
                                if root then
                                    return root
                                end
                                return vim.fs.dirname(abs_path)
                            end
                            return vim.uv.cwd()
                        end,
                        capabilities = capabilities,
                    },
                }
                vim.lsp.enable("tombi")
            else
                notify_missing("tombi")
            end ------------------------
            -- Emmet LSP (Abreviaciones ultra rápidas de HTML/CSS)
            ---------------------------------
            if has_exe("emmet-language-server") then
                vim.lsp.config.emmet_ls = {
                    default_config = {
                        capabilities = capabilities,
                        filetypes = {
                            "html",
                            "css",
                            "scss",
                            "sass",
                            "less",
                            "javascript",
                            "typescript",
                            "javascriptreact",
                            "typescriptreact",
                        },
                    },
                }
                vim.lsp.enable("emmet_ls")
            end

            ---------------------------------
            -- AST-Grep LSP
            ---------------------------------
            -- Nota: ast_grep usa el comando "sg" en la terminal
            if has_exe("sg") then
                vim.lsp.config.ast_grep = {
                    default_config = {
                        cmd = { "sg", "lsp" },
                        filetypes = {
                            "c",
                            "cpp",
                            "rust",
                            "go",
                            "java",
                            "python",
                            "javascript",
                            "typescript",
                            "html",
                            "css",
                            "json",
                        },
                        root_dir = function(fname)
                            return vim.fs.dirname(
                                vim.fs.find({ "sgconfig.yml", ".git" }, { upward = true, path = vim.fs.dirname(fname) })[1]
                            )
                        end,
                        capabilities = capabilities,
                    },
                }
                vim.lsp.enable("ast_grep")
            end

            --------------------------------------------------------
            -- HTML
            --------------------------------------------------------
            if has_exe("vscode-html-language-server") then
                vim.lsp.config.html = { default_config = { capabilities = capabilities } }
                vim.lsp.enable("html")
            end

            --------------------------------------------------------
            -- CSS
            --------------------------------------------------------
            if has_exe("vscode-css-language-server") then
                vim.lsp.config.cssls = { default_config = { capabilities = capabilities } }
                vim.lsp.enable("cssls")
            end

            --------------------------------------------------------
            -- JSON
            --------------------------------------------------------
            if has_exe("vscode-json-language-server") then
                vim.lsp.config.jsonls = { default_config = { capabilities = capabilities } }
                vim.lsp.enable("jsonls")
            end

            --------------------------------------------------------
            -- Bash / Shell
            --------------------------------------------------------
            if has_exe("bash-language-server") then
                vim.lsp.config.bashls = { default_config = { capabilities = capabilities } }
                vim.lsp.enable("bashls")
            end

            --------------------------------------------------------
            -- YAML
            --------------------------------------------------------
            if has_exe("yaml-language-server") then
                vim.lsp.config.yamlls = { default_config = { capabilities = capabilities } }
                vim.lsp.enable("yamlls")
            end

            --------------------------------------------------------
            -- Markdown
            --------------------------------------------------------
            if has_exe("marksman") then
                vim.lsp.config.marksman = { default_config = { capabilities = capabilities } }
                vim.lsp.enable("marksman")
            end

            --------------------------------------------------------
            -- clangd (Optimizado para Neovim 0.12+ Nativo Multiplataforma)
            --------------------------------------------------------

            -- 1. VALIDACIÓN: Solo se ejecuta si 'clangd' está instalado en el sistema
            if vim.fn.executable("clangd") == 1 then
                -- Detectamos el sistema operativo actual
                local is_windows = vim.fn.has("win32") == 1

                -- Argumentos base comunes (SIN el query-driver, lo asignaremos después)
                local cmd = {
                    "clangd",
                    "--background-index",
                    "--clang-tidy",
                    "--header-insertion=never",
                }
                local fallbackFlags = {}

                if is_windows then
                    -- ==========================================
                    -- CONFIGURACIÓN PARA WINDOWS (Scoop / MinGW)
                    -- ==========================================
                    local home = (vim.env.USERPROFILE or vim.uv.os_homedir()):gsub("\\", "/")
                    local mingw_include = home .. "/scoop/apps/mingw/current/x86_64-w64-mingw32/include"

                    -- Patrón con barras invertidas dobles para rutas de Windows
                    table.insert(cmd, "--query-driver=**\\bin\\*g++*,**\\bin\\*gcc*")

                    fallbackFlags = {
                        "--target=x86_64-w64-mingw32",
                        "-I" .. mingw_include,
                    }
                else
                    -- ==========================================
                    -- CONFIGURACIÓN PARA LINUX / MACOS
                    -- ==========================================

                    -- Patrón universal con barras normales. Esto permite que clangd
                    -- ejecute de forma segura los compiladores ocultos en ~/.platformio/...
                    table.insert(cmd, "--query-driver=**/*g++*,**/*gcc*,**/*clang*")
                end

                -- 2. Aplicamos la configuración en la API moderna de Neovim 0.12
                vim.lsp.config.clangd = vim.tbl_deep_extend("force", vim.lsp.config.clangd or {}, {
                    default_config = { capabilities = capabilities },
                    cmd = cmd,

                    -- Obligatorio en Neovim 0.12 nativo
                    filetypes = { "c", "cpp", "objc", "objcpp", "h", "hpp" },

                    init_options = {
                        fallbackFlags = fallbackFlags,
                    },
                    root_markers = {
                        "compile_commands.json",
                        "compile_flags.txt",
                        "platformio.ini",
                        ".git",
                    },

                    on_attach = function(client, bufnr)
                        client.server_capabilities.documentFormattingProvider = false
                        client.server_capabilities.documentRangeFormattingProvider = false
                    end,
                })

                -- 3. Activamos el servidor de forma segura usando el gestor nativo
                vim.lsp.enable("clangd")
            end
            --------------------------------------------------------
            -- asm_lsp
            --------------------------------------------------------
            if has_exe("asm-lsp") then
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
                    },
                }
                vim.lsp.enable("asm_lsp")
            else
                notify_missing("asm-lsp")
            end

            --------------------------------------------------------
            -- Python LSPs: Pyright & Pylsp (Selector Dinámico)
            -- pyright
            -- pylsp
            --------------------------------------------------------

            -- 🔍 Helper: Localiza el ejecutable de Python en el entorno virtual (.venv / uv)
            local function find_python_venv(bufnr)
                local buf_path = vim.api.nvim_buf_get_name(bufnr or 0)
                local start_dir = (buf_path ~= "" and vim.fs.dirname(buf_path)) or (vim.uv or vim.loop).cwd()

                local venv_dir = vim.fs.find(".venv", { upward = true, path = start_dir })[1]
                if not venv_dir then
                    return nil
                end

                local python_bin = is_windows and (venv_dir .. "/Scripts/python.exe") or (venv_dir .. "/bin/python")
                python_bin = python_bin:gsub("\\", "/")

                if vim.fn.filereadable(python_bin) == 1 or vim.fn.executable(python_bin) == 1 then
                    return python_bin
                end
                return nil
            end

            -- 1. Configuramos Pylsp
            if has_exe("pylsp") then
                vim.lsp.config.pylsp = vim.tbl_deep_extend("force", vim.lsp.config.pylsp or {}, {
                    cmd = { "pylsp" },
                    -- 🛑 CRÍTICO: Tabla vacía para aplastar el autostart nativo de Neovim
                    filetypes = {},
                    capabilities = capabilities,
                    settings = {
                        pylsp = {
                            plugins = {
                                rope_rename = { enabled = false },
                                jedi_rename = { enabled = false },
                                pylsp_rope = { rename = true },
                                autopep8 = { enabled = true },
                                yapf = { enabled = false },
                            },
                        },
                    },
                })
            else
                notify_missing("pylsp")
            end

            -- 2. Configuramos Pyright
            if has_exe("pyright-langserver") then
                vim.lsp.config.pyright = vim.tbl_deep_extend("force", vim.lsp.config.pyright or {}, {
                    cmd = { "pyright-langserver", "--stdio" },
                    -- 🛑 CRÍTICO: Tabla vacía para aplastar el autostart nativo de Neovim
                    filetypes = {},
                    capabilities = capabilities,
                    settings = {
                        python = {
                            analysis = {
                                autoSearchPaths = true,
                                useLibraryCodeForTypes = true,
                                diagnosticMode = "workspace",
                            },
                        },
                    },
                })
            else
                notify_missing("pyright-langserver")
            end

            -- =========================================================
            -- 🧠 LÓGICA DE LAS 3 CAPAS (BLINDADA CONTRA DUPLICADOS)
            -- =========================================================

            -- Tu servidor global por defecto
            vim.g.python_lsp_default = "pyright"

            -- Autocomando que inyecta el LSP correcto + entorno .venv de uv
            vim.api.nvim_create_autocmd("FileType", {
                pattern = "python",
                callback = function(args)
                    local lsp_to_use = vim.b.python_lsp or vim.g.python_lsp or vim.g.python_lsp_default
                    local config = vim.lsp.config[lsp_to_use]

                    if config then
                        local active_clients = vim.lsp.get_clients({ bufnr = args.buf, name = lsp_to_use })

                        if #active_clients == 0 then
                            -- 🐍 Inyección de entorno virtual de UV
                            local venv_python = find_python_venv(args.buf)
                            local lsp_config = vim.deepcopy(config)

                            if venv_python then
                                lsp_config.settings = lsp_config.settings or {}
                                if lsp_to_use == "pyright" then
                                    lsp_config.settings.python = lsp_config.settings.python or {}
                                    lsp_config.settings.python.pythonPath = venv_python
                                elseif lsp_to_use == "pylsp" then
                                    lsp_config.settings.pylsp = lsp_config.settings.pylsp or {}
                                    lsp_config.settings.pylsp.plugins = lsp_config.settings.pylsp.plugins or {}
                                    lsp_config.settings.pylsp.plugins.jedi = lsp_config.settings.pylsp.plugins.jedi
                                        or {}
                                    lsp_config.settings.pylsp.plugins.jedi.environment = venv_python
                                end
                            end

                            vim.lsp.start(lsp_config, { bufnr = args.buf })
                        end
                    end
                end,
            })

            -- EL INTERRUPTOR: Comando interactivo
            vim.api.nvim_create_user_command("PythonLspSwitch", function()
                vim.ui.select({ "pyright", "pylsp" }, {
                    prompt = "🐍 Elige el LSP para Python:",
                }, function(choice)
                    if not choice then
                        return
                    end

                    vim.g.python_lsp = choice
                    local bufnr = vim.api.nvim_get_current_buf()

                    -- 1. Apagamos TODOS los clientes de Python en este buffer de forma blindada
                    local clients = vim.lsp.get_clients({ bufnr = bufnr })
                    for _, client in ipairs(clients) do
                        if client.name == "pyright" or client.name == "pylsp" then
                            -- 🛡️ TÁCTICA 1: Cortamos la comunicación con el buffer ANTES de apagar
                            vim.lsp.buf_detach_client(bufnr, client.id)
                            -- Ahora sí, le pedimos que se apague amablemente
                            client:stop()
                        end
                    end

                    -- 2. 🛡️ TÁCTICA 2: Esperamos 300ms para que el servidor viejo muera en paz
                    vim.defer_fn(function()
                        local config = vim.lsp.config[choice]
                        if config then
                            local venv_python = find_python_venv(bufnr)
                            local lsp_config = vim.deepcopy(config)

                            if venv_python then
                                lsp_config.settings = lsp_config.settings or {}
                                if choice == "pyright" then
                                    lsp_config.settings.python = lsp_config.settings.python or {}
                                    lsp_config.settings.python.pythonPath = venv_python
                                elseif choice == "pylsp" then
                                    lsp_config.settings.pylsp = lsp_config.settings.pylsp or {}
                                    lsp_config.settings.pylsp.plugins = lsp_config.settings.pylsp.plugins or {}
                                    lsp_config.settings.pylsp.plugins.jedi = lsp_config.settings.pylsp.plugins.jedi
                                        or {}
                                    lsp_config.settings.pylsp.plugins.jedi.environment = venv_python
                                end
                            end

                            vim.lsp.start(lsp_config, { bufnr = bufnr })
                            local msg = "✅ LSP cambiado a: " .. choice
                            if venv_python then
                                msg = msg .. " (.venv detectado)"
                            end
                            vim.notify(msg, vim.log.levels.INFO)
                        end
                    end, 300)
                end)
            end, {})

            -- Atajo de teclado
            vim.keymap.set("n", "<leader>ps", ":PythonLspSwitch<CR>", { desc = "Python: Cambiar LSP" })

            -- =========================================================
            -- ⚡ COMANDOS Y ATAJOS PARA `UV`
            -- =========================================================
            if has_exe("uv") then
                vim.keymap.set(
                    "n",
                    "<leader>rr",
                    ":term uv run python %<CR>",
                    { desc = "Python (uv): Ejecutar archivo actual" }
                )
                vim.keymap.set("n", "<leader>pt", ":term uv run pytest<CR>", { desc = "Python (uv): Ejecutar tests" })

                vim.api.nvim_create_user_command("UvSync", function()
                    vim.cmd("split | terminal uv sync")
                end, { desc = "Sincronizar dependencias con uv" })

                vim.api.nvim_create_user_command("UvAdd", function(opts)
                    vim.cmd("split | terminal uv add " .. opts.args)
                end, { nargs = 1, desc = "Añadir un paquete con uv" })
            end

            --------------------------------------------------------
            -- lua_ls (Neovim 0.12+ moderno)
            --------------------------------------------------------

            if has_exe("lua-language-server") then
                vim.lsp.config.lua_ls = {

                    ------------------------------------------------
                    -- Capabilities (cmp_nvim_lsp)
                    ------------------------------------------------
                    capabilities = capabilities,

                    ------------------------------------------------
                    -- Ejecutable
                    ------------------------------------------------
                    cmd = { "lua-language-server" },

                    ------------------------------------------------
                    -- Filetypes
                    ------------------------------------------------
                    filetypes = { "lua" },

                    ------------------------------------------------
                    -- Root markers
                    ------------------------------------------------
                    root_markers = {
                        { ".luarc.json", ".luarc.jsonc" },
                        ".git",
                    },

                    ------------------------------------------------
                    -- on_attach
                    ------------------------------------------------
                    on_attach = function(client, bufnr)
                        ------------------------------------------------
                        -- stylua será el formatter real
                        ------------------------------------------------
                        client.server_capabilities.documentFormattingProvider = false
                        client.server_capabilities.documentRangeFormattingProvider = false

                        ------------------------------------------------
                        -- Keymaps buffer-local opcionales
                        ------------------------------------------------
                        local opts = { buffer = bufnr }

                        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)

                        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)

                        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
                    end,

                    ------------------------------------------------
                    -- Settings de lua-language-server
                    ------------------------------------------------
                    settings = {
                        Lua = {

                            --------------------------------------------
                            -- Runtime
                            --------------------------------------------
                            runtime = {
                                version = "LuaJIT",
                            },

                            --------------------------------------------
                            -- Completion
                            --------------------------------------------
                            completion = {
                                callSnippet = "Replace",
                            },

                            --------------------------------------------
                            -- Diagnostics
                            --------------------------------------------
                            diagnostics = {

                                ----------------------------------------
                                -- lazydev.nvim maneja esto
                                ----------------------------------------
                                globals = {},

                                ----------------------------------------
                                -- Reduce ruido
                                ----------------------------------------
                                disable = {
                                    "missing-fields",
                                },
                            },

                            --------------------------------------------
                            -- Workspace
                            --------------------------------------------
                            workspace = {

                                ----------------------------------------
                                -- Evita prompts molestos
                                ----------------------------------------
                                checkThirdParty = false,

                                ----------------------------------------
                                -- Runtime files de Neovim
                                ----------------------------------------
                                -- library = vim.api.nvim_get_runtime_file("", true),
                                library = {},
                            },

                            --------------------------------------------
                            -- Hinting
                            --------------------------------------------
                            hint = {
                                enable = true,
                            },

                            --------------------------------------------
                            -- Telemetry
                            --------------------------------------------
                            telemetry = {
                                enable = false,
                            },

                            --------------------------------------------
                            -- Format
                            --------------------------------------------
                            format = {
                                enable = false,
                            },
                        },
                    },
                }

                --------------------------------------------------------
                -- Activar servidor
                --------------------------------------------------------
                vim.lsp.enable("lua_ls")
            else
                notify_missing("lua-language-server")
            end
            --------------------------------------------------------
            -- ts_ls
            --------------------------------------------------------
            if has_exe("typescript-language-server") then
                -- Utilizamos get_mason_binary para asegurar la ruta correcta (especialmente útil en Windows/JS)
                local ts_binary = get_mason_binary("typescript-language-server", "typescript-language-server")

                vim.lsp.config.ts_ls = {
                    default_config = {
                        cmd = { ts_binary, "--stdio" },
                        filetypes = {
                            "javascript",
                            "javascript.jsx",
                            "typescript",
                            "typescript.tsx",
                        },
                        init_options = {
                            hostInfo = "neovim",
                        },
                        capabilities = capabilities,
                    },
                }
                vim.lsp.enable("ts_ls")
            else
                notify_missing("typescript-language-server")
            end

            --------------------------------------------------------
            -- vimls
            --------------------------------------------------------
            if has_exe("vim-language-server") then
                vim.lsp.config.vimls = {
                    default_config = {
                        cmd = { "vim-language-server" },
                        capabilities = capabilities,
                    },
                }
                vim.lsp.enable("vimls")
            end

            --------------------------------------------------------
            -- PowerShell LSP (Neovim 0.11+)
            --------------------------------------------------------
            local ps_bundle_path = vim.fn.stdpath("data") .. "/mason/packages/powershell-editor-services"
            local ps_cmd = has_exe("pwsh") and "pwsh" or "powershell.exe"

            if has_exe(ps_cmd) then
                vim.lsp.config("powershell_es", {
                    cmd = {
                        ps_cmd,
                        "-NoLogo",
                        "-NoProfile",
                        "-ExecutionPolicy",
                        "Bypass",
                        "-Command",
                        string.format(
                            "& '%s/PowerShellEditorServices/Start-EditorServices.ps1' -HostName 'nvim' -HostProfileId '0' -HostVersion '1.0.0' -Stdio -BundledModulesPath '%s' -LogLevel Normal",
                            ps_bundle_path,
                            ps_bundle_path
                        ),
                    },
                    root_dir = vim.fs.root(0, { ".git", "PSScriptAnalyzerSettings.psd1" }) or vim.fn.getcwd(),
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
                    capabilities = capabilities,
                })
                vim.lsp.enable("powershell_es")
            else
                notify_missing(ps_cmd)
            end

            ---------------------------------
            -- PlatformIO AUTOSETUP para clangd (Optimizado Neovim 0.12)
            ---------------------------------

            local function read_file(path)
                if vim.fn.filereadable(path) ~= 1 then
                    return ""
                end
                return table.concat(vim.fn.readfile(path), "\n")
            end

            local function platformio_root(bufnr)
                return vim.fs.root(bufnr, { "platformio.ini" })
            end

            -- Plantilla con espacios ASCII estándar válidos para el parser YAML de clangd
            local function build_clangd_template(platformio_ini_text)
                local text = (platformio_ini_text or ""):lower()
                local lines = {
                    "CompileFlags:",
                    "  Add:",
                }

                -- 1. Detectamos el HOME de forma multiplataforma
                local is_windows = vim.fn.has("win32") == 1
                local home = is_windows and (vim.env.USERPROFILE or vim.uv.os_homedir()):gsub("\\", "/") or vim.env.HOME

                -- 2. Determinamos la ruta del framework según la plataforma
                local framework_lib_path = nil

                if text:find("espressif32") then
                    framework_lib_path = home .. "/.platformio/packages/framework-arduinoespressif32/libraries"
                elseif text:find("atmelavr") then
                    framework_lib_path = home .. "/.platformio/packages/framework-arduino-avr/libraries"
                    -- IMPORTANTE: Mantenemos el target para que clangd entienda los enteros de 16-bits en AVR
                    table.insert(lines, "    - --target=avr")
                end

                -- 3. Escaneo dinámico de librerías (Funciona para ESP32 y AVR por igual)
                if framework_lib_path then
                    local handle = vim.uv.fs_scandir(framework_lib_path)
                    if handle then
                        while true do
                            local name, type = vim.uv.fs_scandir_next(handle)
                            if not name then
                                break
                            end

                            if type == "directory" then
                                local lib_dir = framework_lib_path .. "/" .. name
                                local src_dir = lib_dir .. "/src"

                                if vim.fn.isdirectory(src_dir) == 1 then
                                    table.insert(lines, "    - -I" .. src_dir)
                                else
                                    table.insert(lines, "    - -I" .. lib_dir)
                                end
                            end
                        end
                    end
                end

                -- Limpieza YAML si no se agregó nada
                if #lines == 2 then
                    lines = { "CompileFlags:" }
                end

                -- 4. Banderas de supresión universales
                vim.list_extend(lines, {
                    "  Remove:",
                    "    - -mlongcalls",
                    "    - -fstrict-volatile-bitfields",
                    "    - -fno-tree-switch-conversion",
                    "    - -free",
                    "    - -fipa-pta",
                    "",
                    "Diagnostics:",
                    "  Suppress:",
                    "    - type_unsupported",
                    "    - machine_mode",
                })
                return lines
            end

            local function write_clangd(root)
                local ini_path = root .. "/platformio.ini"
                local clangd_file = root .. "/.clangd"
                local ini_text = read_file(ini_path)

                -- Pasamos solo ini_text ya que compile_commands.json se encarga de los includes
                local new_lines = build_clangd_template(ini_text)
                vim.fn.writefile(new_lines, clangd_file)
            end

            local function safe_lsp_restart(client_name)
                -- Comando nativo core de Neovim 0.12
                vim.cmd("lsp restart " .. (client_name or ""))
            end

            local function ensure_platformio_setup(bufnr, force)
                local root = platformio_root(bufnr)
                if not root then
                    return
                end

                local pio_cmd = type(find_pio) == "function" and find_pio() or "pio"
                if not pio_cmd then
                    vim.notify("PlatformIO no encontrado", vim.log.levels.ERROR)
                    return
                end

                local function ensure_gitignore_entry(entry)
                    local gitignore = root .. "/.gitignore"
                    local lines = {}
                    if vim.fn.filereadable(gitignore) == 1 then
                        lines = vim.fn.readfile(gitignore)
                        for _, line in ipairs(lines) do
                            if vim.trim(line) == entry then
                                return
                            end
                        end
                    end
                    table.insert(lines, entry)
                    vim.fn.writefile(lines, gitignore)
                    vim.notify(".gitignore actualizado: " .. entry, vim.log.levels.INFO)
                end

                ensure_gitignore_entry("compile_commands.json")
                ensure_gitignore_entry(".clangd")

                local ini_path = root .. "/platformio.ini"
                local compiledb = root .. "/compile_commands.json"
                local clangd_file = root .. "/.clangd"

                local ini_time = vim.fn.getftime(ini_path)
                local db_time = vim.fn.filereadable(compiledb) == 1 and vim.fn.getftime(compiledb) or -1
                local clangd_time = vim.fn.filereadable(clangd_file) == 1 and vim.fn.getftime(clangd_file) or -1

                -- Evaluamos qué archivos necesitan actualizarse REALMENTE
                local need_clangd = force or vim.fn.filereadable(clangd_file) == 0 or ini_time > clangd_time
                local need_compiledb = force or vim.fn.filereadable(compiledb) == 0 or ini_time > db_time

                -- 1. Regenerar .clangd si es necesario
                if need_clangd then
                    write_clangd(root)
                    vim.notify("PlatformIO: .clangd actualizado", vim.log.levels.INFO)

                    -- ¡AQUÍ ESTÁ EL TRUCO!
                    -- Solo reiniciamos el LSP si NO se va a generar el compile_commands.json.
                    -- Si se va a generar el archivo pesado, nos quedamos quietos y esperamos.
                    if not need_compiledb then
                        safe_lsp_restart("clangd")
                    end
                end

                -- 2. Regenerar compile_commands.json de forma asíncrona
                if need_compiledb then
                    vim.notify("PlatformIO: generando compile_commands.json...", vim.log.levels.INFO)

                    -- Detectamos si estamos en Windows para activar el modo shell
                    local is_windows = vim.fn.has("win32") == 1

                    vim.fn.jobstart({ pio_cmd, "run", "-t", "compiledb" }, {
                        cwd = root,
                        shell = is_windows, -- <--- ¡ESTO ES CRUCIAL PARA WINDOWS!
                        on_exit = function(_, code)
                            if code == 0 then
                                vim.schedule(function()
                                    vim.notify("PlatformIO: compile_commands.json listo")
                                    safe_lsp_restart("clangd")
                                end)
                            end
                        end,
                    })
                end
            end
            -- Configuración de Autocomandos
            local pio_group = vim.api.nvim_create_augroup("PlatformIOAutoSetup", { clear = true })

            vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
                group = pio_group,
                pattern = { "*.c", "*.cpp", "*.h", "*.hpp", "*.ino" },
                callback = function(args)
                    ensure_platformio_setup(args.buf, false)
                end,
            })

            vim.api.nvim_create_user_command("PioRefresh", function()
                ensure_platformio_setup(vim.api.nvim_get_current_buf(), true)
            end, {})

            ------------------------------------------------------------
            -- 3. Detección de Plantillas PlatformIO (Compatible con blink.cmp)
            ------------------------------------------------------------
            local pio_snippets = {
                ["espwifi"] = true,
                ["piomain"] = true,
                ["uno_setup"] = true,
            }

            vim.api.nvim_create_autocmd("InsertLeave", {
                group = pio_group,
                pattern = { "*.c", "*.cpp", "*.h", "*.hpp", "*.ino" },
                callback = function(args)
                    local bufnr = args.buf
                    if not platformio_root(bufnr) then
                        return
                    end

                    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
                    for _, line in ipairs(lines) do
                        for snippet, _ in pairs(pio_snippets) do
                            if line:find(snippet) then
                                ensure_platformio_setup(bufnr, true)
                                return
                            end
                        end
                    end
                end,
            })

            ---------------------------------
            -- Arduino LSP  (usa clangd + arduino-cli)
            ---------------------------------

            -- ============================================================
            -- 1. HERRAMIENTAS AUXILIARES
            -- ============================================================

            local function normalize_path(path)
                return (path or ""):gsub("\\", "/")
            end

            local function resolve_program(package, binary)
                if has_exe(binary) then
                    return binary
                end

                local mason_path = get_mason_binary(package, binary)
                if mason_path and vim.fn.filereadable(mason_path) == 1 then
                    return mason_path
                end

                return nil
            end

            local function get_default_arduino_cli_config()
                if is_windows then
                    return normalize_path(vim.fn.expand("$LOCALAPPDATA/Arduino15/arduino-cli.yaml"))
                end

                return normalize_path(vim.fn.expand("~/.arduino15/arduino-cli.yaml"))
            end

            -- Cuenta cuántos espacios de indentación tiene una línea
            local function obtener_indentacion(linea)
                local espacios = linea:match("^(%s*)")
                return #espacios, espacios
            end

            -- Verifica si una línea es el inicio de una clave YAML
            local function es_clave(linea, clave)
                return linea:match("^%s*" .. clave .. ":") ~= nil
            end

            -- ============================================================
            -- 2. LÓGICA YAML
            -- ============================================================

            local function inyectar_yaml(lineas, jerarquia, campo, valor)
                local cambio_realizado = false
                local indent_actual = -1
                local linea_insertar_idx = #lineas + 1
                local indent_str_padre = ""

                for _, padre in ipairs(jerarquia) do
                    local encontrado = false

                    for i, linea in ipairs(lineas) do
                        local nivel, str_espacios = obtener_indentacion(linea)

                        if es_clave(linea, padre) and nivel > indent_actual then
                            indent_actual = nivel
                            indent_str_padre = str_espacios
                            linea_insertar_idx = i + 1
                            encontrado = true
                            break
                        end
                    end

                    if not encontrado then
                        local nueva_indent = indent_str_padre .. "  "
                        if indent_actual == -1 then
                            nueva_indent = ""
                        end

                        local nueva_linea = nueva_indent .. padre .. ":"

                        if linea_insertar_idx > #lineas then
                            table.insert(lineas, nueva_linea)
                            linea_insertar_idx = #lineas + 1
                        else
                            table.insert(lineas, linea_insertar_idx, nueva_linea)
                            linea_insertar_idx = linea_insertar_idx + 1
                        end

                        cambio_realizado = true
                        indent_actual = #nueva_indent
                        indent_str_padre = nueva_indent
                    end
                end

                local indent_final = indent_str_padre .. "  "
                if #jerarquia == 0 then
                    indent_final = ""
                end

                local encontrado_campo = false

                for i, linea in ipairs(lineas) do
                    local nivel, _ = obtener_indentacion(linea)

                    if es_clave(linea, campo) and nivel == #indent_final then
                        local valor_actual = linea:match(":%s*(.+)$")
                        if valor_actual then
                            valor_actual = vim.trim(valor_actual)
                        end

                        if valor_actual ~= valor then
                            lineas[i] = indent_final .. campo .. ": " .. valor
                            cambio_realizado = true
                        end

                        encontrado_campo = true
                        break
                    end
                end

                if not encontrado_campo then
                    local nueva_linea = indent_final .. campo .. ": " .. valor
                    if linea_insertar_idx > #lineas then
                        table.insert(lineas, nueva_linea)
                    else
                        table.insert(lineas, linea_insertar_idx, nueva_linea)
                    end
                    cambio_realizado = true
                end

                return cambio_realizado
            end

            local function gestionar_archivo_config(ruta_archivo, configuraciones)
                local lineas = {}
                if vim.fn.filereadable(ruta_archivo) == 1 then
                    lineas = vim.fn.readfile(ruta_archivo)
                end

                local hubo_algun_cambio = false

                for _, config in ipairs(configuraciones) do
                    local cambiado = inyectar_yaml(lineas, config.padres, config.clave, config.valor)
                    if cambiado then
                        hubo_algun_cambio = true
                    end
                end

                if hubo_algun_cambio then
                    local dir = vim.fn.fnamemodify(ruta_archivo, ":p:h")
                    if vim.fn.isdirectory(dir) == 0 then
                        vim.fn.mkdir(dir, "p")
                    end

                    vim.fn.writefile(lineas, ruta_archivo)
                    vim.notify(
                        "Configuración actualizada: " .. vim.fn.fnamemodify(ruta_archivo, ":t"),
                        vim.log.levels.INFO
                    )
                    vim.cmd("checktime")
                end
            end

            local function build_arduino_receta(base_dir)
                local ruta_win = normalize_path(base_dir)
                if is_windows then
                    ruta_win = ruta_win:gsub("/", "\\")
                end

                return {
                    {
                        padres = { "directories" },
                        clave = "user",
                        valor = ruta_win,
                    },
                    {
                        padres = { "logging" },
                        clave = "level",
                        valor = "info",
                    },
                }
            end

            function GestionarEntornoArduino(base_dir)
                local dir_actual = normalize_path(base_dir or vim.fn.expand("%:p:h"))
                local archivo_yaml = dir_actual .. "/arduino-cli.yaml"
                local receta = build_arduino_receta(dir_actual)
                gestionar_archivo_config(archivo_yaml, receta)
            end

            local function get_fqbn(root_dir)
                local default_fqbn = "arduino:avr:uno"
                local sketch_yaml = normalize_path(root_dir) .. "/sketch.yaml"

                local file = io.open(sketch_yaml, "r")
                if not file then
                    return default_fqbn
                end

                local fqbn = default_fqbn
                for line in file:lines() do
                    local match = line:match("fqbn:%s*([%w%p%-:_]+)")
                    if match then
                        fqbn = match
                        break
                    end
                end
                file:close()

                return fqbn
            end

            local function get_arduino_cli_config(root_dir)
                local local_config = normalize_path(root_dir) .. "/arduino-cli.yaml"
                if vim.fn.filereadable(local_config) == 1 then
                    return local_config
                end

                return get_default_arduino_cli_config()
            end

            -- ============================================================
            -- 3. RESOLVER BINARIOS NECESARIOS
            -- ============================================================

            local cmd_server = resolve_program("arduino-language-server", "arduino-language-server")
            local cmd_cli = resolve_program("arduino-cli", "arduino-cli")
            local cmd_clangd = resolve_program("clangd", "clangd")

            -- ============================================================
            -- 4. ARDUINO LSP
            -- ============================================================

            vim.api.nvim_create_autocmd("FileType", {
                pattern = "arduino",
                callback = function(ev)
                    if not cmd_server or not cmd_cli or not cmd_clangd then
                        return
                    end

                    local root_dir = vim.fs.root(ev.buf, { "sketch.yaml", "arduino-cli.yaml", ".git", "*.ino" })
                        or vim.fn.getcwd()

                    root_dir = normalize_path(root_dir)

                    GestionarEntornoArduino(root_dir)

                    local fqbn = get_fqbn(root_dir)
                    local config_path = get_arduino_cli_config(root_dir)

                    local capabilities_arduino = vim.lsp.protocol.make_client_capabilities()
                    capabilities_arduino.textDocument.completion.completionItem.snippetSupport = true
                    capabilities_arduino.workspace.semanticTokens = { refreshSupport = false }
                    capabilities_arduino.textDocument.semanticTokens = { dynamicRegistration = false }

                    vim.lsp.start({
                        name = "arduino_language_server",
                        cmd = {
                            cmd_server,
                            "-cli",
                            cmd_cli,
                            "-clangd",
                            cmd_clangd,
                            "-cli-config",
                            config_path,
                            "-fqbn",
                            fqbn,
                        },
                        root_dir = root_dir,
                        capabilities = capabilities_arduino,
                        on_attach = function(client)
                            client.server_capabilities.semanticTokensProvider = nil
                            vim.notify("Arduino LSP: Conectando con Clangd en " .. cmd_clangd, vim.log.levels.INFO)
                        end,
                    })
                end,
            })

            -- ============================================================
            -- 5. PLANTILLA AUTOMÁTICA PARA ARDUINO (.ino)
            -- ============================================================

            vim.api.nvim_create_autocmd("BufNewFile", {
                pattern = "*.ino",
                callback = function()
                    local lines = {
                        "#define LED 13",
                        "#define BAUDRATE 9600",
                        "",
                        "void setup() {",
                        "  Serial.begin(BAUDRATE);",
                        "  delay(10);",
                        "  pinMode(LED, OUTPUT);",
                        "}",
                        "",
                        "void loop() {",
                        '  Serial.println("LED ON");',
                        "  digitalWrite(LED, 1);",
                        "  delay(500);",
                        '  Serial.println("LED OFF");',
                        "  digitalWrite(LED, 0);",
                        "  delay(500);",
                        "}",
                    }

                    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

                    vim.schedule(function()
                        vim.cmd("write")
                    end)
                end,
            })

            --------------------------------------------------------
            -- Kotlin LSP (Oficial JetBrains)
            --------------------------------------------------------
            local kotlin_binary = get_mason_binary("kotlin-lsp", "bin/intellij-server")

            if has_exe("kotlin-lsp") or has_exe("intellij-server") or vim.fn.filereadable(kotlin_binary) == 1 then
                vim.lsp.config.kotlin_lsp = {
                    default_config = {
                        cmd = { kotlin_binary, "--stdio" },
                        filetypes = { "kotlin" },
                        root_markers = {
                            "settings.gradle.kts",
                            "settings.gradle",
                            "build.gradle.kts",
                            "pom.xml",
                            ".git",
                        },
                        capabilities = capabilities,
                    },
                }
                vim.lsp.enable("kotlin_lsp")
            else
                notify_missing("kotlin-lsp")
            end

            --------------------------------------------------------
            -- Kotlin LSP
            --------------------------------------------------------
            --if has_exe("kotlin-lsp") or has_exe("kotlin-language-server") then
            --    vim.lsp.config.kotlin_lsp = {
            --        default_config = {
            --            capabilities = capabilities,
            --            single_file_support = false,
            --        },
            --    }
            --    vim.lsp.enable("kotlin_lsp")
            --else
            --    notify_missing("kotlin-lsp")
            --end

            --------------------------------------------------------
            -- Rust LSP (rust-analyzer)
            --------------------------------------------------------
            if has_exe("rust-analyzer") then
                vim.lsp.config.rust_analyzer = {
                    default_config = {
                        cmd = { "rust-analyzer" },
                        filetypes = { "rust" },
                        root_markers = { "Cargo.toml", "rust-project.json", ".git" },
                        single_file_support = true,
                        capabilities = capabilities,
                        settings = {
                            ["rust-analyzer"] = {
                                imports = {
                                    granularity = { group = "module" },
                                    prefix = "self",
                                },
                                cargo = {
                                    sysroot = "discover",
                                    allFeatures = true,
                                },
                                procMacro = { enable = true },
                            },
                        },
                    },
                }
                vim.lsp.enable("rust_analyzer")

                -- 🔔 NOTIFICACIÓN: Alerta si se abre un archivo sin Cargo.toml
                local rust_notice_group = vim.api.nvim_create_augroup("RustSingleFileNotice", { clear = true })
                vim.api.nvim_create_autocmd("FileType", {
                    group = rust_notice_group,
                    pattern = "rust",
                    callback = function(args)
                        local buf_path = vim.api.nvim_buf_get_name(args.buf)
                        if buf_path == "" then
                            return
                        end

                        -- Buscar el manifiesto del proyecto en la carpeta o hacia arriba
                        local root = vim.fs.root(args.buf, { "Cargo.toml", "rust-project.json" })
                        if not root then
                            vim.schedule(function()
                                vim.notify(
                                    "⚠️ rust-analyzer no funciona en archivos sueltos.\nEjecuta 'cargo init' para activar autocompletado y errores.",
                                    vim.log.levels.WARN,
                                    { title = "Rust LSP" }
                                )
                            end)
                        end
                    end,
                })
            else
                notify_missing("rust-analyzer")
            end

            ---------------------------------
            -- Matlab LSP
            ---------------------------------
            if has_exe("matlab-ls") then
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
                    },
                }
                vim.lsp.enable("matlab_ls")
            end

            ------------------------------------------------------------
            -- Atajos de Teclado del LSP (Solo los necesarios)
            ------------------------------------------------------------

            -- [1] ATAJOS QUE NEOVIM NO INCLUYE POR DEFECTO:
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "LSP: Ir a Definición" })
            vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "LSP: Ir a Declaración (Cabecera)" })
            vim.keymap.set("n", "gl", vim.diagnostic.open_float, { desc = "Mostrar diagnostic flotante" })

            -- [2] TUS SOBREESCRITURAS (Porque prefieres usar tu <leader> en lugar de los nativos 'gra' y 'grn'):
            vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "LSP: Acciones de Código" })

            -- =========================================================
            -- Smart Rename para LSP
            -- =========================================================
            --
            -- Problema:
            -- ---------------------------------------------------------
            -- El rename nativo:
            --
            --     vim.lsp.buf.rename()
            --
            -- funciona perfectamente en la mayoría de LSPs modernos
            -- (Pyright, LuaLS, Rust Analyzer, etc.).
            --
            -- Sin embargo, con clangd puede ocurrir un problema de
            -- sincronización:
            --
            --   1. El rename se aplica correctamente en memoria.
            --   2. Pero clangd NO refresca inmediatamente el AST.
            --   3. Aparecen diagnostics falsos temporales.
            --
            -- Ejemplo:
            --
            --   "Call to undeclared function"
            --
            -- El error desaparece al ejecutar:
            --
            --     :wa
            --
            -- porque clangd depende mucho de:
            --
            --   - didSave
            --   - reparseo desde disco
            --   - background indexing
            --   - include graph
            --
            -- especialmente en proyectos grandes de C/C++.
            --
            --
            -- Solución:
            -- ---------------------------------------------------------
            -- Implementar manualmente el request:
            --
            --     textDocument/rename
            --
            -- y guardar TODOS los buffers únicamente cuando el
            -- WorkspaceEdit haya terminado de aplicarse.
            --
            -- Esto evita:
            --
            --   - race conditions
            --   - timers arbitrarios
            --   - delays dependientes del tamaño del proyecto
            --
            --
            -- NOTA IMPORTANTE:
            -- ---------------------------------------------------------
            -- Este workaround SOLO se aplica a clangd.
            --
            -- Los demás LSPs usan:
            --
            --     vim.lsp.buf.rename()
            --
            -- directamente.
            --
            --
            -- Referencias:
            -- ---------------------------------------------------------
            -- LSP Spec:
            --   textDocument/rename
            --
            -- Neovim:
            --   :help vim.lsp.Client.request()
            --   :help vim.lsp.util.apply_workspace_edit()
            --
            -- =========================================================

            -- ---------------------------------------------------------
            -- Rename especializado para clangd
            -- ---------------------------------------------------------
            local function clangd_rename()
                -- Obtener la palabra bajo el cursor.
                --
                -- <cword> = "current word"
                local curr_name = vim.fn.expand("<cword>")

                -- Mostrar prompt interactivo.
                vim.ui.input({
                    prompt = "Nuevo nombre: ",
                    default = curr_name,
                }, function(new_name)
                    -- Cancelar si:
                    --   - el usuario presiona ESC
                    --   - el nombre es vacío
                    --   - el nombre no cambió
                    if not new_name or new_name == curr_name then
                        return
                    end

                    -- Buscar el cliente clangd asociado
                    -- al buffer actual.
                    --
                    -- [1] porque get_clients() devuelve una lista.
                    local client = vim.lsp.get_clients({
                        bufnr = 0,
                        name = "clangd",
                    })[1]

                    -- Validar existencia del cliente.
                    if not client then
                        vim.notify("clangd no encontrado", vim.log.levels.ERROR)
                        return
                    end

                    -- Construir parámetros LSP para:
                    --
                    --   textDocument/rename
                    --
                    -- IMPORTANTE:
                    -- Se usa client.offset_encoding para evitar:
                    --
                    --   "multiple different client offset_encodings detected"
                    --
                    -- y:
                    --
                    --   "position_encoding param is required"
                    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)

                    -- Nuevo nombre solicitado.
                    params.newName = new_name

                    -- =====================================================
                    -- Request manual al servidor LSP
                    -- =====================================================
                    --
                    -- En vez de usar:
                    --
                    --     vim.lsp.buf.rename()
                    --
                    -- usamos directamente:
                    --
                    --     client:request(...)
                    --
                    -- para poder saber EXACTAMENTE cuándo termina
                    -- el rename.
                    --
                    -- Esto permite ejecutar:
                    --
                    --     :wall
                    --
                    -- únicamente después de aplicar el WorkspaceEdit.
                    -- =====================================================

                    client:request(
                        "textDocument/rename",
                        params,

                        -- Callback ejecutado cuando clangd responde.
                        function(err, result)
                            -- Manejo de errores LSP.
                            if err then
                                vim.notify(err.message, vim.log.levels.ERROR)
                                return
                            end

                            -- Aplicar WorkspaceEdit recibido.
                            --
                            -- Esto modifica:
                            --   - buffers
                            --   - referencias
                            --   - headers
                            --   - múltiples archivos
                            if result then
                                vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
                            end

                            -- =================================================
                            -- clangd necesita didSave
                            -- =================================================
                            --
                            -- Guardar TODOS los buffers modificados para
                            -- forzar:
                            --
                            --   - reparseo
                            --   - refresh del AST
                            --   - actualización de diagnostics
                            --
                            -- silent! evita mensajes molestos.
                            -- =================================================
                            vim.cmd("silent! wall")

                            vim.notify("Rename completado y guardado", vim.log.levels.INFO)
                        end,

                        -- Buffer actual
                        0
                    )
                end)
            end

            -- ---------------------------------------------------------
            -- Filetypes relacionados con clangd
            -- ---------------------------------------------------------
            --
            -- Incluye:
            --   - C
            --   - C++
            --   - Objective-C
            --   - headers
            --
            -- porque el problema también ocurre en:
            --   .h
            --   .hpp
            --   .hh
            --   etc.
            -- ---------------------------------------------------------
            local clang_filetypes = {
                c = true,
                cpp = true,
                cc = true,
                cxx = true,
                h = true,
                hpp = true,
                hh = true,
                hxx = true,
                objc = true,
                objcpp = true,
            }

            -- ---------------------------------------------------------
            -- Smart Rename
            -- ---------------------------------------------------------
            --
            -- Selecciona automáticamente:
            --
            --   - clangd_rename() para C/C++
            --   - vim.lsp.buf.rename() para el resto
            --
            -- Esto evita aplicar workarounds innecesarios
            -- a otros LSPs que ya funcionan correctamente.
            -- ---------------------------------------------------------
            local function smart_rename()
                if clang_filetypes[vim.bo.filetype] then
                    -- Workaround especializado para clangd
                    clangd_rename()
                else
                    -- Rename estándar para cualquier otro LSP
                    vim.lsp.buf.rename()
                end
            end

            -- ---------------------------------------------------------
            -- Keymap
            -- ---------------------------------------------------------
            vim.keymap.set("n", "<leader>rn", smart_rename, {
                desc = "Smart LSP Rename",
            })

            -- =========================================================
            -- NOTA SOBRE LOS KEYMAPS LSP EN NEOVIM 0.11+
            -- =========================================================
            --
            -- Neovim moderno ya incluye MUCHOS keymaps LSP por
            -- defecto, por lo que NO necesitas configurarlos manualmente.
            --
            -- Incluidos automáticamente:
            --
            --   K     -> hover
            --   grr   -> references
            --   gri   -> implementation
            --   grn   -> rename
            --   gra   -> code action
            --   grt   -> type definition
            --   [d    -> previous diagnostic
            --   ]d    -> next diagnostic
            --
            -- Documentación oficial:
            --   :help lsp-defaults
            --
            -- Referencias:
            --   https://neovim.io/doc/user/lsp/
            --   https://neovim.io/doc/user/news-0.11/
            --
            -- Por eso este archivo solo define mappings
            -- personalizados realmente necesarios.
            --
            -- =========================================================
        end,
    },
}
