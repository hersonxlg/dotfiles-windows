return {
--  "TheLeoP/powershell.nvim",
--  ft = { "ps1", "psm1", "psd1" },
--  config = function()
--    require("powershell").setup({
--      bundle_path   = vim.fn.stdpath("data") .. "/mason/packages/powershell-editor-services",
--      host_or_path  = "pwsh",
--      host_args     = { "-NoLogo", "-NoProfile" },
--      capabilities  = require("cmp_nvim_lsp").default_capabilities(),
--      init_options  = { enableProfileLoading = false },
--      settings      = { powershell = { codeFormatting = { Preset = "OTBS" } } },
--      root_dir      = function(buf)
--        local path = vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
--        local root = vim.fs.find({ ".git" }, { upward = true, path = path })[1]
--        return root and vim.fs.dirname(root) or path
--      end,
--    })
--  end
}
