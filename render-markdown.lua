return {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
        file_types = { "markdown", "blink-cmp-documentation" },
        completions = {
            blink = {
                enabled = true,
            },
        },
    },
    ft = { "markdown", "blink-cmp-documentation" },
}
