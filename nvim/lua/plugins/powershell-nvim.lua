return {
    "TheLeoP/powershell.nvim",
    ---@type powershell.user_config
    opts = {
        bundle_path = vim.fn.stdpath "data" .. "/mason/packages/powershell-editor-services",
    },
    config = function()
        -- This is the default configuration
        require('powershell').setup({
            capabilities = vim.lsp.protocol.make_client_capabilities(),
            bundle_path = "",
            init_options = vim.empty_dict(),
            settings = vim.empty_dict(),
            shell = "pwsh",
            --handlers = base_handlers, -- see lua/powershell/handlers.lua
            root_dir = function(buf)
                return vim.fs.dirname(vim.fs.find({ ".git" }, { upward = true, path = vim.fs.dirname(vim.api.nvim_buf_get_name(buf)) })[1])
            end,
        })
    end
}
