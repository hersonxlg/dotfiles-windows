return {
    -- amongst your other plugins
    {
        'akinsho/toggleterm.nvim',
        version = "*",
        config = function()
            -- ------------------------------------------------------------------------------------
            -- Configuracion de la Termianl por defecto:
            -- ------------------------------------------------------------------------------------
            local vi_mode_pwsh_file = vim.fn.getenv("LOCALAPPDATA").."\\nvim\\lua\\plugins\\psreadline-config.ps1"
            local simple_term, toggleterm = pcall(require, "toggleterm")
            toggleterm.setup {
                -- function to run when the terminal is first created
                on_create = function(terminal)
                    --vim.cmd("TermExec cmd=\"clear; echo hola\"")
                end,
                close_on_exit = true, -- close the terminal window when the process exits
                shell = "pwsh -nologo -noprofile -noexit -command {set-theme pure; . '".. vi_mode_pwsh_file .. "'}"
                --shell = "cmd"
            }

            -- ------------------------------------------------------------------------------------
            -- Terminal presonalizada:
            -- ------------------------------------------------------------------------------------
            local Terminal = require("toggleterm.terminal").Terminal

            local my_terminal = Terminal:new({
                --shell = "pwsh -nologo -noprofile -noninteractive",
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
                    --border = "double",
                    border = 'curved',
                    highlights = {
                        border = 'Normal',
                        background = 'Normal',
                    },
                    winblend = 3,
                    title_pos = 'center',
                },
                -- function to run on opening the terminal
                on_open = function(term)
                    vim.cmd("startinsert!")
                    vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
                end,
                -- function to run on closing the terminal
                on_close = function(term)
                    vim.cmd("startinsert!")
                end,
            })

            function Output_term_toggle()
                my_terminal:toggle()
            end

            function Output_exec(cmd)
                my_terminal.cmd = "pwsh -nologo -noprofile -command " .. cmd
                my_terminal.close_on_exit = false
                Output_term_toggle()
            end

            -- ------------------------------------------------------------------------------------
            -- floatterm
            -- ------------------------------------------------------------------------------------
            local TerminalN = require("toggleterm.terminal").Terminal

            local float_terminal = TerminalN:new({
                shell = "cmd",
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
                    --border = "double",
                    border = 'curved',
                    highlights = {
                        border = 'Normal',
                        background = 'Normal',
                    },
                    winblend = 3,
                    title_pos = 'center',
                },
                -- function to run on opening the terminal
                on_open = function(term)
                    vim.cmd("startinsert!")
                    vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
                end,
                -- function to run on closing the terminal
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
                    shell = "pwsh -nologo -noprofile -command "
                end

                if shell:match("pwsh") then
                    comando = shell .. " -command { " .. cmd .."}"
                else
                    comando = shell .. " " .. cmd
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
                --require("toggleterm").send_lines_to_terminal("single_line", trim_spaces, { args = vim.v.count })
                require("toggleterm").send_lines_to_terminal("visual_selection", trim_spaces, { args = vim.v.count })
            end)
            -- Replace with these for the other two options
            -- require("toggleterm").send_lines_to_terminal("visual_lines", trim_spaces, { args = vim.v.count })
            -- require("toggleterm").send_lines_to_terminal("visual_selection", trim_spaces, { args = vim.v.count })
            --
            -- For use as an operator map:
            -- Send motion to terminal
            vim.keymap.set("n", [[<leader><c-\>]], function()
                require("toggleterm").set_opfunc(function(motion_type)
                    require("toggleterm").send_lines_to_terminal(motion_type, false, { args = vim.v.count })
                end)
                vim.api.nvim_feedkeys("g@", "n", false)
            end)

            vim.keymap.set("n", "<C-cr>", "<Cmd>ToggleTerm name=desktop<CR>", { noremap = true })
            vim.keymap.set("n", "<C-;>", "<Cmd>ToggleTerm name=desktop<CR>", { noremap = true })
            vim.keymap.set("n", "<C-,>", "<Cmd>ToggleTerm name=desktop<CR>", { noremap = true })
            vim.keymap.set("n", "<leader>ah", "<Cmd>ToggleTerm size=20 direction=horizontal name=desktop<CR>",
                { noremap = true })
            vim.keymap.set("n", "<leader>av", "<Cmd>ToggleTerm size=40 direction=vertical name=desktop<CR>",
                { noremap = true })



            function _G.set_terminal_keymaps()
                local opts = { buffer = 0, noremap = true }
                --vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
                vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], opts)
                vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], opts)
                vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], opts)
                vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], opts)
                vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], opts)
                vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], opts)
                vim.keymap.set('t', '<S-q><S-q>', "<C-\\><C-n>", opts)

                vim.keymap.set("t", "<A-l>", "<Cmd>ToggleTerm<cr>", { noremap = true })
                vim.keymap.set("t", "<C-;>", "<Cmd>ToggleTerm<cr>", { noremap = true })

                vim.keymap.set("t", "<A-l>", "<Cmd>ToggleTerm<cr>", { noremap = true })
                vim.keymap.set("t", "<A-j>", "<Cmd>ToggleTerm<cr>", { noremap = true })
            end

            -- if you only want these mappings for toggle term use term://*toggleterm#* instead
            vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')
        end



    }
    -- or
    --{'akinsho/toggleterm.nvim', version = "*", opts = {--[[ things you want to change go here]]}}
    --
}
