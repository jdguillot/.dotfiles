{
  pkgs,
  inputs,
  hostProfile,
  hostMeta,
  ...
}:
{
  imports = [
    ../modules
    ./files.nix
  ];

  # Common module automatically provides:
  # - nixpkgs.config.allowUnfree
  # - programs: home-manager, bash, gpg, gh
  # - services: gpg-agent
  # - .markdownlint.yaml file

  cyberfighter = {
    profile.enable = hostProfile;

    system = {
      inherit (hostMeta.system) username;
      homeDirectory = "/home/${hostMeta.system.username}";
      stateVersion = "24.11";
    };

    packages = {
      includeDev = true;
      extraPackages = [
        inputs.isd.packages.${pkgs.system}.default
      ];
    };

    features = {
      # Git, shell, editor, tools enabled by default
      git = {
        useSecretsForIdentity = true;
      };

      ssh = {
        enable = true;
        onepass = true;
      };

      shell = {
        fish.enable = true;
        starship.enable = true;
        zsh.enable = true;
      };

      editor = {
        vim.enable = true;
        neovim.enable = true;
        zed.enable = true;
        lazyvim.enable = true;
      };

      terminal = {
        enable = true;
        alacritty.enable = true;
        ghostty.enable = true;
      };

      desktop = {
        enable = true;
        bitwarden.enable = true;
      };

      tools = {
        btop.enable = true;
        lazygit.enable = true;
        tmux.enable = true;
        sesh.enable = true;
        zellij.enable = true;
        yazi.enable = true;
        carapace.enable = true;
        jujutsu = {
          enable = true;
          useSecretsForIdentity = true;
        };
      };
    };
  };

  # Additional program configurations

}
