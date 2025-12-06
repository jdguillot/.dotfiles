-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Enable automatic list continuation in markdown
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "markdown", "md" },
	callback = function()
		-- r: automatically insert comment leader after hitting <Enter> in Insert mode
		-- o: automatically insert comment leader after hitting 'o' or 'O' in Normal mode
		vim.opt_local.formatoptions:append("ro")
		-- Set comment string for markdown lists
		vim.opt_local.comments = "b:-,b:*,b:+,n:>"
		-- Enable spellcheck for markdown
		vim.opt_local.spell = true
		vim.opt_local.spelllang = "en_us"
	end,
})

-- Use Catppuccin palette colors for spell checking
vim.api.nvim_create_autocmd("ColorScheme", {
	pattern = "*",
	callback = function()
		-- Try to get catppuccin colors if available
		local has_catppuccin, catppuccin = pcall(require, "catppuccin.palettes")

		if has_catppuccin then
			local colors = catppuccin.get_palette() -- Gets current flavor's palette

			-- Subtle spell highlights using theme colors
			vim.api.nvim_set_hl(0, "SpellBad", { bg = colors.surface0, fg = colors.red, underline = true })
			vim.api.nvim_set_hl(0, "SpellCap", { bg = colors.surface0, fg = colors.yellow, underline = true })
			vim.api.nvim_set_hl(0, "SpellRare", { bg = colors.surface0, fg = colors.green, underline = true })
			vim.api.nvim_set_hl(0, "SpellLocal", { bg = colors.surface0, fg = colors.blue, underline = true })
		else
			-- Fallback if catppuccin isn't loaded
			vim.api.nvim_set_hl(0, "SpellBad", { sp = "#d99090", underline = true })
			vim.api.nvim_set_hl(0, "SpellCap", { sp = "#d9c990", underline = true })
		end
	end,
})

-- Apply immediately on startup
vim.schedule(function()
	local has_catppuccin, catppuccin = pcall(require, "catppuccin.palettes")
	if has_catppuccin then
		local colors = catppuccin.get_palette()
		vim.api.nvim_set_hl(0, "SpellBad", { bg = colors.surface0, fg = colors.red, underline = true })
		vim.api.nvim_set_hl(0, "SpellCap", { bg = colors.surface0, fg = colors.yellow, underline = true })
	end
end)
