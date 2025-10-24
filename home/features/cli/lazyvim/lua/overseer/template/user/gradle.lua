return {
	name = "gradle build",
	builder = function()
		return {
			cmd = { "./gradlew" },
			args = { "build" },
			components = { "default" },
		}
	end,
}
