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
			-- float = {
			-- 	transparent = true,
			-- 	solid = true,
			-- },
		},
		config = function(_, opts)
			require("catppuccin").setup(opts)
			vim.cmd.colorscheme("catppuccin-frappe")
			
			-- Force transparency after colorscheme loads
			vim.api.nvim_create_autocmd("ColorScheme", {
				pattern = "*",
				callback = function()
					vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
					vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
					vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
				end,
			})
			
			-- Apply immediately
			vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
			vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
			vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
		end,
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "catppuccin-frappe",
		},
	},
}
