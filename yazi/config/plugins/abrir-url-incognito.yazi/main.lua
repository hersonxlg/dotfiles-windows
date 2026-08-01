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
        
        -- TRUCO MAESTRO: Escapamos los símbolos especiales de Windows (^ y &)
        -- Esto nos permite enviar la URL limpia a la consola SIN usar comillas dobles
        local link_escapado = link:gsub("%^", "^^"):gsub("&", "^&")
        
        -- Construimos el comando completamente libre de comillas problemáticas
        local comando = "start brave --incognito " .. link_escapado

        -- Usamos :output() para obligar a Yazi a esperar los 10ms que tarda CMD en lanzar Brave
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
        ya.notify({ 
            title = "Brave", 
            content = "No se encontró un enlace válido.", 
            level = "warn", 
            timeout = 3 
        })
    end
end

return M
