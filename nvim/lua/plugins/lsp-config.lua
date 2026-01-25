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
                    "arduino_language_server",
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
            local ps_bundle_path = vim.fn.stdpath("data") .. "/mason/packages/powershell-editor-services"

            vim.lsp.config("powershell_es", {
                -- Esto sobreescribe la función automática que falla en Windows
                cmd = {
                    "pwsh", -- o "powershell.exe" si no tienes PS7
                    "-NoLogo",
                    "-NoProfile",
                    "-ExecutionPolicy", "Bypass",
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


            ---------------------------------
            -- Arduino LSP  (usa clangd + arduino-cli)
            ---------------------------------


            -- ============================================================
            -- 2. FUNCIÓN DE ACTUALIZACIÓN INTELIGENTE (ESTRUCTURAL)
            -- ============================================================
            --
            -- ============================================================
            -- 2.1 HERRAMIENTAS AUXILIARES
            -- ============================================================

            -- Cuenta cuántos espacios de indentación tiene una línea
            local function obtener_indentacion(linea)
                local espacios = linea:match("^(%s*)")
                return #espacios, espacios -- Retorna el número y el string de espacios
            end

            -- Verifica si una línea es el inicio de una clave YAML (ej: "  directories:")
            local function es_clave(linea, clave)
                -- Busca: espacios opcionales + clave + dos puntos
                return linea:match("^%s*" .. clave .. ":") ~= nil
            end

            -- ============================================================
            -- 2.2 FUNCIÓN DE LÓGICA PURA (El "Cerebro")
            -- ============================================================
            --- Navega, verifica y crea/actualiza un campo en una lista de líneas YAML
            --- @param lineas table: Lista de strings (el archivo leído)
            --- @param jerarquia table: Lista de padres (ej: {"directories", "advanced"})
            --- @param campo string: El campo final a editar (ej: "user")
            --- @param valor string: El valor que debe tener
            --- @return boolean: true si hubo cambios, false si no
            local function inyectar_yaml(lineas, jerarquia, campo, valor)
                local cambio_realizado = false
                local indent_actual = -1               -- Nivel de indentación actual (-1 es la raíz)
                local linea_insertar_idx = #lineas + 1 -- Por defecto al final del archivo
                local indent_str_padre = ""            -- String de indentación del padre actual

                -- 1. NAVEGAR LA JERARQUÍA (PADRES)
                -- Buscamos o creamos cada padre en la lista
                for _, padre in ipairs(jerarquia) do
                    local encontrado = false

                    -- Buscamos el padre dentro del rango actual
                    -- (En una implementación simple, buscamos desde el inicio o desde el último padre)
                    for i, linea in ipairs(lineas) do
                        local nivel, str_espacios = obtener_indentacion(linea)

                        -- Si encontramos la clave y está un nivel más adentro que el anterior
                        if es_clave(linea, padre) and nivel > indent_actual then
                            indent_actual = nivel
                            indent_str_padre = str_espacios
                            linea_insertar_idx = i + 1 -- Si tenemos que insertar hijos, será después de este
                            encontrado = true
                            break
                        end
                    end

                    -- Si no existe el padre, hay que crearlo
                    if not encontrado then
                        -- Calculamos la indentación nueva (2 espacios más que el nivel anterior)
                        local nueva_indent = indent_str_padre .. "  "
                        if indent_actual == -1 then nueva_indent = "" end -- Si es raíz, sin indentación

                        -- Insertamos el padre
                        local nueva_linea = nueva_indent .. padre .. ":"

                        -- Si linea_insertar_idx es mayor que el total, es un insert al final
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

                -- 2. GESTIONAR EL CAMPO FINAL (TARGET)
                -- Ahora que 'linea_insertar_idx' apunta dentro del bloque correcto

                local indent_final = indent_str_padre .. "  "
                if #jerarquia == 0 then indent_final = "" end -- Caso borde: sin padres

                local encontrado_campo = false

                -- Buscamos si el campo ya existe en el bloque (escaneo simple)
                -- Nota: Para ser 100% robusto necesitaríamos saber dónde termina el bloque,
                -- pero para configs simples, buscar la clave con la indentación correcta basta.
                for i, linea in ipairs(lineas) do
                    local nivel, _ = obtener_indentacion(linea)

                    -- Verificamos que sea la clave Y que tenga la indentación exacta esperada
                    if es_clave(linea, campo) and nivel == #indent_final then
                        -- ¡Campo encontrado! Verificamos valor
                        local valor_actual = linea:match(":%s*(.+)$")
                        -- Limpiamos espacios extra del valor capturado
                        if valor_actual then valor_actual = vim.trim(valor_actual) end

                        if valor_actual ~= valor then
                            lineas[i] = indent_final .. campo .. ": " .. valor
                            cambio_realizado = true
                        end
                        encontrado_campo = true
                        break
                    end
                end

                -- Si no existe el campo, lo insertamos
                if not encontrado_campo then
                    local nueva_linea = indent_final .. campo .. ": " .. valor
                    -- Insertamos justo después del último padre encontrado (al principio del bloque)
                    if linea_insertar_idx > #lineas then
                        table.insert(lineas, nueva_linea)
                    else
                        table.insert(lineas, linea_insertar_idx, nueva_linea)
                    end
                    cambio_realizado = true
                end

                return cambio_realizado
            end

            -- ============================================================
            -- 2.3 FUNCIÓN DE GESTIÓN DE ARCHIVO (El Coordinador)
            -- ============================================================

            local function gestionar_archivo_config(ruta_archivo, configuraciones)
                -- 1. Leer archivo (o crear lista vacía si no existe)
                local lineas = {}
                if vim.fn.filereadable(ruta_archivo) == 1 then
                    lineas = vim.fn.readfile(ruta_archivo)
                end

                local hubo_algun_cambio = false

                -- 2. Aplicar cada configuración solicitada
                for _, config in ipairs(configuraciones) do
                    -- config debe tener: { padres = {}, clave = "user", valor = "..." }
                    local cambiado = inyectar_yaml(lineas, config.padres, config.clave, config.valor)
                    if cambiado then hubo_algun_cambio = true end
                end

                -- 3. Guardar solo si es necesario
                if hubo_algun_cambio then
                    -- Crear directorio padre si no existe (seguridad extra)
                    local dir = vim.fn.fnamemodify(ruta_archivo, ":p:h")
                    if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end

                    vim.fn.writefile(lineas, ruta_archivo)
                    vim.notify("Configuración actualizada: " .. vim.fn.fnamemodify(ruta_archivo, ":t"),
                        vim.log.levels.INFO)
                    vim.cmd("checktime") -- Actualizar buffer si está abierto
                else
                    vim.notify("Verificación completada. Todo correcto.", vim.log.levels.INFO)
                end
            end


            local function dir_exists(path)
              local stat = vim.loop.fs_stat(path)
              return stat and stat.type == "directory"
            end

            function GestionarEntornoArduino()
                -- Ubicación del buffer:
                local dir_actual = vim.fn.expand("%:p:h")
                --vim.notify("GestionarEntornoArduino: "..dir_actual)
                -----local dir_actual = vim.fn.getcwd()

                if not dir_exists(dir_actual.."/libraries") then
                    return
                end

                -- Preparar ruta Windows
                local ruta_win = dir_actual:gsub("/", "\\")
                if ruta_win:sub(-1) == "\\" then ruta_win = ruta_win:sub(1, -2) end

                local archivo_yaml = dir_actual .. "/arduino-cli.yaml"

                -- DEFINIMOS LA RECETA:
                -- Aquí especificamos qué campos queremos validar/crear
                local receta = {
                    {
                        padres = { "directories" }, -- Lista de padres
                        clave  = "user",          -- Campo final
                        valor  = ruta_win         -- Valor deseado
                    },
                    -- {
                    --     padres = {"directories"},
                    --     clave  = "data",
                    --     valor  = ruta_win .. "\\data"
                    -- },
                    -- {
                    --     padres = {"directories"},
                    --     clave  = "downloads",
                    --     valor  = ruta_win .. "\\staging"
                    -- },
                    -- Ejemplo de cómo generalizar: Podrías añadir algo de logging fácilmente
                    {
                        padres = { "logging" },
                        clave  = "level",
                        valor  = "info"
                    }
                }

                -- Ejecutamos la magia
                gestionar_archivo_config(archivo_yaml, receta)
            end

            --- Arduino lsp
            -- =============================================================================
            -- AYUDANTE PARA ENCONTRAR BINARIOS DE MASON (RUTA ABSOLUTA)
            -- =============================================================================
            local function get_mason_binary(package, binary)
                local mason_path = vim.fn.stdpath("data") .. "/mason"
                local path = mason_path .. "/bin/" .. binary .. ".exe"

                -- Si no está en /bin, busca en /packages (estructura interna de Mason)
                if vim.fn.filereadable(path) == 0 then
                    path = mason_path .. "/packages/" .. package .. "/" .. binary .. ".exe"
                end

                if vim.fn.filereadable(path) == 1 then
                    return path:gsub("\\", "/") -- Importante: slashes normales para Windows
                end

                return binary -- Fallback al sistema si falla todo
            end

            vim.api.nvim_create_autocmd("FileType", {
                pattern = "arduino",
                callback = function(ev)
                    local root_dir    = vim.fs.root(ev.buf, { "sketch.yaml", "arduino-cli.yaml", ".git", "*.ino" }) or
                    vim.fn.getcwd()

                    -- OBTENER RUTAS ABSOLUTAS
                    local cmd_server  = get_mason_binary("arduino-language-server", "arduino-language-server")
                    local cmd_cli     = get_mason_binary("arduino-cli", "arduino-cli")
                    -- Aquí está la clave: Forzamos el Clangd de Mason
                    local cmd_clangd  = get_mason_binary("clangd", "clangd")

                    -- FQBN y Config
                    local fqbn        = "arduino:avr:uno"
                    local sketch_yaml = root_dir .. "/sketch.yaml"
                    local f           = io.open(sketch_yaml, "r")
                    if f then
                        for line in f:lines() do
                            local m = line:match("fqbn:%s*([%w%p%-:_]+)")
                            if m then
                                fqbn = m; break
                            end
                        end
                        f:close()
                    end

                    GestionarEntornoArduino()
                    local config_path = vim.fn.expand("$LOCALAPPDATA/Arduino15/arduino-cli.yaml"):gsub("\\", "/")
                    local local_config = root_dir .. "/arduino-cli.yaml"
                    if vim.fn.filereadable(local_config) == 1 then config_path = local_config:gsub("\\", "/") end

                    -- CAPABILITIES
                    local capabilities = vim.lsp.protocol.make_client_capabilities()
                    capabilities.textDocument.completion.completionItem.snippetSupport = true
                    capabilities.workspace.semanticTokens = { refreshSupport = false }
                    capabilities.textDocument.semanticTokens = { dynamicRegistration = false }

                    vim.lsp.start({
                        name = "arduino_language_server",
                        cmd = {
                            cmd_server,
                            "-cli", cmd_cli,
                            "-clangd", cmd_clangd, -- Ahora pasamos la ruta completa C:/.../clangd.exe
                            "-cli-config", config_path,
                            "-fqbn", fqbn,
                            --"-log"
                        },
                        root_dir = root_dir,
                        capabilities = capabilities,
                        on_attach = function(client)
                            client.server_capabilities.semanticTokensProvider = nil
                            vim.notify("Arduino LSP: Conectando con Clangd en " .. cmd_clangd, vim.log.levels.INFO)
                        end,
                    })
                end,
            })

-- =============================================================================
-- [NUEVO] PLANTILLA AUTOMÁTICA PARA ARDUINO (.ino)
-- =============================================================================
-- Esto se pega FUERA del vim.lsp.start, al final del archivo.
-- Detecta archivos nuevos, escribe el esqueleto básico y guarda.

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
        -- 1. Escribir las líneas en el buffer
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        
        -- 2. Guardar automáticamente (CRUCIAL para que el LSP no falle)
        vim.schedule(function()
            vim.cmd("write")
        end)
    end
})

            
            ----  -- 1. Función unificada para obtener el FQBN
            ----  -- Acepta un 'root_dir' opcional para ser robusta ante cambios de directorio
            ----  local function get_fqbn(root_dir)
            ----      vim.notify("estas en [get_fqbn]")
            ----      local default_fqbn = "esp32:esp32:esp32doit-devkit-v1"
            ----      -- Si no hay root_dir, usa el directorio actual
            ----      local path = (root_dir or ".") .. "/sketch.yaml"
            ----
            ----      local file = io.open(path, "r")
            ----      if not file then return default_fqbn end
            ----
            ----      local fqbn = default_fqbn
            ----      for line in file:lines() do
            ----          if line:find("fqbn:") then
            ----              -- Captura mejorada para evitar espacios extra
            ----              local match = line:match("fqbn:%s*([%w%p%-:_]+)")
            ----              if match then
            ----                  fqbn = match
            ----                  break
            ----              end
            ----          end
            ----      end
            ----      file:close()
            ----      return fqbn
            ----  end
            ----
            ----  -- 2. Función para determinar el archivo de configuración CLI
            ----  local function get_cli_config(root_dir)
            ----      vim.notify("estas en [get_cli_config]")
            ----      local local_conf = (root_dir or ".") .. "/arduino-cli.yaml"
            ----      local global_conf = vim.fn.expand("$LOCALAPPDATA/Arduino15/arduino-cli.yaml")
            ----
            ----      -- Si existe el local, úsalo. Si no, usa el global.
            ----      if vim.fn.filereadable(local_conf) == 1 then
            ----          return local_conf
            ----      else
            ----          return global_conf
            ----      end
            ----  end
            ----
            ----  -- 3. Configuración del LSP
            ----  vim.lsp.config("arduino_language_server", {
            ----      cmd = {
            ----          "arduino-language-server",
            ----          "-cli", "arduino-cli",
            ----          "-clangd", "clangd",
            ----          "-cli-config", get_cli_config(vim.fn.expand("%:p:h")),
            ----          "-fqbn", get_fqbn(vim.fn.expand("%:p:h"))
            ----          -- Los argumentos dinámicos se inyectan en on_new_config
            ----      },
            ----      root_markers = { "sketch.yaml", "*.ino", ".git" },
            ----      filetypes = { "arduino" },
            ----
            ----      on_new_config = function(new_config, new_root_dir)
            ----          vim.notify("estas en [on_new_config]")
            ----          -- Recalculamos FQBN y Config Path basándonos en el directorio real del proyecto
            ----          local fqbn = get_fqbn(new_root_dir)
            ----          local cli_config = get_cli_config(new_root_dir)
            ----
            ----          -- Reconstruimos el comando completo
            ----          new_config.cmd = {
            ----              "arduino-language-server",
            ----              "-cli", "arduino-cli",
            ----              "-clangd", "clangd",
            ----              "-cli-config", cli_config,
            ----              "-fqbn", fqbn
            ----          }
            ----      end,
            ----  })
            ----
            ----  vim.lsp.enable("arduino_language_server")

            --  -- 1. Función auxiliar para leer el FQBN del sketch.yaml
            --  local function get_fqbn()
            --      local fqbn = "esp32:esp32:esp32doit-devkit-v1" -- Valor por defecto si falla
            --      local file = io.open("sketch.yaml", "r")
            --
            --      if file then
            --          for line in file:lines() do
            --              -- Busca la línea que tenga "fqbn:"
            --              if line:find("fqbn:") then
            --                  -- Extrae el texto después de los dos puntos y limpia espacios
            --                  fqbn = line:match("fqbn:%s*([%w%p]+)")
            --                  break
            --              end
            --          end
            --          file:close()
            --      end
            --      return fqbn
            --  end
            --
            --  -- 2. Configuración del LSP
            --  --
            --  -- Esta función esta  defininda en "init.lua":
            --  --   Se usa para crear el archivo "arduino-cli.yam" en el mismo
            --  --   directorio que el archivo [.ino] que se acaba de de abrir,
            --  --   y contiene la ubicación de las librería locales.
            --  GestionarEntornoArduino()

            --  vim.lsp.config("arduino_language_server", {
            --      cmd = {
            --          "arduino-language-server",
            --          "-cli", "arduino-cli",
            --          "-clangd", "clangd",
            --          -- Ficheros con las ubicaciones de las librerias de Arduino.
            --          -- LIBRERIAS GLOBALES
            --          "-cli-config", vim.fn.expand("$LOCALAPPDATA/Arduino15/arduino-cli.yaml"),
            --          -- LIBRERIAS LOCALES (se debe crear el archivo "arduino-cli.yaml")
            --          "-cli-config", vim.fn.expand("./arduino-cli.yaml"),
            --          "-fqbn", get_fqbn()
            --      },
            --      root_markers = { "sketch.yaml", "*.ino", ".git" },
            --      filetypes = { "arduino" },
            --      on_new_config = function(new_config, new_root_dir)
            --          -- Esto asegura que si cambias de carpeta, se recalcule el FQBN
            --          local fqbn = "esp32:esp32:esp32doit-devkit-v1"
            --          local file = io.open(new_root_dir .. "/sketch.yaml", "r")
            --          if file then
            --              for line in file:lines() do
            --                  if line:find("fqbn:") then
            --                      fqbn = line:match("fqbn:%s*([%w%p]+)")
            --                      break
            --                  end
            --              end
            --              file:close()
            --          end
            --
            --          -- Actualizamos los argumentos del comando dinámicamente
            --          new_config.cmd = {
            --              "arduino-language-server",
            --              "-cli", "arduino-cli",
            --              "-clangd", "clangd",
            --              -- Ficheros con las ubicaciones de las librerias de Arduino.
            --              -- LIBRERIAS GLOBALES
            --              "-cli-config", vim.fn.expand("$LOCALAPPDATA/Arduino15/arduino-cli.yaml"),
            --              -- LIBRERIAS LOCALES (se debe crear el archivo "arduino-cli.yaml")
            --              "-cli-config", vim.fn.expand("./arduino-cli.yaml"),
            --              "-fqbn", fqbn
            --          }
            --      end
            --  })
            --
            --  vim.lsp.enable("arduino_language_server")

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
