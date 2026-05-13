return {
    "mikavilpas/yazi.nvim",

    cmd = "Yazi",

    keys = {
        {
            "<leader>yy",
            "<cmd>Yazi<CR>",
            desc = "Abrir Yazi",
        },

        {
            "<leader>yc",
            "<cmd>Yazi cwd<CR>",
            desc = "Abrir Yazi en cwd",
        },
    },

    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
    },

    opts = {
        open_for_directories = true,

        floating_window_border = "rounded",

        floating_window_scaling_factor = 0.9,
    },
}
