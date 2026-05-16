vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = -1
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.shiftround = true
vim.opt.wrap = false


-----------------------------------------------------
-- Simbolos sin representación gráfica:
-----------------------------------------------------
vim.o.list = true
vim.o.listchars = 'tab:»·,lead:•,trail:•,eol:↲'


-----------------------------------------------------
-- Configurar el portapapeles (clipboard):
-----------------------------------------------------
vim.opt.clipboard = "unnamedplus"

-- CAMBIO: Solo aplicar la configuración de 'win32yank' si estás en Windows
if vim.fn.has("win32") == 1 then
  vim.g.clipboard = {
    name = 'win32yank',
    copy = {
      ['+'] = { 'win32yank.exe', '-i', '--crlf' },
      ['*'] = { 'win32yank.exe', '-i', '--crlf' },
    },
    paste = {
      ['+'] = { 'win32yank.exe', '-o', '--lf' },
      ['*'] = { 'win32yank.exe', '-o', '--lf' },
    },
    cache_enabled = false,
  }
end
-- NOTA: En Linux, Neovim detectará automáticamente xclip, xsel o wl-copy gracias a unnamedplus.

vim.cmd("set number")
vim.cmd("set cmdwinheight=20")
-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10
vim.g.mapleader = " "


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
-- Atajos de teclado generales
-----------------------------------------------------
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
vim.keymap.set(
    'n', 'gl',
    vim.diagnostic.open_float,
    { desc = "Mostrar diagnostic flotante" }
)


vim.keymap.set(
    'n', '<leader>rn',
    vim.lsp.buf.rename,
    { desc = "Mostrar diagnostic flotante" }
)

