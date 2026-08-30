return {
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        lazy = true,
        dependencies = {
            "nvim-lua/plenary.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
            "nvim-telescope/telescope-file-browser.nvim",
            "jonarrien/telescope-cmdline.nvim",
            "nvim-telescope/telescope-ui-select.nvim",
        },
        opts = {
            defaults = {
                path_display = { "filename_first" }, -- Muestra "archivo.lua (~/config/nvim)" en vez de la ruta larga
                sorting_strategy = "ascending", -- Los mejores resultados quedan arriba
                layout_config = {
                    prompt_position = "top", -- Barra de búsqueda arriba
                },
                mappings = {
                    i = {
                        ["<C-j>"] = "move_selection_next", -- Mover hacia abajo sin soltar la barra de texto
                        ["<C-k>"] = "move_selection_previous", -- Mover hacia arriba
                        --["<C-q>"] = "send_selected_to_qflist", -- Enviar seleccionados a la lista Quickfix
                    },
                    -- Mapeos dentro del modo Normal (tras presionar <Esc>)
                    n = {
                        ["q"] = require("telescope.actions").close,
                        ["<Esc>"] = require("telescope.actions").close,
                    },
                },
            },
            extensions = {
                fzf = {
                    fuzzy = true,
                    override_generic_sorter = true,
                    override_file_sorter = true,
                    case_mode = "smart_case",
                },
                cmdline = {
                    picker = {
                        layout_config = {
                            width = 120,
                            height = 25,
                        },
                    },
                    mappings = {
                        complete = "<Tab>",
                        run_selection = "<C-CR>",
                        run_input = "<CR>",
                    },
                },
                ["ui-select"] = {
                    require("telescope.themes").get_dropdown({}),
                },
            },
        },
        keys = {
            -- Mis atajos Personales:
            {
                "<leader>en",
                function()
                    require("telescope.builtin").find_files({
                        cwd = vim.fn.stdpath("config"),
                    })
                end,
                desc = "Neovim config Files",
            },
            -- LSP
            {
                "grr",
                function()
                    require("telescope.builtin").lsp_references()
                end,
                desc = "LSP References",
            },
            {
                "<leader>ds",
                function()
                    require("telescope.builtin").lsp_document_symbols()
                end,
                desc = "LSP Document Symbols",
            },

            -- Navegación general y atajos unificados
            {
                "<C-p>",
                function()
                    require("telescope.builtin").find_files()
                end,
                desc = "Buscar archivos",
            },
            {
                "<leader>pf",
                function()
                    require("telescope.builtin").find_files()
                end,
                desc = "Telescope Find Files",
            },
            {
                "<leader>fg",
                function()
                    require("telescope.builtin").live_grep()
                end,
                desc = "Buscar texto",
            },
            {
                "<leader>fb",
                function()
                    require("telescope.builtin").buffers()
                end,
                desc = "Buscar buffers",
            },
            {
                "<leader>fh",
                function()
                    require("telescope.builtin").help_tags()
                end,
                desc = "Buscar ayuda",
            },
            {
                "<leader>pe",
                function()
                    require("telescope.builtin").buffers()
                end,
                desc = "Telescope buffers",
            },
            { "<leader><leader>;", "<cmd>Telescope cmdline<cr>", desc = "Cmdline" },

            -- Git con Fallbacks
            {
                "<leader>pp",
                function()
                    local ok = pcall(require("telescope.builtin").git_files, { show_untracked = true })
                    if not ok then
                        require("telescope.builtin").find_files()
                    end
                end,
                desc = "Telescope Git Files (Fallback)",
            },
            {
                "<leader>gs",
                function()
                    local ok = pcall(require("telescope.builtin").git_status)
                    if not ok then
                        vim.notify("Esta carpeta no es un repositorio Git", vim.log.levels.WARN)
                    end
                end,
                desc = "Telescope Git Status",
            },
            {
                "<leader>gc",
                function()
                    local ok = pcall(require("telescope.builtin").git_bcommits)
                    if not ok then
                        vim.notify("Esta carpeta no es un repositorio Git", vim.log.levels.WARN)
                    end
                end,
                desc = "Telescope Git Status Commits",
            },
            {
                "<leader>gb",
                function()
                    local ok = pcall(require("telescope.builtin").git_branches)
                    if not ok then
                        vim.notify("Esta carpeta no es un repositorio Git", vim.log.levels.WARN)
                    end
                end,
                desc = "Telescope Git Branches",
            },

            -- Extensiones y creación de Plugins
            {
                "<leader>rp",
                function()
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
                        end,
                    })
                end,
                desc = "Find/Create Plugins",
            },
            {
                "<leader>bb",
                function()
                    require("telescope").extensions.file_browser.file_browser({ path = "%:h:p", select_buffer = true })
                end,
                desc = "Telescope File Browser",
            },
            -- Agrega estas entradas a tu lista de `keys`:
            {
                "<leader>pr",
                function()
                    require("telescope.builtin").resume()
                end,
                desc = "Reanudar última búsqueda",
            },
            {
                "<leader>fc",
                function()
                    require("telescope.builtin").grep_string()
                end,
                desc = "Buscar palabra bajo el cursor",
            },
            {
                "<leader>fk",
                function()
                    require("telescope.builtin").keymaps()
                end,
                desc = "Buscar atajos de teclado",
            },
            {
                "<leader>fd",
                function()
                    require("telescope.builtin").diagnostics()
                end,
                desc = "Buscar errores/diagnósticos LSP",
            },
            {
                "<leader>uT",
                function()
                    require("telescope.builtin").colorscheme({ enable_preview = true })
                end,
                desc = "Seleccionar tema de color",
            },
        },
        config = function(_, opts)
            local telescope = require("telescope")

            -- Inicialización única pasándole la tabla opts adecuada
            telescope.setup(opts)

            -- Cargar todas las extensiones registradas
            telescope.load_extension("fzf")
            telescope.load_extension("cmdline")
            telescope.load_extension("file_browser")
            telescope.load_extension("ui-select")
        end,
    },
}
