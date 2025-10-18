return {
	-- Ensure conform.nvim is installed and configured
	{
		"stevearc/conform.nvim",
		optional = true, -- Set to true if conform is already managed by LazyVim extras
		opts = {
			ensure_installed = { "nix" },
			servers = { nil_ls = {} },
			formatters_by_ft = {
				nix = { "nixfmt" },
			},
		},
	},
}
