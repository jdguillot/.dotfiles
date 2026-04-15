return {
	"folke/sidekick.nvim",
	opts = {
		cli = {
			mux = {
				backend = "tmux",
				enabled = true,
				create = "split",
				split = {
					vertical = true,
					size = 0.3,
				},
			},
		},
		-- copilot = {
		-- 	status = {
		-- 		level = vim.log.levels.OFF,
		-- 	},
		-- },
	},
	keys = {
		{
			"<tab>",
			function()
				-- if there is a next edit, jump to it, otherwise apply it if any
				if not require("sidekick").nes_jump_or_apply() then
					return "<Tab>" -- fallback to normal tab
				end
			end,
			expr = true,
			desc = "Goto/Apply Next Edit Suggestion",
		},
	},
}
