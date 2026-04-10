return {
	"saghen/blink.cmp",
	dependencies = { "giuxtaposition/blink-cmp-copilot" },
	opts = {
		keymap = {
			preset = "default",
			["<CR>"] = { "accept", "fallback" },
		},
		completion = {
			list = {
				selection = {
					preselect = false,
					auto_insert = true,
				},
			},
		},

		sources = {
			default = { "lsp", "path", "snippets", "buffer", "copilot" },
			providers = {
				snippets = {
					opts = {
						search_paths = {
							vim.fn.stdpath("config") .. "/snippets",
							vim.fn.getcwd() .. "/.vscode",
							vim.fn.getcwd() .. "/.vscode/snippets",
						},
						friendly_snippets = true,
						extended_filetypes = {},
					},
				},
				copilot = {
					name = "copilot",
					module = "blink-cmp-copilot",
					score_offset = -100,
					async = true,
				},
			},
		},
	},
}
