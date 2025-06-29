--return {
--    "TheLeoP/powershell.nvim",
--    ---@type powershell.user_config
--    opts = {
--        bundle_path = vim.fn.stdpath "data" .. "/mason/packages/powershell-editor-services",
--
--    },
--    config = function()
--        -- This is the default configuration
--        require('powershell').setup({
--            capabilities = vim.lsp.protocol.make_client_capabilities(),
--            --bundle_path = "",
--            bundle_path  = vim.fn.stdpath("data") .. "/mason/packages/powershell-editor-services",
--            host_or_path  = "pwsh",                          -- <–– línea nueva
--            host_args     = { "-NoLogo", "-NoProfile" },     -- <–– línea nueva
--            --init_options = vim.empty_dict(),
--            init_options = { enableProfileLoading = false }, -- desactiva carga de tu perfil
--            settings = vim.empty_dict(),
--            shell = "pwsh",
--            --handlers = base_handlers, -- see lua/powershell/handlers.lua
--            root_dir = function(buf)
--                return vim.fs.dirname(vim.fs.find({ ".git" }, { upward = true, path = vim.fs.dirname(vim.api.nvim_buf_get_name(buf)) })[1])
--            end,
--        })
--    end
--}


return {
  "TheLeoP/powershell.nvim",
  ft = { "ps1", "psm1", "psd1" },
  opts = {
    shell = "pwsh",
    -- 1. Dónde está instalado por Mason:
    bundle_path   = vim.fn.stdpath("data") .. "/mason/packages/powershell-editor-services",
    -- 2. Qué ejecutable lanzar:
    host_or_path  = "pwsh",
    host_args     = { "-NoLogo", "-NoProfile" },
    -- 3. Capacidades LSP (si usas cmp-nvim-lsp):
    capabilities  = require("cmp_nvim_lsp").default_capabilities(),
    -- 4. Evita cargar tu perfil de PowerShell:
    init_options  = { enableProfileLoading = false },
    -- 5. Ajustes de formateo:
    settings      = { powershell = { codeFormatting = { Preset = "OTBS" } } },
    -- 6. Raíz de proyecto:
    root_dir      = function(buf)
      return vim.fs.dirname(
        vim.fs.find({ ".git" }, {
          upward = true,
          path   = vim.fs.dirname(vim.api.nvim_buf_get_name(buf)),
        })[1]
      )
    end,
  },
}

--return {
--  "LazyVim/powershell.nvim",  -- ajusta al nombre real del repo
--  ft = { "ps1", "psm1", "psd1" },
--  config = function()
--    require("powershell").setup({
--      host_or_path = "pwsh",                -- o "pwsh.exe" si es Windows
--      host_args    = { "-NoLogo", "-NoProfile" },
--      -- resto de tus opciones…
--    })
--  end,
--}
