return {
	generator = function(opts, cb)
		local tasks = {}

		-- Run ./gradlew tasks to get all available tasks
		local handle = io.popen("./gradlew tasks --all 2>/dev/null")
		if handle then
			local result = handle:read("*a")
			handle:close()

			-- Parse task names from output
			for line in result:gmatch("[^\r\n]+") do
				local task_name = line:match("^(%w+)%s*%-")
				if task_name then
					table.insert(tasks, {
						name = "gradle " .. task_name,
						builder = function()
							return {
								cmd = { "./gradlew" },
								args = { task_name },
								components = {
									{ "on_output_quickfix", open = true },
									"default",
								},
							}
						end,
					})
				end
			end
		end

		cb(tasks)
	end,
}
