return {
	"stevearc/overseer.nvim",
	opts = {
		task_list = {
			default_detail = 1,
		},
		load_tasks = {
			"gradle",
		},
		-- Ensure gradle is in the list of providers
		task_provider = {
			"gradle",
		},
	},
}
