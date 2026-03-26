return {
	{
		"nvim-java/nvim-java",
		dependencies = {
			"nvim-java/lua-async-await",
			"nvim-java/nvim-java-core",
			"nvim-java/nvim-java-test",
			"nvim-java/nvim-java-dap",
			"MunifTanjim/nui.nvim",
			"neovim/nvim-lspconfig",
			"mfussenegger/nvim-dap",
		},
	},
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				jdtls = {
					-- Set your JDK path here
					-- settings = {
					-- 	java = {
					-- 		configuration = {
					-- 			runtimes = {
					-- 				--   {
					-- 				--     name = "JavaSE-17",
					-- 				--     path = "/path/to/your/jdk-17", -- Change this!
					-- 				--     default = true,
					-- 				--   },
					-- 				--   -- Add more JDK versions if needed
					-- 			},
					-- 		},
					-- 	},
					-- },
				},
			},
		},
	},
}
