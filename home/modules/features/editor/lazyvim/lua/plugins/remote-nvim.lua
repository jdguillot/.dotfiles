return {
	"amitds1997/remote-nvim.nvim",
	lazy = true,
	cmd = { "RemoteStart", "RemoteStop", "RemoteInfo", "RemoteCleanup", "RemoteConfigDel", "RemoteLog" },
	keys = {
		{ "<leader>rs", "<cmd>RemoteStart<cr>", desc = "Remote Start" },
		{ "<leader>rS", "<cmd>RemoteStop<cr>", desc = "Remote Stop" },
		{ "<leader>ri", "<cmd>RemoteInfo<cr>", desc = "Remote Info" },
		{ "<leader>rc", "<cmd>RemoteCleanup<cr>", desc = "Remote Cleanup" },
		{ "<leader>rd", "<cmd>RemoteConfigDel<cr>", desc = "Remote Config Delete" },
		{ "<leader>rl", "<cmd>RemoteLog<cr>", desc = "Remote Log" },
	},
	config = true,
}
