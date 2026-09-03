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
vim.opt.scrolloff = 8

vim.opt.colorcolumn = "0"
vim.opt.signcolumn = "yes"
vim.opt.cmdheight = 0
vim.opt.termguicolors = true

-- Símbolos sin representación gráfica
vim.o.list = true
vim.o.listchars = "tab:»·,lead:•,trail:•,eol:↲"

-- Configurar el portapapeles (clipboard)
vim.opt.clipboard = "unnamedplus"

-- Configuración del Shell Interno (Multiplataforma)
if vim.fn.has("win32") == 1 then
    vim.o.shell = "pwsh"
    vim.o.shellquote = ""
    vim.o.shellxquote = ""
    vim.o.shellcmdflag =
        "-NoLogo -NoProfile -Command [Console]::InputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8; $PSStyle.OutputRendering=[System.Management.Automation.OutputRendering]::PlainText;Remove-Alias -Name tee -Force -ErrorAction SilentlyContinue;"
    vim.o.shellpipe = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'
    vim.o.shellredir = '2>&1 | %%{ "$_" } | tee %s; exit $LastExitCode'
else
    if vim.fn.executable("fish") == 1 then
        vim.o.shell = "fish"
    elseif vim.fn.executable("bash") == 1 then
        vim.o.shell = "bash"
    else
        vim.o.shell = vim.o.shell
    end
end

-- Folding (plegado) para Neovm 0.12
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldenable = true
vim.opt.foldtext = ""
vim.opt.foldcolumn = "1"

-- Cursor UI (Movido desde el init.lua original)
vim.opt.guicursor = {
    "n-v-c:block-Cursor/lCursor-blinkwait1000-blinkon100-blinkoff100",
    "i-ci:ver25-Cursor/lCursor-blinkwait1000-blinkon100-blinkoff100",
    "r:hor50-Cursor/lCursor-blinkwait100-blinkon100-blinkoff100",
    "c-ci:ver25-Cursor/lCursor-blinkwait1000-blinkon100-blinkoff100",
}
