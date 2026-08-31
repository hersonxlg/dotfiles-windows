return {
    "akinsho/toggleterm.nvim",
    version = "*",
    event = "VeryLazy",
    config = function()
        local toggleterm = require("toggleterm")
        local Terminal = require("toggleterm.terminal").Terminal

        toggleterm.setup({
            size = 20,
            open_mapping = [[<A-;>]],
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

        -- Autocomando para navegación y atajos DENTRO de la terminal activa
        vim.api.nvim_create_autocmd("TermOpen", {
            pattern = "term://*",
            callback = function()
                local opts = { buffer = 0 }
                vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
                vim.keymap.set("t", "<c-a-space>", [[<C-\><C-n>]], opts)
                vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
                vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
                vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
                vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
            end,
        })

        -- 1. Terminal Flotante Principal (ID 1): Reutiliza la misma ventana y cambia la carpeta
        vim.keymap.set("n", "<leader>tf", function()
            local dir = vim.fn.expand("%:p:h")
            if dir ~= "" then
                vim.cmd(string.format("1ToggleTerm direction=float dir=%s", vim.fn.fnameescape(dir)))
            else
                vim.cmd("1ToggleTerm direction=float")
            end
        end, { desc = "Abrir/mover terminal en directorio del archivo actual" })

        -- 2. Terminal Vertical Secundaria (ID 2)
        vim.keymap.set(
            "n",
            "<leader>tv",
            "<Cmd>2ToggleTerm direction=vertical size=60<CR>",
            { desc = "Terminal Vertical" }
        )

        -- 3. Instancia dedicada para LazyGit
        local lazygit = Terminal:new({ cmd = "lazygit", hidden = true, direction = "float" })
        vim.keymap.set("n", "<leader>lg", function()
            lazygit:toggle()
        end, { desc = "Toggle LazyGit" })
    end,
}
