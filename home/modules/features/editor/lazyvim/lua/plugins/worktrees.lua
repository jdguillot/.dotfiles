return {
	"afonsofrancof/worktrees.nvim",
	event = "VeryLazy",
	keys = {
		{ "<leader>gwc", "<cmd>WorktreeCreate<cr>", desc = "Create worktree" },
		{ "<leader>gwd", "<cmd>WorktreeDelete<cr>", desc = "Delete worktree" },
		{ "<leader>gws", "<cmd>WorktreeSwitch<cr>", desc = "Switch worktree" },
	},
	opts = {
		-- Specify where to create worktrees relative to git common dir
		-- The common dir is the .git dir in a normal repo or the root dir of a bare repo
		base_path = "..", -- Parent directory of common dir

		-- Template for worktree folder names (string or function(branch) -> path)
		-- This is only used if you don't specify the folder name when creating the worktree
		path_template = "{branch}", -- Default: use branch name

		-- Command names (optional)
		commands = {
			create = "WorktreeCreate",
			delete = "WorktreeDelete",
			switch = "WorktreeSwitch",
		},
	},
}
