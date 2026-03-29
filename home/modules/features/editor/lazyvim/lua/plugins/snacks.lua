return {
	"folke/snacks.nvim",
	opts = {
		gh = {
			-- your gh configuration comes here
			-- or leave it empty to use the default settings
			-- refer to the configuration section below
		},
		picker = {
			sources = {
				gh_issue = {
					-- your gh_issue picker configuration comes here
					-- or leave it empty to use the default settings
				},
				gh_pr = {
					-- your gh_pr picker configuration comes here
					-- or leave it empty to use the default settings
				},
				explorer = {
					win = {
						list = {
							keys = {
								-- Explorer is a floating sidebar; wincmd-based tmux nav picks the wrong window.
								-- Use tmux select-pane directly for h/j/k, and focus picker.main for l (editor).
								["<c-h>"] = "explorer_tmux_left",
								["<c-j>"] = "explorer_tmux_down",
								["<c-k>"] = "explorer_tmux_up",
								["<c-l>"] = "explorer_focus_right",
							},
						},
					},
				},
			},
			actions = {
				explorer_focus_right = function(picker)
					vim.api.nvim_set_current_win(picker.main)
				end,
				explorer_tmux_left = function()
					vim.fn.system("tmux select-pane -L")
				end,
				explorer_tmux_down = function()
					vim.fn.system("tmux select-pane -D")
				end,
				explorer_tmux_up = function()
					vim.fn.system("tmux select-pane -U")
				end,
			},
		},
	},
	keys = {
		{
			"<leader>gi",
			function()
				Snacks.picker.gh_issue()
			end,
			desc = "GitHub Issues (open)",
		},
		{
			"<leader>gI",
			function()
				Snacks.picker.gh_issue({ state = "all" })
			end,
			desc = "GitHub Issues (all)",
		},
		{
			"<leader>gp",
			function()
				Snacks.picker.gh_pr()
			end,
			desc = "GitHub Pull Requests (open)",
		},
		{
			"<leader>gP",
			function()
				Snacks.picker.gh_pr({ state = "all" })
			end,
			desc = "GitHub Pull Requests (all)",
		},
	},
}
