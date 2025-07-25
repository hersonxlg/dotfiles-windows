------------------------------------------------------------
-- Instalar LAZY:
------------------------------------------------------------
-- bateria
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
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
require("vim-options")

------------------------------------------------------------
-- PLUGINS FOR LAZY:
------------------------------------------------------------
require("lazy").setup("plugins")


------------------------------------------------------------
-- auto comando
------------------------------------------------------------
function RequireAll(relative_path)
    local path_base = vim.fn.expand("$LOCALAPPDATA\\nvim\\lua\\")
    vim.g.a = relative_path
    vim.g.b = path_base
    local paths = vim.split(vim.fn.globpath(path_base .. relative_path, "*.lua"), '\n', { trimempty = true })
    vim.g.p = ""
    for i, p in pairs(paths) do
        local path_for_require = p:gsub(path_base, ""):gsub(".lua", ""):gsub("\\", ".")
        require(path_for_require)
        vim.g.p = vim.g.p .. path_for_require .. '\n'
    end
end

RequireAll("autocmd")




vim.opt.guicursor = {
    'n-v-c:block-Cursor/lCursor-blinkwait1000-blinkon100-blinkoff100',
    'i-ci:ver25-Cursor/lCursor-blinkwait1000-blinkon100-blinkoff100',
    'r:hor50-Cursor/lCursor-blinkwait100-blinkon100-blinkoff100',
    'c-ci:ver25-Cursor/lCursor-blinkwait1000-blinkon100-blinkoff100',
}
