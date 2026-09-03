-- Dev-trait only: vim.g.dotfiles_dev is set from Nix in initLua.
if not vim.g.dotfiles_dev then
  return {}
end

return {
	"trixnz/sops.nvim",
	lazy = false,
}
