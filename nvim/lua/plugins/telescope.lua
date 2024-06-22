return {
    {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.5",
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
            extensions = {
                fzf = {
                    fuzzy = true, -- Activar las buquedas aproximadas.
                    override_generic_sorter = true,
                    override_file_sorter = true,
                    case_mode = "smart_case",

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
                    require('telescope.builtin').git_files({ show_untracked = true })
                end,
                desc = "Telescope Git Files",
            },
            {
                "<leader>gs",
                function()
                    require('telescope.builtin').git_status()
                end,
                desc = "Telescope Git Status",
            },
            {
                "<leader>gc",
                function()
                    require('telescope.builtin').git_bcommits()
                end,
                desc = "Telescope Git Status Commits",
            },
            {
                "<leader>gb",
                function()
                    require('telescope.builtin').git_branches()
                end,
                desc = "Telescope Git Branches",
            },
            {
                "<leader>rp",
                function()
                    require("telescope.builtin").find_files({
                        promt_title = "Plugins",
                        cwd = "~\\AppData\\Local\\nvim\\lua\\plugins",
                        attach_mappings = function(_, map)
                            local actions = require("telescope.actions")
                            local action_state = require("telescope.actions.state")
                            map("i", "<c-y>", function(promt_bufnr)
                                local new_plugin = action_state.get_current_line()
                                actions.close(promt_bufnr)
                                vim.cmd(string.format("edit ~\\AppData\\Local\\nvim\\lua\\plugins/%s.lua", new_plugin))
                            end)
                            return true
                        end
                    })
                end,
                desc = "Telescope Git Branches",
            },
            {
                "<leader>pf",
                function()
                    require('telescope.builtin').find_files()
                end,
                desc = "Telescope Git Branches",
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
            require('telescope').setup(opts)
            require("telescope").load_extension('cmdline')

            -- You dont need to set any of these options. These are the default ones. Only
            -- the loading is important
            require('telescope').setup {
                extensions = {
                    fzf = {
                        fuzzy = true,                   -- false will only do exact matching
                        override_generic_sorter = true, -- override the generic sorter
                        override_file_sorter = true,    -- override the file sorter
                        case_mode = "ignore_case",      -- or "ignore_case" or "respect_case"
                        -- the default case_mode is "smart_case"
                    },
                    fzf_writer = {
                        minimum_grep_characters = 2,
                        minimum_files_characters = 2,

                        -- Disabled by default.
                        -- Will probably slow down some aspects of the sorter, but can make color highlights.
                        -- I will work on this more later.
                        use_highlighter = true,
                    },
                }
            }
            -- To get fzf loaded and working with telescope, you need to call
            -- load_extension, somewhere after setup function:
            require('telescope').load_extension('fzf')

            vim.keymap.set("n", "<C-p>", builtin.find_files, {})
            vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
            vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
            vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})
        end,
    },
    --bateria
    --batería
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
