return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local home = vim.env.HOME
      local user = vim.env.USER
      local hostname = vim.fn.hostname()
      local dotfiles_path = home .. "/.dotfiles"

      -- Construct the home-manager configuration name
      local hm_config = user .. "@" .. hostname

      opts.servers = opts.servers or {}
      opts.servers.nixd = {
        cmd = { "nixd" },
        settings = {
          nixd = {
            nixpkgs = {
              expr = string.format('import (builtins.getFlake "%s").inputs.nixpkgs { }', dotfiles_path),
            },
            formatting = {
              command = { "nixfmt" },
            },
            options = {
              nixos = {
                expr = string.format('(builtins.getFlake "%s").nixosConfigurations.%s.options', dotfiles_path, hostname),
              },
              home_manager = {
                expr = string.format('(builtins.getFlake "%s").homeConfigurations."%s".options', dotfiles_path, hm_config),
              },
            },
          },
        },
      }
      return opts
    end,
  },
}
