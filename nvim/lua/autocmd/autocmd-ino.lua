

------------------------------------------------------------
-- Auto comandos:
------------------------------------------------------------



--vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
--    pattern = { "*.ino" },
--    callback = function(args)
--        --vim.fn.system("powershell -noprofile -c &'C:\\Users\\herson\\Documents\\powershell\\Scripts\\Setup-Sketch.ps1'") 
--        
--        local dir_actual = vim.fn.expand("%:p:h")
--        vim.notify(dir_actual)
--        vim.fn.system("sleep 2") 
--        --vim.fn.system({ "gcc", "--version" })
--        --print("Archivo:", args.file)
--        --print("Buffer:", args.buf)
--    end
--})



-- ****************************************************************************************************

--local pending_file = nil
--local term_buf = nil
--
--vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
--  pattern = "*.ino",
--  callback = function(args)
--    pending_file = args.file
--
--    vim.cmd(
--            "tabnew | terminal pwsh -NoLogo -NoProfile -Command \"& C:\\Users\\herson\\Documents\\powershell\\Scripts\\Setup-Sketch.ps1; sleep 1;\""
--        )
--
--    term_buf = vim.api.nvim_get_current_buf()
--    vim.cmd("startinsert")
--
--    return true -- ⛔ cancela apertura real
--  end,
--})
--
--vim.api.nvim_create_autocmd("TermClose", {
--  callback = function(args)
--    if args.buf ~= term_buf or not pending_file then
--      return
--    end
--
--    vim.schedule(function()
--      -- cerrar terminal
--      vim.api.nvim_buf_delete(args.buf, { force = true })
--
--      -- abrir archivo
--      vim.cmd("edit " .. vim.fn.fnameescape(pending_file))
--
--      -- 🔥 FORZAR CICLO NORMAL DE NEOVIM
--      vim.cmd("doautocmd BufReadPost")
--      vim.cmd("filetype detect")
--
--      pending_file = nil
--      term_buf = nil
--    end)
--  end,
--})

--vim.api.nvim_create_autocmd("BufReadPost", {
--  pattern = "*.ino",
--  callback = function()
--    vim.schedule(function()
--      vim.notify("Selecciona un archivo", vim.log.levels.INFO)
--      require("telescope.builtin").find_files()
--    end)
--  end,
--})

