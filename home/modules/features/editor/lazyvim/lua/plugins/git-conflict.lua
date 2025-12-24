return {
	"akinsho/git-conflict.nvim",
	version = "*",
	lazy = false,
	opts = {
		default_mappings = false,
		default_commands = true,
		disable_diagnostics = false,
		list_opener = "copen",
		highlights = {
			incoming = "DiffAdd",
			current = "DiffText",
		},
		debug = false,
	},
}
