return {
	-- Configure markdown LSP and linting
	{
		"mfussenegger/nvim-lint",
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

	{
		"dhruvasagar/vim-table-mode",
		dev = true,
		ft = "markdown",
	},

	{
		"iamcco/markdown-preview.nvim",
		dev = true,
		cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
		ft = "markdown",
	},

	{
		"HakonHarnes/img-clip.nvim",
		event = "VeryLazy",
		opts = {
			default = {
				-- Directory to save images (relative to current file)
				dir_path = "assets",
				-- Image file naming
				file_name = "%Y-%m-%d-%H-%M-%S",
				-- Use relative paths in markdown links
				relative_to_current_file = true,
				-- Prompt for confirmation before saving
				prompt_for_file_name = true,
			},
			filetypes = {
				markdown = {
					url_encode_path = true,
					template = "![$CURSOR]($FILE_PATH)",
					drag_and_drop = {
						download_images = false,
					},
				},
			},
		},
	},
}
