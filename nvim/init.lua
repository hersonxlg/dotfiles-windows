require("vim._core.ui2").enable({})

------------------------------------------------------------
-- Instalar LAZY:
------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop
if not uv.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end

vim.opt.rtp:prepend(lazypath)

------------------------------------------------------------
-- Configuraciones de NeoVim:
------------------------------------------------------------
require("options")

------------------------------------------------------------
-- Configuraciones de NeoVim:
------------------------------------------------------------
require("keymaps")

------------------------------------------------------------
-- PLUGINS FOR LAZY:
------------------------------------------------------------
require("lazy").setup("plugins", {
    git = {
        timeout = 300, -- 5 minutos de tiempo límite para evitar descargas abortadas en Linux
    },
})

------------------------------------------------------------
-- Autocomando Multiplataforma (Linux / Windows)
------------------------------------------------------------
function RequireAll(relative_path)
    -- stdpath("config") obtiene dinámicamente ~/.config/nvim en Linux o AppData/Local/nvim en Windows
    local config_path = vim.fn.stdpath("config") .. "/lua/"
    local target_dir = config_path .. relative_path
    
    local paths = vim.split(vim.fn.globpath(target_dir, "*.lua"), "\n", { trimempty = true })
    
    for _, p in ipairs(paths) do
        -- Normalizamos barras inclinadas de Windows (\) a estilo Linux (/)
        local normalized_p = p:gsub("\\", "/")
        local normalized_config = config_path:gsub("\\", "/")
        
        -- Convertimos la ruta en formato del require de Lua (ejemplo: "autocmd.mis_autocmds")
        local module_name = normalized_p:gsub(normalized_config, ""):gsub("%.lua$", ""):gsub("/", ".")
        require(module_name)
    end
end

------------------------------------------------------------
-- Comandos Automáticos
------------------------------------------------------------
RequireAll("autocmd")

vim.opt.guicursor = {
    "n-v-c:block-Cursor/lCursor-blinkwait1000-blinkon100-blinkoff100",
    "i-ci:ver25-Cursor/lCursor-blinkwait1000-blinkon100-blinkoff100",
    "r:hor50-Cursor/lCursor-blinkwait100-blinkon100-blinkoff100",
    "c-ci:ver25-Cursor/lCursor-blinkwait1000-blinkon100-blinkoff100",
}


