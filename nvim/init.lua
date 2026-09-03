--require("vim._core.ui2").enable({})

-- 1. Primero cargamos las variables globales (Leader)
require("config.globals")

------------------------------------------------------------
-- 2. Instalar LAZY:
------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop
if not uv.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end

vim.opt.rtp:prepend(lazypath)

------------------------------------------------------------
-- 3. Configuraciones Base de NeoVim:
------------------------------------------------------------
require("config.options")
require("config.keymaps")
require("config.autocmd")

------------------------------------------------------------
-- 4. PLUGINS FOR LAZY:
------------------------------------------------------------
require("lazy").setup("plugins", {
    git = {
        timeout = 300,
    },
    ui = {
        icons = {
            cmd = "⌘",
            config = "🛠",
            event = "📅",
            ft = "📂",
            init = "⚙",
            keys = "🗝",
            runtime = "💻",
            require = "🌙",
            source = "📄",
            start = "🚀",
            task = "📌",
            loaded = "✓",
            not_loaded = "✗",
            lazy = "➜",
            plugin = "📦",
        },
    },
})

------------------------------------------------------------
-- 5. Autocomando Multiplataforma (Linux / Windows)
------------------------------------------------------------
function RequireAll(relative_path)
    local config_path = vim.fn.stdpath("config") .. "/lua/"
    local target_dir = config_path .. relative_path

    local paths = vim.split(vim.fn.globpath(target_dir, "*.lua"), "\n", { trimempty = true })

    for _, p in ipairs(paths) do
        local normalized_p = p:gsub("\\", "/")
        local normalized_config = config_path:gsub("\\", "/")
        local module_name = normalized_p:gsub(normalized_config, ""):gsub("%.lua$", ""):gsub("/", ".")
        require(module_name)
    end
end

------------------------------------------------------------
-- 6. Ejecutar Eventos Específicos
------------------------------------------------------------
RequireAll("autocmd")
