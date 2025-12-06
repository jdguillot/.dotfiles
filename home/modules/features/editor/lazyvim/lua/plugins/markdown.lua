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

	-- {
	-- 	"HakonHarnes/img-clip.nvim",
	-- 	event = "VeryLazy",
	-- 	opts = {
	-- 		default = {
	-- 			-- Directory to save images (relative to current file)
	-- 			dir_path = "assets",
	-- 			-- Image file naming
	-- 			file_name = "%Y-%m-%d-%H-%M-%S",
	-- 			-- Use relative paths in markdown links
	-- 			use_absolute_path = false,
	-- 			-- Prompt for confirmation before saving
	-- 			prompt_for_file_name = false,
	-- 		},
	-- 		filetypes = {
	-- 			markdown = {
	-- 				url_encode_path = true,
	-- 				template = "![$CURSOR]($FILE_PATH)",
	-- 				drag_and_drop = {
	-- 					download_images = false,
	-- 				},
	-- 			},
	-- 		},
	-- 	},
	-- 	keys = {
	-- 		{ "<leader>p", "<cmd>PasteImage<cr>", desc = "Paste image from clipboard" },
	-- 	},
	-- },

	{
		"dfendr/clipboard-image.nvim",
		opts = { -- Default configuration for all filetype
			default = {
				img_dir = { "assets" },
				-- img_name = function()
				-- 	return os.date("%Y-%m-%d-%H-%M-%S")
				-- end,
				--
				--
				img_name = function()
					local name = os.date("%Y-%m-%d-%H-%M-%S")
					vim.fn.inputsave()
					local input = vim.fn.input("Name: ", name)
					vim.fn.inputrestore()
					return input
				end,

				-- img_name = function()
				-- 	local name = vim.fn.input("Name: ")
				-- 	return name
				-- end,

				affix = "![](%s)",
			},
			-- You can create configuration for ceartain filetype by creating another field (markdown, in this case)
			-- If you're uncertain what to name your field to, you can run `lua print(vim.bo.filetype)`
			-- Missing options from `markdown` field will be replaced by options from `default` field
			markdown = {
				img_dir = { "%:p:h", "assets" }, -- Use table for nested dir (New feature form PR #20)
				img_dir_txt = "assets",
				-- img_handler = function(img) -- New feature from PR #22
				-- 	local script = string.format('./image_compressor.sh "%s"', img.path)
				-- 	os.execute(script)
				-- end,
			},
		},
		ft = { "tex", "markdown" },
		keys = {
			{ "<leader>i", "<cmd>PasteImg<cr>", desc = "Paste image" },
		},
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
