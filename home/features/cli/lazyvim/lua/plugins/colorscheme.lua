-- return {
-- 	"AlexvZyl/nordic.nvim",
-- 	lazy = false,
-- 	priority = 1000,
-- 	config = function()
-- 		require("nordic").load()
-- 	end,
-- }
return {
	"catppuccin/nvim",
	name = "catppuccin-frappe",
	priority = 1000,
	lazy = false,
	config = function()
		require("catppuccin").setup({ flavour = "frappe" })
		vim.cmd.colorscheme("catppuccin-frappe")
	end,
}
