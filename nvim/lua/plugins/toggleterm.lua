return {
    "akinsho/toggleterm.nvim",
    version = "*",
    -- MODIFICACIÓN 1: Cargamos el plugin justo después del inicio para poder pre-cargar la shell
    event = "VeryLazy",
    config = function()
        -- Tu configuración base
        require("toggleterm").setup({
            size = 20,
            open_mapping = [[<A-;>]], -- ToggleTerm creará automáticamente este mapeo en todos los modos
            hide_numbers = true,
            shade_terminals = true,
            shading_factor = 2,
            start_in_insert = true,
            insert_mappings = true,
            terminal_mappings = true,
            persist_size = true,
            direction = "float",
            close_on_exit = true,
            shell = vim.o.shell,
            float_opts = {
                border = "curved",
                winblend = 3,
            },
        })

        -- Tus atajos para cuando ya estás DENTRO de la terminal
        local function set_terminal_keymaps()
            local opts = { buffer = 0 }
            vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
            vim.keymap.set("t", "<c-a-space>", [[<C-\><C-n>]], opts)

            vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
            vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
            vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
            vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
        end

        vim.api.nvim_create_autocmd("TermOpen", {
            pattern = "term://*",
            callback = function()
                set_terminal_keymaps()
            end,
        })

        -- Como quitamos 'keys' de Lazy, definimos manualmente el resto de tus atajos aquí abajo:
        vim.keymap.set("n", "<leader>tf", "<Cmd>ToggleTerm direction=float<CR>", { desc = "Terminal Flotante" })
        vim.keymap.set(
            "n",
            "<leader>tv",
            "<Cmd>ToggleTerm direction=vertical size=60<CR>",
            { desc = "Terminal Vertical" }
        )

        -- Configuración para LazyGit (Se ejecutará solo cuando lo pidas)
        local Terminal = require("toggleterm.terminal").Terminal
        local lazygit = Terminal:new({ cmd = "lazygit", hidden = true, direction = "float" })
        vim.keymap.set("n", "<leader>g", function()
            lazygit:toggle()
        end, { desc = "Toggle LazyGit" })

        -- ====================================================================
        -- MODIFICACIÓN 2: TRUCO DE PRE-CARGA ASÍNCRONA (Pre-spawn)
        -- ====================================================================
        -- Le dice a Neovim: "En cuanto tengas un tiempo libre en tu bucle principal,
        -- arranca la terminal número 1 en el fondo pero no la muestres todavía".
        vim.schedule(function()
            local main_term = Terminal:new({ id = 1 })
            main_term:spawn()
        end)
    end,
}
