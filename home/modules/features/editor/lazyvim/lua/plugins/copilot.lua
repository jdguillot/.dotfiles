return {
	"zbirenbaum/copilot.lua",
	opts = {
		disable_limit_reached_message = true, -- Set to `true` to suppress completion limit reached popup
		suggestion = {
			enabled = true,
			auto_trigger = true,
			keymap = {
				-- accept = "<Tab>",
				accept_word = "<C-l>",
				accept_line = "<C-j>",
				next = "<M-]>",
				prev = "<M-[>",
				dismiss = "<C-]>",
			},
		},
	},
}
