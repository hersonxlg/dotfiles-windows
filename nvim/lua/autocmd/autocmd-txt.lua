

------------------------------------------------------------
-- Auto comandos:
------------------------------------------------------------


vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    pattern = { "*.txt" },
    callback = function(event)
        vim.keymap.set("n", "qq", "<cmd>echo 'hola'<cr>", { noremap = true })
        vim.keymap.set("n", "qw", "<cmd>echo 'mundo'<cr>", { noremap = true })
    end
})


