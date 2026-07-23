return {
    "mikavilpas/yazi.nvim",

    cmd = "Yazi",

    keys = {
        {
            "<leader>y",
            "<cmd>Yazi<cr>",
            desc = "Open yazi",
        },

        {
            "<leader>Y",
            "<cmd>Yazi cwd<cr>",
            desc = "Open yazi in cwd",
        },

        {
            "<C-Up>",
            "<cmd>Yazi toggle<cr>",
            desc = "Resume yazi session",
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

        keymaps = {
            show_help = "<f1>",
        },
    },
}
