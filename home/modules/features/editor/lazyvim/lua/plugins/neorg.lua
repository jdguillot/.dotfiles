return {
  "nvim-neorg/neorg",
  lazy = false,
  ft = "norg",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  cmd = "Neorg",
	config = function()
		require("neorg").setup({
			load = {
				["core.defaults"] = {},
				["core.concealer"] = {},
				["core.keybinds"] = {
					config = {
						default_keybinds = true,
						neorg_leader = "<Leader>",
					},
				},
				["core.dirman"] = {
					config = {
						workspaces = {
							notes = "~/notes",
						},
						default_workspace = "notes",
					},
				},
				["core.journal"] = {
					config = {
						workspace = "notes",
					},
				},
			},
		})

		local wk = require("which-key")

		-- Helper function to get all .norg files in workspace
		local function get_norg_files()
			local workspace = vim.fn.expand("~/notes")
			local files = vim.fn.systemlist("find " .. workspace .. ' -type f -name "*.norg"')
			local items = {}
			for _, file in ipairs(files) do
				local name = vim.fn.fnamemodify(file, ":t:r")
				local relative = vim.fn.fnamemodify(file, ":~:.")
				table.insert(items, {
					idx = #items + 1,
					text = name .. " - " .. relative,
					file = file,
					name = name,
				})
			end
			return items
		end

		-- Picker for neorg files
		local function pick_norg_file()
			local items = get_norg_files()
			Snacks.picker.pick({
				title = "Neorg Files",
				items = items,
				confirm = function(picker, item)
					picker:close()
					if item then
						vim.cmd("edit " .. vim.fn.fnameescape(item.file))
					end
				end,
			})
		end

		-- Picker for creating/linking to notes
		local function pick_or_create_link()
			local items = get_norg_files()
			Snacks.picker.pick({
				title = "Insert Link to Note",
				prompt = "Link: ",
				items = items,
				confirm = function(picker, item)
					picker:close()
					if item then
						local link = "{:$/" .. item.name .. ":}"
						vim.api.nvim_put({ link }, "c", true, true)
					end
				end,
			})
		end

		-- Picker for headings in current file
		local function pick_heading()
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			local items = {}
			for lnum, line in ipairs(lines) do
				if line:match("^%*+%s") then
					local level = #line:match("^%*+")
					local heading = line:match("^%*+%s+(.+)$")
					if heading then
						table.insert(items, {
							idx = #items + 1,
							text = string.rep("  ", level - 1) .. heading,
							lnum = lnum,
						})
					end
				end
			end

			if #items == 0 then
				vim.notify("No headings found", vim.log.levels.INFO)
				return
			end

			Snacks.picker.pick({
				title = "Jump to Heading",
				items = items,
				confirm = function(picker, item)
					picker:close()
					if item then
						vim.api.nvim_win_set_cursor(0, { item.lnum, 0 })
						vim.cmd("normal! zz")
					end
				end,
			})
		end

		-- Picker for TODO items in current file
		local function pick_todo()
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			local items = {}
			for lnum, line in ipairs(lines) do
				if line:match("^%s*%-%s+%(") then
					local status = line:match("%(([^%)]+)%)")
					local text = line:match("%)%s+(.+)$")
					if text then
						local icon = "○"
						if status == "x" then
							icon = "✓"
						elseif status == "-" then
							icon = "◐"
						elseif status == "!" then
							icon = "‼"
						end
						table.insert(items, {
							idx = #items + 1,
							text = string.format("%s %s", icon, text),
							lnum = lnum,
						})
					end
				end
			end

			if #items == 0 then
				vim.notify("No TODO items found", vim.log.levels.INFO)
				return
			end

			Snacks.picker.pick({
				title = "Jump to TODO",
				items = items,
				confirm = function(picker, item)
					picker:close()
					if item then
						vim.api.nvim_win_set_cursor(0, { item.lnum, 0 })
						vim.cmd("normal! zz")
					end
				end,
			})
		end

		-- Picker for workspaces
		local function pick_workspace()
			local workspaces = { "notes", "work", "personal" }
			local items = {}
			for i, ws in ipairs(workspaces) do
				table.insert(items, {
					idx = i,
					text = ws,
					workspace = ws,
				})
			end
			Snacks.picker.pick({
				title = "Switch Workspace",
				items = items,
				confirm = function(picker, item)
					picker:close()
					if item then
						vim.cmd("Neorg workspace " .. item.workspace)
					end
				end,
			})
		end

    -- Global neorg commands (work everywhere)
    wk.add({
      { "<leader>N", group = "neorg", desc = "Neorg", icon = "" },
      { "<leader>Nn", "<Plug>(neorg.dirman.new-note)", desc = "New note", icon = "" },
      { "<leader>Nr", "<cmd>Neorg return<cr>", desc = "Return", icon = "󰌍" },
      { "<leader>Nf", pick_norg_file, desc = "Find note", icon = "" },
      { "<leader>Ni", "<cmd>Neorg index<cr>", desc = "Open index", icon = "" },

			{ "<leader>Nj", group = "journal", icon = "" },
			{ "<leader>Njt", "<cmd>Neorg journal today<cr>", desc = "Today", icon = "󰃭" },
			{ "<leader>Njy", "<cmd>Neorg journal yesterday<cr>", desc = "Yesterday", icon = "󰃮" },
			{ "<leader>Njm", "<cmd>Neorg journal tomorrow<cr>", desc = "Tomorrow", icon = "󰃱" },
			{ "<leader>Njc", "<cmd>Neorg journal custom<cr>", desc = "Custom date", icon = "" },
			{ "<leader>Njo", "<cmd>Neorg journal toc open<cr>", desc = "Journal TOC", icon = "" },

			{ "<leader>Nw", group = "workspace", icon = "󱂬" },
			{ "<leader>Nws", "<cmd>Neorg workspace<cr>", desc = "Show workspace", icon = "" },
			{ "<leader>Nww", pick_workspace, desc = "Switch workspace", icon = "󱂬" },

			{ "<leader>No", "<cmd>Neorg toc<cr>", desc = "Table of contents", icon = "" },
		})

		-- Buffer-local keybinds for .norg files
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "norg",
			callback = function()
				local opts = { buffer = true, silent = true }

				-- Navigation
				vim.keymap.set("n", "gd", "<Plug>(neorg.esupports.hop.hop-link)", opts)
				vim.keymap.set("n", "<CR>", "<Plug>(neorg.esupports.hop.hop-link)", opts)
				vim.keymap.set("n", "<M-CR>", "<Plug>(neorg.esupports.hop.hop-link.vsplit)", opts)

				-- Task cycling (quick toggle)
				vim.keymap.set("n", "<C-Space>", "<Plug>(neorg.qol.todo-items.todo.task-cycle)", opts)

				-- List continuation
				vim.keymap.set("i", "<M-CR>", "<Plug>(neorg.itero.next-iteration)", opts)

				-- Promotion/Demotion in insert mode
				vim.keymap.set("i", "<C-t>", "<Plug>(neorg.promo.promote)", opts)
				vim.keymap.set("i", "<C-d>", "<Plug>(neorg.promo.demote)", opts)

				-- Which-key groups for buffer-local commands
				wk.add({
					{
						"<localleader>t",
						group = "tasks",
						icon = "",
						buffer = true,
					},
					{
						"<localleader>tf",
						pick_todo,
						desc = "Find TODO",
						icon = "",
						buffer = true,
					},
					{
						"<localleader>tu",
						"<Plug>(neorg.qol.todo-items.todo.task-undone)",
						desc = "Undone",
						icon = "",
						buffer = true,
					},
					{
						"<localleader>tp",
						"<Plug>(neorg.qol.todo-items.todo.task-pending)",
						desc = "Pending",
						icon = "󰥔",
						buffer = true,
					},
					{
						"<localleader>td",
						"<Plug>(neorg.qol.todo-items.todo.task-done)",
						desc = "Done",
						icon = "",
						buffer = true,
					},
					{
						"<localleader>th",
						"<Plug>(neorg.qol.todo-items.todo.task-on-hold)",
						desc = "On hold",
						icon = "󰏤",
						buffer = true,
					},
					{
						"<localleader>tc",
						"<Plug>(neorg.qol.todo-items.todo.task-cancelled)",
						desc = "Cancelled",
						icon = "",
						buffer = true,
					},
					{
						"<localleader>tr",
						"<Plug>(neorg.qol.todo-items.todo.task-recurring)",
						desc = "Recurring",
						icon = "󰑖",
						buffer = true,
					},
					{
						"<localleader>ti",
						"<Plug>(neorg.qol.todo-items.todo.task-important)",
						desc = "Important",
						icon = "󰀪",
						buffer = true,
					},
					{
						"<localleader>ta",
						"<Plug>(neorg.qol.todo-items.todo.task-ambiguous)",
						desc = "Ambiguous",
						icon = "",
						buffer = true,
					},

					{ "<localleader>l", group = "lists", icon = "", buffer = true },
					{
						"<localleader>lt",
						"<Plug>(neorg.pivot.list.toggle)",
						desc = "Toggle list type",
						icon = "󰌁",
						buffer = true,
					},
					{
						"<localleader>li",
						"<Plug>(neorg.pivot.list.invert)",
						desc = "Invert list",
						icon = "",
						buffer = true,
					},

					{ "<localleader>i", group = "insert", icon = "", buffer = true },
					{
						"<localleader>id",
						"<Plug>(neorg.tempus.insert-date)",
						desc = "Insert date",
						icon = "",
						buffer = true,
					},
					{
						"<localleader>il",
						pick_or_create_link,
						desc = "Insert link",
						icon = "",
						buffer = true,
					},
					{
						"<localleader>in",
						function()
							local filename = vim.fn.input("New note name: ")
							if filename ~= "" then
								local link = "{:$/" .. filename .. ":}"
								vim.api.nvim_put({ link }, "c", true, true)
							end
						end,
						desc = "Insert new note link",
						icon = "",
						buffer = true,
					},

					{
						"<localleader>g",
						group = "goto",
						icon = "󰁔",
						buffer = true,
					},
					{
						"<localleader>gh",
						pick_heading,
						desc = "Goto heading",
						icon = "",
						buffer = true,
					},

					{
						"<localleader>m",
						"<Plug>(neorg.looking-glass.magnify-code-block)",
						desc = "Magnify code block",
						icon = "",
						buffer = true,
					},
				})
			end,
		})
	end,
}
