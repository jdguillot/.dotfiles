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
    ./variables.nix
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
      extraPackages = with pkgs; [
        inputs.isd.packages.${pkgs.system}.default
      ];
    };

    features = {
      # Git, shell, editor, tools enabled by default
      git = {
        userName = "jdguillot";
        userEmail = "jdguillot@outlook.com";
      };

      shell = {
        fish.enable = true;
        starship.enable = true;
        zsh.enable = true;
      };

      editor = {
        vim.enable = true;
        neovim.enable = true;
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
        zellij.enable = true;
        carapace.enable = true;
        jujutsu = {
          enable = true;
          userName = "Jonathan Guillot";
          userEmail = "jdguillot@outlook.com";
        };
      };
    };
  };

  # Additional program configurations

}
