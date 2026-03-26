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
