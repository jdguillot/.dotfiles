-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = function()
		vim.b.autoformat = false
	end,
})

vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
	callback = function()
		local cwd = vim.fn.getcwd()
		local work_notes = vim.fn.expand("~/projects/work-notes")

		if cwd == work_notes or cwd:find(work_notes, 1, true) == 1 then
			require("lazy").load({ plugins = { "obsidian.nvim" } })
		end
	end,
})

-- ── Swap file utilities ───────────────────────────────────────────────────────
do
	--- All swap files on disk for a given absolute filepath.
	local function find_swap_files(filepath)
		local resolved = vim.fn.resolve(vim.fn.expand(filepath))
		local swapdir = vim.fn.stdpath("state") .. "/swap"
		local escaped = resolved:gsub("/", "%%")
		return vim.fn.glob(swapdir .. "/" .. escaped .. ".sw?", false, true)
	end

	--- True if the given pid corresponds to a running process.
	local function is_running(pid)
		if not pid or pid <= 0 then
			return false
		end
		return pcall(vim.uv.kill, pid, 0)
	end

	--- Only swap files whose owning process is no longer alive.
	local function find_dead_swaps(filepath)
		local active = vim.fn.swapname(vim.api.nvim_get_current_buf())
		local dead = {}
		for _, swap in ipairs(find_swap_files(filepath)) do
			if swap ~= active then
				local info = vim.fn.swapinfo(swap)
				if not info.error and not is_running(info.pid) then
					table.insert(dead, swap)
				end
			end
		end
		return dead
	end

	--- Temporarily recover from a specific swap into the current buffer.
	--- Renames competing swaps aside so :recover! never prompts.
	--- Returns (ok, err, recovered_lines).
	--- The caller is responsible for restoring the buffer if needed.
	local function isolate_and_recover(target_swap)
		local filepath = vim.fn.expand("%:p")
		local hidden = {}
		for _, swap in ipairs(find_swap_files(filepath)) do
			if swap ~= target_swap then
				local tmp = swap .. ".recovering"
				if vim.fn.rename(swap, tmp) == 0 then
					table.insert(hidden, { tmp = tmp, orig = swap })
				end
			end
		end
		-- Stop treesitter to prevent render-markdown index errors during recovery
		pcall(vim.treesitter.stop, 0)
		-- recover! suppresses E308 ("original file may have been changed")
		local ok, err = pcall(vim.cmd, "silent! recover!")
		local lines = ok and vim.api.nvim_buf_get_lines(0, 0, -1, false) or {}
		-- Always restore renamed swaps
		for _, pair in ipairs(hidden) do
			vim.fn.rename(pair.tmp, pair.orig)
		end
		return ok, err, lines
	end

	--- Auto-select if only one dead swap; otherwise show vim.ui.select.
	local function pick_swap(dead, cb)
		if #dead == 1 then
			cb(dead[1])
		else
			local labels = vim.tbl_map(function(s)
				local info = vim.fn.swapinfo(s)
				local t = info.mtime and os.date("%Y-%m-%d %H:%M", info.mtime) or "?"
				return vim.fn.fnamemodify(s, ":t") .. "  (" .. t .. ")"
			end, dead)
			vim.ui.select(labels, { prompt = "Select dead swap file:" }, function(_, idx)
				if idx then
					cb(dead[idx])
				end
			end)
		end
	end

	-- :SwapDiff — open a new tab showing disk vs swap content as a read-only diff.
	-- The original buffer is NOT modified.
	vim.api.nvim_create_user_command("SwapDiff", function()
		local filepath = vim.fn.expand("%:p")
		if filepath == "" then
			vim.notify("No file in current buffer", vim.log.levels.ERROR)
			return
		end
		local dead = find_dead_swaps(filepath)
		if #dead == 0 then
			vim.notify("No dead swap files found for " .. vim.fn.fnamemodify(filepath, ":t"), vim.log.levels.INFO)
			return
		end
		local ft = vim.bo.filetype
		local disk_lines = vim.fn.readfile(filepath)
		-- Snapshot current buffer so we can restore it after the temp recovery
		local cur_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		local was_modified = vim.bo.modified

		pick_swap(dead, function(swap)
			local ok, err, recovered_lines = isolate_and_recover(swap)

			-- Always restore the original buffer first
			vim.api.nvim_buf_set_lines(0, 0, -1, false, cur_lines)
			if not was_modified then
				vim.cmd("noautocmd set nomodified")
			end
			vim.schedule(function()
				pcall(vim.treesitter.start, 0)
			end)

			if not ok then
				vim.notify("Could not read swap: " .. tostring(err), vim.log.levels.ERROR)
				return
			end

			-- Open diff in a new tab so layout is clean
			vim.cmd("tabnew")
			local function make_scratch(lines, name)
				local buf = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_win_set_buf(0, buf)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
				vim.bo[buf].filetype = ft
				vim.bo[buf].swapfile = false
				vim.bo[buf].modifiable = false
				vim.api.nvim_buf_set_name(buf, name)
				vim.cmd("diffthis")
				return buf
			end

			make_scratch(disk_lines, filepath .. " [disk]")
			vim.cmd("vsplit")
			make_scratch(recovered_lines, filepath .. " [swap]")
		end)
	end, { desc = "Diff disk vs dead swap content in a new tab (non-destructive)" })

	-- :SwapRecover[!] — recover current buffer from a dead swap file.
	vim.api.nvim_create_user_command("SwapRecover", function(opts)
		local filepath = vim.fn.expand("%:p")
		if filepath == "" then
			vim.notify("No file in current buffer", vim.log.levels.ERROR)
			return
		end
		local dead = find_dead_swaps(filepath)
		if #dead == 0 then
			vim.notify("No dead swap files found for " .. vim.fn.fnamemodify(filepath, ":t"), vim.log.levels.INFO)
			return
		end
		pick_swap(dead, function(swap)
			local ok, err, _ = isolate_and_recover(swap)
			vim.schedule(function()
				pcall(vim.treesitter.start, 0)
			end)
			if not ok then
				vim.notify("Recovery failed: " .. tostring(err), vim.log.levels.ERROR)
			end
		end)
	end, { bang = true, desc = "Recover current buffer from a dead swap file" })

	-- :SwapDelete — delete dead-session swap files (never touches the active swap).
	vim.api.nvim_create_user_command("SwapDelete", function()
		local filepath = vim.fn.expand("%:p")
		if filepath == "" then
			vim.notify("No file in current buffer", vim.log.levels.ERROR)
			return
		end
		local dead = find_dead_swaps(filepath)
		if #dead == 0 then
			vim.notify("No dead swap files found", vim.log.levels.INFO)
			return
		end
		local deleted = {}
		for _, swap in ipairs(dead) do
			if vim.fn.delete(swap) == 0 then
				table.insert(deleted, vim.fn.fnamemodify(swap, ":t"))
			else
				vim.notify("Failed to delete: " .. swap, vim.log.levels.ERROR)
			end
		end
		if #deleted > 0 then
			vim.notify("Deleted: " .. table.concat(deleted, ", "))
		end
	end, { desc = "Delete dead swap files for current buffer" })
end
