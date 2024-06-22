------------------------------------------------------------
-- Auto comandos:
------------------------------------------------------------

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    pattern = { "*.ps1" },
    -- Funcion que se ejecuta la inicio:
    callback = function(event)
        local current_buffer_dir = vim.fn.expand("%:p:h")
        local current_buffer_name = vim.fn.bufname("%")
        current_buffer_name = current_buffer_name:gsub(".*\\","")
        local shell = "pwsh -nologo -noprofile "
        local comando = ".\\\\"..current_buffer_name
        vim.keymap.set("n", "<leader>r", function ()
            vim.api.nvim_command("write")
            Float_Terminal_exec(comando ,shell)
        end, {noremap=true})
    end
})
