return {
	"zbirenbaum/copilot.lua",
	requires = {
		"copilotlsp-nvim/copilot-lsp", -- (optional) for NES functionality
	},
	opts = {
		-- disable_limit_reached_message = true, -- Set to `true` to suppress completion limit reached popup
		suggestion = {
			enabled = true, -- Re-enabled for inline suggestions
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
