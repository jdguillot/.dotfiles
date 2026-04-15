return {
	{
		"nvim-mini/mini.surround",
		version = "*",

		opts = {
			custom_surroundings = {
				[")"] = { output = { left = "(", right = ")" } },
				["]"] = { output = { left = "[", right = "]" } },
				["}"] = { output = { left = "{", right = "}" } },
				["("] = { output = { left = "(", right = ")" } },
				["["] = { output = { left = "[", right = "]" } },
				["{"] = { output = { left = "{", right = "}" } },
			},
		},
	},
}
