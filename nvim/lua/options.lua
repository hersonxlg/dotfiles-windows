vim.g.netrw_banner = 0

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.wrap = false
vim.opt.smartindent = true
vim.opt.inccommand = "split"

vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.laststatus = 3

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = vim.fn.stdpath("data") .. "/undodir"
vim.opt.undofile = true

vim.opt.clipboard:append("unnamedplus")
vim.opt.isfname:append("@-@")
-- vim.opt.guicursor = ""
vim.opt.scrolloff = 8

vim.opt.colorcolumn = "0"
vim.opt.signcolumn = "yes"
vim.opt.cmdheight = 0
vim.opt.termguicolors = true

vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Hinglight when yanking (copying) text",
    callback = function()
        vim.hl.on_yank()
    end,
})

-----------------------------------------------------
-- Simbolos sin representación gráfica:
-----------------------------------------------------
vim.o.list = true
vim.o.listchars = "tab:»·,lead:•,trail:•,eol:↲"

-----------------------------------------------------
-- Configurar el portapapeles (clipboard):
-----------------------------------------------------
vim.opt.clipboard = "unnamedplus"

--  -- CAMBIO: Solo aplicar la configuración de 'win32yank' si estás en Windows
--  if vim.fn.has("win32") == 1 then
--    vim.g.clipboard = {
--      name = 'win32yank',
--      copy = {
--        ['+'] = { 'win32yank.exe', '-i', '--crlf' },
--        ['*'] = { 'win32yank.exe', '-i', '--crlf' },
--      },
--      paste = {
--        ['+'] = { 'win32yank.exe', '-o', '--lf' },
--        ['*'] = { 'win32yank.exe', '-o', '--lf' },
--      },
--      cache_enabled = false,
--    }
--  end
--  -- NOTA: En Linux, Neovim detectará automáticamente xclip, xsel o wl-copy gracias a unnamedplus.

-----------------------------------------------------
-- Configuración del Shell Interno (Multiplataforma)
-----------------------------------------------------
-- CAMBIO: Separar las opciones del sistema para evitar que Linux intente usar comandos de Windows
if vim.fn.has("win32") == 1 then
    vim.o.shell = "pwsh"
    vim.o.shellquote = ""
    vim.o.shellxquote = ""
    vim.o.shellcmdflag =
        "-NoLogo -NoProfile -Command [Console]::InputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8; $PSStyle.OutputRendering=[System.Management.Automation.OutputRendering]::PlainText;Remove-Alias -Name tee -Force -ErrorAction SilentlyContinue;"
    vim.o.shellpipe = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'
    vim.o.shellredir = '2>&1 | %%{ "$_" } | tee %s; exit $LastExitCode'
else
    -- Si estás en Linux/macOS, usa tu orden de preferencia (fish -> bash -> shell por defecto)
    if vim.fn.executable("fish") == 1 then
        vim.o.shell = "fish"
    elseif vim.fn.executable("bash") == 1 then
        vim.o.shell = "bash"
    else
        vim.o.shell = vim.o.shell
    end
end

-----------------------------------------------------
-- Folding (plegado) para Neovm 0.12:
-----------------------------------------------------

-- 1. Decirle a Neovim que use expresiones para el plegado
vim.opt.foldmethod = "expr"

-- 2. Usar la función nativa de Tree-sitter para calcular los pliegues
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"

-- 3. Evitar que todo el código se abra completamente colapsado al iniciar un archivo
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldenable = true

-- 4. Truco visual moderno: mantiene el resaltado de sintaxis (colores) en la línea plegada
vim.opt.foldtext = ""

-- 5. Opcional: Muestra una columna a la izquierda indicando dónde hay pliegues
-- "0" para ocultarla, "1" para verla de forma discreta
vim.opt.foldcolumn = "1"
