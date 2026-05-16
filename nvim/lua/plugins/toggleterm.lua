return {
    -- amongst your other plugins
    {
        'akinsho/toggleterm.nvim',
        version = "*",
        config = function()
            -- 1. Detectar el sistema operativo actual
            local is_windows = vim.fn.has("win32") == 1

            -- 2. Variables para almacenar el comando completo y el ejecutable base
            local shell_config = ""
            local chosen_shell_base = ""

            -- 3. Verificaciones previas inteligentes de ejecutables
            if is_windows then
                if vim.fn.executable("pwsh") == 1 or vim.fn.executable("pwsh.exe") == 1 then
                    chosen_shell_base = "pwsh"
                    -- Si tiene pwsh, cargamos tu script de vi-mode personalizado
                    local localappdata = vim.fn.getenv("LOCALAPPDATA")
                    if localappdata == vim.NIL or type(localappdata) ~= "string" then
                        localappdata = vim.fn.expand("~/AppData/Local")
                    end
                    local vi_mode_pwsh_file = localappdata .. "\\nvim\\lua\\plugins\\psreadline-config.ps1"
                    shell_config = "pwsh -nologo -noprofile -noexit -command { . '".. vi_mode_pwsh_file .. "'}"
                else
                    -- Fallback si pwsh no existe en Windows
                    chosen_shell_base = "powershell"
                    shell_config = "powershell.exe -nologo"
                end
            else
                -- Lógica para Linux / macOS
                if vim.fn.executable("fish") == 1 then
                    chosen_shell_base = "fish"
                    shell_config = "fish"
                elseif vim.fn.executable("bash") == 1 then
                    chosen_shell_base = "bash"
                    shell_config = "bash"
                else
                    -- Último recurso: el shell por defecto del sistema
                    shell_config = vim.o.shell
                    chosen_shell_base = vim.o.shell:match("([^/]+)$") or "bash"
                end
            end

            -- 4. Inicializar ToggleTerm con el shell detectado
            local simple_term, toggleterm = pcall(require, "toggleterm")
            toggleterm.setup {
                on_create = function(terminal)
                    --vim.cmd("TermExec cmd=\"clear; echo hola\"")
                end,
                close_on_exit = true, -- close the terminal window when the process exits
                shell = shell_config
            }

            -- ------------------------------------------------------------------------------------
            -- Terminal personalizada:
            -- ------------------------------------------------------------------------------------
            local Terminal = require("toggleterm.terminal").Terminal

            local my_terminal = Terminal:new({
                close_on_exit = false,
                cmd = "echo Bienvenido.",
                dir = "git_dir",
                direction = "float",
                -- custom
                highlights = {
                    Normal = {
                        guibg = "black"
                    }
                },
                float_opts = {
                    border = 'curved',
                    highlights = {
                        border = 'Normal',
                        background = 'Normal',
                    },
                    winblend = 3,
                    title_pos = 'center',
                },
                on_open = function(term)
                    vim.cmd("startinsert!")
                    vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
                end,
                on_close = function(term)
                    vim.cmd("startinsert!")
                end,
            })

            function Output_term_toggle()
                my_terminal:toggle()
            end

            function Output_exec(cmd)
                if is_windows then
                    my_terminal.cmd = chosen_shell_base .. " -nologo -noprofile -command " .. cmd
                else
                    my_terminal.cmd = chosen_shell_base .. " -c '" .. cmd .. "'"
                end
                my_terminal.close_on_exit = false
                Output_term_toggle()
            end

            -- ------------------------------------------------------------------------------------
            -- floatterm
            -- ------------------------------------------------------------------------------------
            local TerminalN = require("toggleterm.terminal").Terminal

            local float_terminal = TerminalN:new({
                -- Ahora usa el mismo shell inteligente detectado previamente
                shell = shell_config,
                close_on_exit = false,
                cmd = "echo Bienvenido.",
                dir = "git_dir",
                direction = "float",
                -- custom
                highlights = {
                    Normal = {
                        guibg = "black"
                    }
                },
                float_opts = {
                    border = 'curved',
                    highlights = {
                        border = 'Normal',
                        background = 'Normal',
                    },
                    winblend = 3,
                    title_pos = 'center',
                },
                on_open = function(term)
                    vim.cmd("startinsert!")
                    vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
                end,
                on_close = function(term)
                    vim.cmd("startinsert!")
                end,
            })

            function Float_Terminal_toggle()
                float_terminal:toggle()
            end

            function Float_Terminal_exec(cmd, shell)
                local comando = ""

                if shell == nil then
                    if is_windows then
                        if chosen_shell_base == "pwsh" or chosen_shell_base == "powershell" then
                            comando = chosen_shell_base .. " -nologo -noprofile -command { " .. cmd .. " }"
                        else
                            comando = "cmd /c " .. cmd
                        end
                    else
                        comando = chosen_shell_base .. " -c '" .. cmd .. "'"
                    end
                else
                    -- Si pasas un shell personalizado manualmente
                    if shell:match("pwsh") or shell:match("powershell") then
                        comando = shell .. " -command { " .. cmd .."}"
                    elseif shell:match("bash") or shell:match("fish") or shell:match("-c") then
                        comando = shell .. " '" .. cmd .. "'"
                    else
                        comando = shell .. " " .. cmd
                    end
                end

                float_terminal.cmd = comando
                float_terminal.close_on_exit = false
                Float_Terminal_toggle()
            end

            -- ------------------------------------------------------------------------------------
            -- shortcuts:
            -- ------------------------------------------------------------------------------------
            local trim_spaces = false
            vim.keymap.set("v", "<space>s", function()
                require("toggleterm").send_lines_to_terminal("visual_selection", trim_spaces, { args = vim.v.count })
            end)

            vim.keymap.set("n", [[<leader><c-\>]], function()
                require("toggleterm").set_opfunc(function(motion_type)
                    require("toggleterm").send_lines_to_terminal(motion_type, false, { args = vim.v.count })
                end)
                vim.api.nvim_feedkeys("g@", "n", false)
            end)

            vim.keymap.set("n", "<C-cr>", "<Cmd>ToggleTerm name=desktop<CR>", { noremap = true })
            vim.keymap.set("n", "<C-;>", "<Cmd>ToggleTerm name=desktop<CR>", { noremap = true })
            vim.keymap.set("n", "<A-;>", "<Cmd>ToggleTerm name=desktop<CR>", { noremap = true })
            vim.keymap.set("n", "<C-,>", "<Cmd>ToggleTerm name=desktop<CR>", { noremap = true })
            vim.keymap.set("n", "<leader>ah", "<Cmd>ToggleTerm size=20 direction=horizontal name=desktop<CR>",
                { noremap = true })
            vim.keymap.set("n", "<leader>av", "<Cmd>ToggleTerm size=40 direction=vertical name=desktop<CR>",
                { noremap = true })

            function _G.set_terminal_keymaps()
                local opts = { buffer = 0, noremap = true }
                vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], opts)
                vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], opts)
                vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], opts)
                vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], opts)
                vim.keymap.set('t', '<C-w>', [[<C-\\><C-n><C-w>]], opts)
                vim.keymap.set('t', '<esc>', [[<C-\\><C-n>]], opts)
                vim.keymap.set('t', '<S-q><S-q>', "<C-\\><C-n>", opts)

                vim.keymap.set("t", "<A-l>", "<Cmd>ToggleTerm<cr>", { noremap = true })
                vim.keymap.set("t", "<C-;>", "<Cmd>ToggleTerm<cr>", { noremap = true })
                vim.keymap.set("t", "<A-;>", "<Cmd>ToggleTerm<cr>", { noremap = true })
                vim.keymap.set("t", "<A-l>", "<Cmd>ToggleTerm<cr>", { noremap = true })
                vim.keymap.set("t", "<A-j>", "<Cmd>ToggleTerm<cr>", { noremap = true })
            end

            vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')
        end
    }
}
