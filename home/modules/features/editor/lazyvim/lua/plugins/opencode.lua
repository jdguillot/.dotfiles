return {
	"NickvanDyke/opencode.nvim",
	dependencies = {
		-- Recommended for `ask()` and `select()`.
		-- Required for `snacks` provider.
		---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
		{ "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
	},
	lazy = true,
	config = function()
		---@type opencode.Opts
		vim.g.opencode_opts = {
			-- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition".
			provider = {
				enabled = "tmux",
				tmux = {},
			},
		}

		-- Required for `opts.auto_reload`.
		vim.o.autoread = true
	end,
}
