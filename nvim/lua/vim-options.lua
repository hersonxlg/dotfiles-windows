--vim.cmd("set expandtab")
--vim.cmd("set tabstop=4")
--vim.cmd("set softtabstop=4")
--vim.cmd("set shiftwidth=4")

vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = -1
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.shiftround = true


-----------------------------------------------------
-- Simbolos sin representación gráfica:
-----------------------------------------------------
vim.o.list = true
vim.o.listchars = 'tab:»·,lead:•,trail:•,eol:↲'


-----------------------------------------------------
-- configurar el portapapeles (clipboard):
-----------------------------------------------------

--vim.cmd("set clipboard+=unnamedplus")

vim.opt.clipboard = "unnamedplus"
vim.g.clipboard = {
  name = 'win32yank',
  copy = {
--['+'] = { 'C:\\ProgramData\\chocolatey\\bin\\win32yank.exe', '-i', '--crlf' },
--['*'] = { 'C:\\ProgramData\\chocolatey\\bin\\win32yank.exe', '-i', '--crlf' },
    ['+'] = { 'win32yank.exe', '-i', '--crlf' },
    ['*'] = { 'win32yank.exe', '-i', '--crlf' },
  },
  paste = {
--    ['+'] = { 'C:\\ProgramData\\chocolatey\\bin\\win32yank.exe', '-o', '--lf' },
--    ['*'] = { 'C:\\ProgramData\\chocolatey\\bin\\win32yank.exe', '-o', '--lf' },
    ['+'] = { 'win32yank.exe', '-o', '--lf' },
    ['*'] = { 'win32yank.exe', '-o', '--lf' },
  },
  cache_enabled = false,
}

vim.cmd("set number")
vim.cmd("set cmdwinheight=20")
-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10
vim.g.mapleader = " "


-----------------------------------------------------
-- Powershell
-----------------------------------------------------
vim.o.shell = "pwsh"
vim.o.shellquote = ""
vim.o.shellxquote = ""
vim.o.shellcmdflag =
"-NoLogo -NoProfile -Command [Console]::InputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8; $PSStyle.OutputRendering=[System.Management.Automation.OutputRendering]::PlainText;Remove-Alias -Name tee -Force -ErrorAction SilentlyContinue;"
vim.o.shellpipe = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'
vim.o.shellredir = '2>&1 | %%{ "$_" } | tee %s; exit $LastExitCode'



vim.keymap.set("n", "<leader>w", ":w<CR>", { noremap = true })
vim.keymap.set("n", "<leader>q", ":quit<CR>", { noremap = true })
vim.keymap.set("n", "<leader>x", ":bd<CR>", { noremap = true })
vim.keymap.set("n", "<leader>s", ":so %<CR>", { noremap = true })
vim.keymap.set("n", "<leader>ev", ":vsplit $MYVIMRC<CR>", { noremap = true })
vim.keymap.set("n", "<leader>sv", ":w<CR>:so %<CR>:q<CR>", { noremap = true })

vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set("i", "kj", "<Esc>")
vim.keymap.set("n", "zv", "<c-v>",{noremap = true})
vim.keymap.set("n", "<leader>;", "q:",{noremap = true})


vim.keymap.set("n", "<c-j>", "<c-w><c-j>",{noremap = true})
vim.keymap.set("n", "<c-k>", "<c-w><c-k>",{noremap = true})
vim.keymap.set("n", "<c-h>", "<c-w><c-h>",{noremap = true})
vim.keymap.set("n", "<c-l>", "<c-w><c-l>",{noremap = true})


vim.keymap.set("n", "<leader>.", "<cmd>luafile $MYVIMRC<cr>",{noremap = true})



-----------------------------------------------------
-- atajos para LSP
-----------------------------------------------------
vim.keymap.set('n', 'gl', vim.diagnostic.open_float, { desc = "Mostrar diagnostic flotante" })


