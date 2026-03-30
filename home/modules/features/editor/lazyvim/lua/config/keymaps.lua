-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("i", "jj", "<Esc>", { noremap = true, silent = true })
vim.keymap.set({ "i", "n" }, "<Select>", "<End>", { noremap = true, silent = true })

vim.keymap.set({ "n", "i", "t" }, "<c-x>", "<cmd>q<cr>", { noremap = true, silent = true })

local wk = require("which-key")

-- Overseer keymaps
wk.add({
	{ "<leader>r", group = "overseer", desc = "Tasks", icon = "󱌢" },
	{ "<leader>rt", "<cmd>OverseerToggle<cr>", desc = "Toggle Overseer", icon = "󱌢" },
	{ "<leader>rr", "<cmd>OverseerRun<cr>", desc = "Run task", icon = "󰜎" },
	{ "<leader>ra", "<cmd>OverseerTaskAction<cr>", desc = "Task action", icon = "󰌆" },
	{ "<leader>rl", "<cmd>OverseerLoadBundle<cr>", desc = "Load bundle", icon = "󰏖" },
	{ "<leader>rs", "<cmd>OverseerSaveBundle<cr>", desc = "Save bundle", icon = "󰆓" },
	{ "<leader>rq", "<cmd>OverseerQuickAction<cr>", desc = "Quick action", icon = "󰓁" },
})

-- Obsidian keymaps
wk.add({
	{ "<leader>o", group = "obsidian", desc = "Obsidian", icon = "󱞁" },

	{ "<leader>on", group = "new", icon = "󰈔" },
	{ "<leader>onn", "<cmd>ObsidianNew<cr>", desc = "New note", icon = "" },
	{ "<leader>ont", "<cmd>ObsidianNewFromTemplate<cr>", desc = "New template note", icon = "" },

	{ "<leader>of", "<cmd>ObsidianQuickSwitch<cr>", desc = "Find note", icon = "" },
	{ "<leader>os", "<cmd>ObsidianSearch<cr>", desc = "Search notes", icon = "" },
	{ "<leader>oo", "<cmd>ObsidianOpen<cr>", desc = "Open in Obsidian", icon = "󰏌" },

	{ "<leader>od", group = "daily", icon = "" },
	{ "<leader>odt", "<cmd>ObsidianToday<cr>", desc = "Today's note", icon = "󰃭" },
	{ "<leader>ody", "<cmd>ObsidianYesterday<cr>", desc = "Yesterday's note", icon = "󰃮" },
	{ "<leader>odm", "<cmd>ObsidianTomorrow<cr>", desc = "Tomorrow's note", icon = "󰃱" },

	{ "<leader>ol", group = "links", icon = "" },
	{ "<leader>oll", "<cmd>ObsidianLink<cr>", desc = "Link selection", mode = "v", icon = "" },
	{ "<leader>oln", "<cmd>ObsidianLinkNew<cr>", desc = "Link to new note", mode = "v", icon = "󰈔" },
	{ "<leader>olb", "<cmd>ObsidianBacklinks<cr>", desc = "Show backlinks", icon = "󰌷" },
	{ "<leader>olf", "<cmd>ObsidianFollowLink<cr>", desc = "Follow link", icon = "󰁔" },
	{ "<leader>ot", "<cmd>ObsidianTemplate<cr>", desc = "Insert template", icon = "" },
	{ "<leader>ow", "<cmd>ObsidianWorkspace<cr>", desc = "Switch workspace", icon = "󱂬" },
	{ "<leader>ob", "<cmd>ObsidianBacklinks<cr>", desc = "Backlinks", icon = "󰌷" },
	{ "<leader>or", "<cmd>ObsidianRename<cr>", desc = "Rename note", icon = "󰑕" },
	{ "<leader>oc", "<cmd>ObsidianToggleCheckbox<cr>", desc = "Toggle checkbox", icon = "󰄲" },
	{ "<leader>oT", "<cmd>ObsidianTags<cr>", desc = "Search tags", icon = "" },
})

-- Mini Diff keymaps
wk.add({
	{ "<leader>gh", group = "hunks", icon = "" },
	{
		"<leader>ghr",
		function()
			local line = vim.fn.line(".")
			MiniDiff.do_hunks(0, "reset", { line_start = line, line_end = line })
		end,
		desc = "Reset hunk",
		icon = "󰜺",
	},
	{
		"<leader>ghr",
		function()
			local line_start = vim.fn.line("v")
			local line_end = vim.fn.line(".")
			if line_start > line_end then
				line_start, line_end = line_end, line_start
			end
			MiniDiff.do_hunks(0, "reset", { line_start = line_start, line_end = line_end })
		end,
		desc = "Reset hunk",
		mode = "v",
		icon = "󰜺",
	},
	{
		"<leader>gho",
		function()
			MiniDiff.toggle_overlay(0)
		end,
		desc = "Toggle diff overlay",
		icon = "",
	},
})

-- Git Conflict keymaps
wk.add({
	{ "<leader>gx", group = "conflicts", icon = "" },
	{ "<leader>gxo", "<Plug>(git-conflict-ours)", desc = "Choose Ours", icon = "" },
	{ "<leader>gxt", "<Plug>(git-conflict-theirs)", desc = "Choose Theirs", icon = "" },
	{ "<leader>gxb", "<Plug>(git-conflict-both)", desc = "Choose Both", icon = "" },
	{ "<leader>gx0", "<Plug>(git-conflict-none)", desc = "Choose None", icon = "" },
	{ "[x", "<Plug>(git-conflict-prev-conflict)", desc = "Previous Conflict" },
	{ "]x", "<Plug>(git-conflict-next-conflict)", desc = "Next Conflict" },
	{ "<leader>gxl", "<cmd>GitConflictListQf<cr>", desc = "List Conflicts", icon = "" },
})

-- Markdown keymaps
-- wk.add({
-- 	{ "<leader>i", "<cmd>PasteImg<cr>", desc = "Paste image", icon = "" },
-- })

wk.add({
	{ "<leader>i", "<cmd>PasteImage<cr>", desc = "Paste image from clipboard", icon = "" },
})
