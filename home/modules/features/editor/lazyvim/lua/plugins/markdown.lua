return {
	-- Configure markdown LSP and linting
	{
		"nvim-lint",
		opts = function(_, opts)
			opts.linters_by_ft = opts.linters_by_ft or {}
			opts.linters_by_ft.markdown = { "markdownlint-cli2" }

			opts.linters = opts.linters or {}
			opts.linters["markdownlint-cli2"] = {
				args = { "--config", "/home/jdguillot/.dotfiles/home/modules/core/common/.markdownlint.yaml", "--" },
				stdin = false,
			}
		end,
	},

	-- -- Configure conform formatter for markdown
	-- {
	--   "stevearc/conform.nvim",
	--   opts = function(_, opts)
	--     opts.formatters_by_ft = opts.formatters_by_ft or {}
	--     opts.formatters_by_ft.markdown = { "markdownlint-cli2" }
	--
	--     opts.formatters = opts.formatters or {}
	--     opts.formatters["markdownlint-cli2"] = {
	--       args = { "--config", "/home/jdguillot/.dotfiles/home/modules/core/common/.markdownlint.yaml", "--" },
	--       stdin = false,
	--     }
	--   end,
	-- },
}

