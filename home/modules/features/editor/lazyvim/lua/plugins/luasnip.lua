return {
	"L3MON4D3/LuaSnip",
	dependencies = { "friendly-snippets" },
	config = function()
		require("luasnip.loaders.from_vscode").lazy_load() -- Load friendly-snippets

		-- Try loading with the full project path
		require("luasnip.loaders.from_vscode").load({
			paths = { vim.fn.getcwd() .. "/.vscode" },
		})

		-- Alternative: load from the project root
		require("luasnip.loaders.from_vscode").load({
			paths = { vim.fn.getcwd() },
		})
	end,
}
