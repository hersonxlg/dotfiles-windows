return {
    {
        "nvim-telescope/telescope.nvim",
        branch = "master",
        lazy = true,
        dependencies = {
            {
                'nvim-telescope/telescope-fzf-native.nvim',
                build = 'make'
            },
            "nvim-lua/plenary.nvim",
            "nvim-telescope/telescope-file-browser.nvim",
            "jonarrien/telescope-cmdline.nvim",
        },
        opts = {
            -- Toda la configuración de extensiones unificada aquí
            extensions = {
                fzf = {
                    fuzzy = true,                   -- Activar las búsquedas aproximadas
                    override_generic_sorter = true, -- override the generic sorter
                    override_file_sorter = true,    -- override the file sorter
                    case_mode = "smart_case",       -- default case_mode is "smart_case"
                },
                fzf_writer = {
                    minimum_grep_characters = 2,
                    minimum_files_characters = 2,
                    use_highlighter = true,
                },
            },
            cmdline = {
                picker   = {
                    layout_config = {
                        width  = 120,
                        height = 25,
                    }
                },
                mappings = {
                    complete      = '<Tab>',
                    run_selection = '<C-CR>',
                    run_input     = '<CR>',
                },
            },
        },
        keys = {
            {
                "<leader>ds",
                function()
                    require('telescope.builtin').lsp_document_symbols()
                end,
                desc = "LSP Document Symbols",
            },
            {
                "<leader><leader>;",
                '<cmd>Telescope cmdline<cr>',
                desc = 'Cmdline'
            },
            {
                "<leader>pe",
                function()
                    require('telescope.builtin').buffers()
                end,
                desc = "Telescope buffers",
            },
            {
                "<leader>pp",
                function()
                    -- Intenta abrir git_files, si falla (no es un repo Git), abre find_files normal
                    local ok = pcall(require('telescope.builtin').git_files, { show_untracked = true })
                    if not ok then
                        require('telescope.builtin').find_files()
                    end
                end,
                desc = "Telescope Git Files (Fallback)",
            },
            {
                "<leader>gs",
                function()
                    local ok = pcall(require('telescope.builtin').git_status)
                    if not ok then
                        vim.notify("Esta carpeta no es un repositorio Git", vim.log.levels.WARN)
                    end
                end,
                desc = "Telescope Git Status",
            },
            {
                "<leader>gc",
                function()
                    local ok = pcall(require('telescope.builtin').git_bcommits)
                    if not ok then
                        vim.notify("Esta carpeta no es un repositorio Git", vim.log.levels.WARN)
                    end
                end,
                desc = "Telescope Git Status Commits",
            },
            {
                "<leader>gb",
                function()
                    local ok = pcall(require('telescope.builtin').git_branches)
                    if not ok then
                        vim.notify("Esta carpeta no es un repositorio Git", vim.log.levels.WARN)
                    end
                end,
                desc = "Telescope Git Branches",
            },
            {
                "<leader>rp",
                function()
                    -- Ruta dinámica y multiplataforma para los plugins
                    local plugins_path = vim.fn.stdpath("config") .. "/lua/plugins"
                    
                    require("telescope.builtin").find_files({
                        prompt_title = "Plugins",
                        cwd = plugins_path,
                        attach_mappings = function(_, map)
                            local actions = require("telescope.actions")
                            local action_state = require("telescope.actions.state")
                            map("i", "<c-y>", function(prompt_bufnr)
                                local new_plugin = action_state.get_current_line()
                                actions.close(prompt_bufnr)
                                vim.cmd(string.format("edit %s/%s.lua", plugins_path, new_plugin))
                            end)
                            return true
                        end
                    })
                end,
                desc = "Find/Create Plugins",
            },
            {
                "<leader>pf",
                function()
                    require('telescope.builtin').find_files()
                end,
                desc = "Telescope Find Files",
            },
            {
                "<leader>bb",
                function()
                    require("telescope").extensions.file_browser.file_browser({ path = "%:h:p", select_buffer = true })
                end,
                desc = "Telescope File Browser"
            },
        },
        config = function(opts)
            local builtin = require("telescope.builtin")
            
            -- Una sola llamada a setup pasando los "opts" definidos arriba
            require('telescope').setup(opts)
            
            -- Cargar extensiones
            require("telescope").load_extension('cmdline')
            require('telescope').load_extension('fzf')

            -- Atajos clásicos
            vim.keymap.set("n", "<C-p>", builtin.find_files, {})
            vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
            vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
            vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})
        end,
    },
    -- batería
    {
        "nvim-telescope/telescope-ui-select.nvim",
        config = function()
            require("telescope").setup({
                extensions = {
                    ["ui-select"] = {
                        require("telescope.themes").get_dropdown({}),
                    },
                },
            })
            require("telescope").load_extension("ui-select")
        end,
    },
}
