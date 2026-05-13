return {
    ---------------------------------
    -- Install "Mason"
    ---------------------------------
    {
        "williamboman/mason.nvim",
        lazy = false,
        config = function()
            require("mason").setup()
        end,
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
                    "arduino_language_server",
                    "asm_lsp",
                    "vimls",
                },
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
        },
        lazy = false,
        config = function()
            local capabilities = require("cmp_nvim_lsp").default_capabilities()
            local uv = vim.uv or vim.loop

            local function notify_missing(name)
                vim.notify(name .. " no está instalado o no está en PATH", vim.log.levels.WARN)
            end

            local function has_exe(name)
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
                local is_windows = vim.fn.has("win32") == 1
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

            --------------------------------------------------------
            -- clangd
            --------------------------------------------------------
            if has_exe("clangd") then
                local query_driver = os_home() .. "/.platformio/packages/toolchain-*/bin/*"

                vim.lsp.config.clangd = {
                    default_config = {
                        cmd = {
                            "clangd",
                            "--background-index",
                            "--query-driver=" .. query_driver,
                        },
                        root_dir = function(fname)
                            return vim.fs.root(fname, {
                                "compile_commands.json",
                                "platformio.ini",
                                ".git",
                            }) or vim.fs.dirname(fname)
                        end,
                        capabilities = capabilities,
                    },
                }
                vim.lsp.enable("clangd")
            else
                notify_missing("clangd")
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
            -- pylsp
            --------------------------------------------------------
            if has_exe("pylsp") then
                vim.lsp.config.pylsp = {
                    default_config = {
                        cmd = { "pylsp" },
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
                    },
                }
                vim.lsp.enable("pylsp")
            else
                notify_missing("pylsp")
            end

            --------------------------------------------------------
            -- lua_ls
            --------------------------------------------------------
            if has_exe("lua-language-server") then
                vim.lsp.config.lua_ls = {
                    default_config = {
                        cmd = { "lua-language-server" },
                        capabilities = capabilities,
                    },
                }
                vim.lsp.enable("lua_ls")
            else
                notify_missing("lua-language-server")
            end

            --------------------------------------------------------
            -- ts_ls
            --------------------------------------------------------
            if has_exe("typescript-language-server") then
                vim.lsp.config.ts_ls = {
                    default_config = {
                        cmd = { "typescript-language-server", "--stdio" },
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
            -- PlatformIO AUTOSETUP para clangd
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

            local function build_clangd_template(platformio_ini_text)
                local text = (platformio_ini_text or ""):lower()

                local lines = {
                    "CompileFlags:",
                    "  Add:",
                }

                if text:find("platform%s*=%s*espressif32") or text:find("espressif32") or text:find("esp32") then
                    table.insert(lines, "    - --target=xtensa-esp32-elf")
                elseif text:find("platform%s*=%s*atmelavr") or text:find("atmelavr") then
                    table.insert(lines, "    - --target=avr")
                end

                table.insert(lines, "  Remove:")
                table.insert(lines, "    - -mlongcalls")
                table.insert(lines, "    - -fstrict-volatile-bitfields")
                table.insert(lines, "    - -fno-tree-switch-conversion")
                table.insert(lines, "    - -free")
                table.insert(lines, "    - -fipa-pta")
                table.insert(lines, "")
                table.insert(lines, "Diagnostics:")
                table.insert(lines, "  Suppress:")
                table.insert(lines, "    - pp_file_not_found")
                table.insert(lines, "    - type_unsupported")
                table.insert(lines, "    - machine_mode")

                return lines
            end

            local function write_clangd(root)
                local ini_path = root .. "/platformio.ini"
                local clangd_file = root .. "/.clangd"
                local ini_text = read_file(ini_path)
                local new_lines = build_clangd_template(ini_text)

                vim.fn.writefile(new_lines, clangd_file)
            end

            local function ensure_platformio_setup(bufnr)
                local root = platformio_root(bufnr)
                if not root then
                    return
                end
            
                local pio_cmd = find_pio()
                if not pio_cmd then
                    vim.notify(
                        "PlatformIO no está instalado o no está en PATH",
                        vim.log.levels.ERROR
                    )
                    return
                end
            
                ------------------------------------------------------------
                -- Asegurar compile_commands.json en .gitignore
                ------------------------------------------------------------
            
                local function ensure_gitignore_entry(entry)
                    local gitignore = root .. "/.gitignore"
                    local lines = {}
            
                    -- Leer archivo si existe
                    if vim.fn.filereadable(gitignore) == 1 then
                        lines = vim.fn.readfile(gitignore)
            
                        -- Verificar si ya existe
                        for _, line in ipairs(lines) do
                            if vim.trim(line) == entry then
                                return
                            end
                        end
                    end
            
                    -- Agregar línea
                    table.insert(lines, entry)
            
                    -- Escribir archivo
                    vim.fn.writefile(lines, gitignore)
            
                    vim.notify(
                        ".gitignore actualizado: " .. entry,
                        vim.log.levels.INFO
                    )
                end
            
                ensure_gitignore_entry("compile_commands.json")
            
                ------------------------------------------------------------
                -- Archivos PlatformIO
                ------------------------------------------------------------
            
                local ini_path = root .. "/platformio.ini"
                local compiledb = root .. "/compile_commands.json"
                local clangd_file = root .. "/.clangd"
            
                local ini_time = vim.fn.getftime(ini_path)
            
                local db_time =
                    vim.fn.filereadable(compiledb) == 1
                    and vim.fn.getftime(compiledb)
                    or -1
            
                local clangd_time =
                    vim.fn.filereadable(clangd_file) == 1
                    and vim.fn.getftime(clangd_file)
                    or -1
            
                local need_compiledb =
                    vim.fn.filereadable(compiledb) == 0
                    or ini_time > db_time
            
                local need_clangd =
                    vim.fn.filereadable(clangd_file) == 0
                    or ini_time > clangd_time
            
                ------------------------------------------------------------
                -- Regenerar .clangd
                ------------------------------------------------------------
            
                if need_clangd then
                    write_clangd(root)
            
                    vim.notify(
                        "PlatformIO: .clangd actualizado",
                        vim.log.levels.INFO
                    )
                end
            
                ------------------------------------------------------------
                -- Regenerar compile_commands.json
                ------------------------------------------------------------
            
                if need_compiledb then
                    vim.notify(
                        "PlatformIO: generando compile_commands.json...",
                        vim.log.levels.INFO
                    )
            
                    vim.fn.jobstart(
                        { pio_cmd, "run", "-t", "compiledb" },
                        {
                            cwd = root,
            
                            on_exit = function(_, code)
                                if code == 0 then
                                    vim.schedule(function()
                                        vim.notify(
                                            "PlatformIO: compile_commands.json listo",
                                            vim.log.levels.INFO
                                        )
            
                                        vim.cmd("edit")
                                    end)
                                else
                                    vim.schedule(function()
                                        vim.notify(
                                            "PlatformIO: falló la generación de compile_commands.json",
                                            vim.log.levels.ERROR
                                        )
                                    end)
                                end
                            end,
                        }
                    )
            
                elseif need_clangd then
                    vim.schedule(function()
                        vim.cmd("edit")
                    end)
                end
            end

            local pio_group = vim.api.nvim_create_augroup("PlatformIOAutoSetup", { clear = true })

            vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
                group = pio_group,
                pattern = { "*.c", "*.cpp", "*.h", "*.hpp", "*.cc", "*.hh" },
                callback = function(args)
                    ensure_platformio_setup(args.buf)
                end,
            })

            ---------------------------------
            -- Tu bloque Arduino actual puede quedarse aquí
            -- sin cambios si todavía lo usas.
            ---------------------------------

            ---------------------------------
            -- Arduino LSP  (usa clangd + arduino-cli)
            ---------------------------------
            
            -- ============================================================
            -- 1. HERRAMIENTAS AUXILIARES
            -- ============================================================
            
            local function is_windows()
                return vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
            end
            
            local function normalize_path(path)
                return (path or ""):gsub("\\", "/")
            end
            
            local function program_exists(name)
                return vim.fn.executable(name) == 1
            end
            
            local function notify_missing(name)
                vim.notify(name .. " no está instalado o no está en PATH", vim.log.levels.WARN)
            end
            
            local function find_mason_binary(package, binary)
                local mason_path = vim.fn.stdpath("data") .. "/mason"
                local ext = is_windows() and ".exe" or ""
            
                local path = mason_path .. "/bin/" .. binary .. ext
                if vim.fn.filereadable(path) == 0 then
                    path = mason_path .. "/packages/" .. package .. "/" .. binary .. ext
                end
            
                if vim.fn.filereadable(path) == 1 then
                    return normalize_path(path)
                end
            
                return nil
            end
            
            local function resolve_program(package, binary)
                if program_exists(binary) then
                    return binary
                end
            
                local mason_path = find_mason_binary(package, binary)
                if mason_path then
                    return mason_path
                end
            
                return nil
            end
            
            local function get_default_arduino_cli_config()
                if is_windows() then
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
                if is_windows() then
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
            
            if not cmd_server then
                notify_missing("arduino-language-server")
            end
            
            if not cmd_cli then
                notify_missing("arduino-cli")
            end
            
            if not cmd_clangd then
                notify_missing("clangd")
            end
            
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
                            vim.notify(
                                "Arduino LSP: Conectando con Clangd en " .. cmd_clangd,
                                vim.log.levels.INFO
                            )
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

            ---------------------------------
            -- Global keymaps
            ---------------------------------
            vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, {})
            vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, {})
        end,
    },
}
