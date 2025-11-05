return {
	"stevearc/overseer.nvim",
	opts = {
		templates = { "builtin" },
	},
	config = function(_, opts)
		local overseer = require("overseer")
		overseer.setup(opts)

		-- Function to get all Gradle tasks
		local function register_gradle_tasks()
			local handle = io.popen("./gradlew tasks --all 2>/dev/null | grep -E '^[a-zA-Z]' | awk '{print $1}'")
			if not handle then
				return
			end

			local common_tasks = { "build", "test", "clean", "assemble", "run" }

			-- Register common tasks first
			for _, task in ipairs(common_tasks) do
				overseer.register_template({
					name = "gradle " .. task,
					builder = function()
						return {
							cmd = { "./gradlew" },
							args = { task },
							components = {
								{ "on_output_quickfix", open = true },
								{ "on_complete_notify" },
								"default",
							},
						}
					end,
					condition = {
						callback = function()
							return vim.fn.filereadable("gradlew") == 1
						end,
					},
				})
			end

			-- Register all other discovered tasks
			for task in handle:lines() do
				if task ~= "" and not vim.tbl_contains(common_tasks, task) then
					overseer.register_template({
						name = "gradle " .. task,
						builder = function()
							return {
								cmd = { "./gradlew" },
								args = { task },
								components = { "default" },
							}
						end,
						condition = {
							callback = function()
								return vim.fn.filereadable("gradlew") == 1
							end,
						},
					})
				end
			end

			handle:close()
		end

		-- Register tasks when entering a Java/Kotlin project
		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "java", "kotlin", "groovy" },
			callback = function()
				if vim.fn.filereadable("gradlew") == 1 then
					register_gradle_tasks()
				end
			end,
		})
	end,
}
