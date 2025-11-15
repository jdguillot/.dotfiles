return {
	"NickvanDyke/opencode.nvim",
	dependencies = {
		-- Recommended for `ask()` and `select()`.
		-- Required for `snacks` provider.
		---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
		{ "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
	},
	keys = {
		{
			"<leader>ao",
			function()
				require("opencode").ask("@this: ", { submit = true })
			end,
			mode = { "n", "x" },
			desc = "Ask OpenCode",
		},
		{
			"<leader>aO",
			function()
				require("opencode").select()
			end,
			mode = { "n", "x" },
			desc = "OpenCode actions…",
		},
		{
			"<leader>aP",
			function()
				require("opencode").prompt("@this")
			end,
			mode = { "n", "x" },
			desc = "Add to OpenCode",
		},
		{
			"<leader>at",
			function()
				require("opencode").toggle()
			end,
			mode = { "n", "t" },
			desc = "Toggle OpenCode",
		},
		{
			"<leader>au",
			function()
				require("opencode").command("session.half.page.up")
			end,
			desc = "OpenCode half page up",
		},
		{
			"<leader>ad",
			function()
				require("opencode").command("session.half.page.down")
			end,
			desc = "OpenCode half page down",
		},
	},
	config = function()
		---@type opencode.Opts
		vim.g.opencode_opts = {
			-- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition".
		}

		-- Required for `opts.auto_reload`.
		vim.o.autoread = true
	end,
}
