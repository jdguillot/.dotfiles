-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("i", "jj", "<Esc>", { noremap = true, silent = true })

local wk = require("which-key")

-- Overseer keymaps
wk.add({
	{ "<leader>t", group = "overseer", desc = "Tasks", icon = "󱌢" },
	{ "<leader>tt", "<cmd>OverseerToggle<cr>", desc = "Toggle Overseer", icon = "󱌢" },
	{ "<leader>tr", "<cmd>OverseerRun<cr>", desc = "Run task", icon = "󰜎" },
	{ "<leader>ta", "<cmd>OverseerTaskAction<cr>", desc = "Task action", icon = "󰌆" },
	{ "<leader>tl", "<cmd>OverseerLoadBundle<cr>", desc = "Load bundle", icon = "󰏖" },
	{ "<leader>ts", "<cmd>OverseerSaveBundle<cr>", desc = "Save bundle", icon = "󰆓" },
	{ "<leader>tq", "<cmd>OverseerQuickAction<cr>", desc = "Quick action", icon = "󰓁" },
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

-- OpenCode keymaps
wk.add({
	{ "<leader>a", group = "ai", icon = "" },
	{ "<leader>ao", function() require("opencode").ask("@this: ", { submit = true }) end, mode = { "n", "x" }, desc = "Ask OpenCode", icon = "" },
	{ "<leader>aO", function() require("opencode").select() end, mode = { "n", "x" }, desc = "OpenCode actions…", icon = "" },
	{ "<leader>aP", function() require("opencode").prompt("@this") end, mode = { "n", "x" }, desc = "Add to OpenCode", icon = "" },
	{ "<leader>at", function() require("opencode").toggle() end, mode = { "n", "t" }, desc = "Toggle OpenCode", icon = "" },
	{ "<leader>au", function() require("opencode").command("session.half.page.up") end, desc = "OpenCode half page up", icon = "" },
	{ "<leader>ad", function() require("opencode").command("session.half.page.down") end, desc = "OpenCode half page down", icon = "" },
})

-- Markdown keymaps
-- wk.add({
-- 	{ "<leader>i", "<cmd>PasteImg<cr>", desc = "Paste image", icon = "" },
-- })


wk.add({
  { "<leader>i", "<cmd>PasteImage<cr>", desc = "Paste image from clipboard", icon = "" },
})
