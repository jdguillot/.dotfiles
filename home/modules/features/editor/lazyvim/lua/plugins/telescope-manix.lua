-- Nix documentation search via :Telescope manix. Plugin binary lives in
-- the Nix dev.path farm; the spec entry's owner/name is what maps lazy to
-- that farm dir (a bare name has no url, so lazy won't redirect).
return {
	"mrcjkb/telescope-manix",
	cmd = "Telescope",
	keys = {
		{ "<leader>nm", "<cmd>Telescope manix<cr>", desc = "Nix docs search" },
	},
	-- top-level require("telescope") in this plugin fires on load, so lazy must
	-- load telescope.nvim first. LazyVim core declares it, but only as lazy = true
	-- on "Telescope" — explicit dep forces the ordering.
	dependencies = { "nvim-telescope/telescope.nvim" },
}
