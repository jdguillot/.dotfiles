-- Dev-trait only: vim.g.dotfiles_dev is set from Nix in initLua.
if not vim.g.dotfiles_dev then
  return {}
end

return {
	-- Configure conform.nvim for JSON formatting
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				json = { "prettier" },
				jsonc = { "prettier" },
				json5 = { "prettier" },
				markdown = { "prettier" },
				["markdown.mdx"] = { "prettier" },
			},
		},
	},
}
