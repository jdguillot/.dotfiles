return {
	{
		"catppuccin/nvim",
		name = "catppuccin-frappe",
		main = "catppuccin", -- tells lazy.nvim to call require("catppuccin").setup(opts)
		priority = 1000,
		lazy = false,
		opts = {
			flavour = "frappe",
			transparent_background = true,
			float = {
				transparent = true,
				solid = true,
			},
		},
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "catppuccin-frappe",
		},
	},
}
