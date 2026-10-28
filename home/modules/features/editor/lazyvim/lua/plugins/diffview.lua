return {
	"sindrets/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
	keys = {
		{
			"<leader>gv",
			function()
				if next(require("diffview.lib").views) == nil then
					vim.cmd("DiffviewOpen")
				else
					vim.cmd("DiffviewClose")
				end
			end,
			desc = "Diffview (toggle)",
		},
		{ "<leader>gV", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview File History" },
	},
	opts = {
		enhanced_diff_hl = true,
		view = {
			-- ours | base | theirs over the result: the base column shows what
			-- each side started from, which is what makes a conflict readable.
			merge_tool = {
				layout = "diff4_mixed",
			},
		},
	},
}
