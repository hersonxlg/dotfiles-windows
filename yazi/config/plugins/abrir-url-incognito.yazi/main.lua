local M = {}

local obtener_ruta_hovered = ya.sync(function()
    local hovered = cx.active.current.hovered
    if hovered then return tostring(hovered.url) end
    return nil
end)

function M:entry(job)
    local path = obtener_ruta_hovered()
    if not path then return end

    local file = io.open(path, "r")
    if not file then return end
    
    local content = file:read("*a")
    file:close()

    local link = content:match("[Uu][Rr][Ll]%s*=%s*(https?://[^\r\n]+)")

    if link then
        ya.notify({ 
            title = "Brave Incógnito", 
            content = "Abriendo enlace de forma segura...", 
            level = "info",
            timeout = 2 
        })
        
        if ya.target_family() == "windows" then
            -- ----------------------------------------------------
            -- WINDOWS: Usar CMD con start y escape de símbolos
            -- ----------------------------------------------------
            local link_escapado = link:gsub("%^", "^^"):gsub("&", "^&")
            local comando = "start brave --incognito " .. link_escapado

            local output, err = Command("cmd")
                :arg("/c")
                :arg(comando)
                :output()

            if not output then
                ya.notify({ 
                    title = "Error de Ejecución", 
                    content = tostring(err), 
                    level = "error", 
                    timeout = 5 
                })
            end
        else
            -- ----------------------------------------------------
            -- LINUX / MACOS: Desvincular con systemd-run / nohup y :output()
            -- ----------------------------------------------------
            local cmd_linux = string.format(
                "systemd-run --user --scope brave --incognito %q >/dev/null 2>&1 || nohup brave --incognito %q >/dev/null 2>&1 &",
                link, link
            )

            local output, err = Command("sh")
                :arg("-c")
                :arg(cmd_linux)
                :output()

            if not output then
                ya.notify({ 
                    title = "Error de Ejecución", 
                    content = tostring(err), 
                    level = "error", 
                    timeout = 5 
                })
            end
        end
    else
        ya.notify({ 
            title = "Brave", 
            content = "No se encontró un enlace válido.", 
            level = "warn", 
            timeout = 3 
        })
    end
end

return M
