return {
	"akinsho/git-conflict.nvim",
	version = "*",
	lazy = false,
	opts = {
		default_mappings = false,
		default_commands = true,
		-- Conflict markers break the parser for the rest of the file; diagnostics
		-- return once the last conflict in the buffer is resolved.
		disable_diagnostics = true,
		list_opener = "copen",
		highlights = {
			incoming = "DiffAdd",
			current = "DiffText",
		},
		debug = false,
	},
}
