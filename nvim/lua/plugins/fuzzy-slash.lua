return {
    "IndianBoy42/fuzzy_slash.nvim",
    enabled = false,
    dependencies = {
        { "IndianBoy42/fuzzy.nvim",
            dependencies = {
                { 
                    "nvim-telescope/telescope-fzf-native.nvim",
                    build = "make"
                }
            } 
        },
    },
    config = function ()
        require('fuzzy_slash').setup({})
    end
    -- Configure and lazy load as you want
}
