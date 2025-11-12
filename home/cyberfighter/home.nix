{
  config,
  lib,
  pkgs,
  inputs,
  osConfig,
  ...
}:
{
  imports = [
    ../modules
    ../features/cli/jujutsu.nix
    ../features/cli/lazyvim/lazyvim.nix
    ../features/cli/btop/btop.nix
    ../features/cli/lazygit/default.nix
    ../features/cli/starship/default.nix
    ../features/cli/tmux/default.nix
    ../features/cli/carapace/default.nix
    ../features/cli/zsh/default.nix
    ../features/desktop/alacritty/default.nix
    ../features/desktop/ghostty/default.nix
    ../features/desktop/bitwarden.nix
  ];

  # Common module automatically provides:
  # - nixpkgs.config.allowUnfree
  # - programs: home-manager, bash, gpg, gh
  # - services: gpg-agent
  # - .markdownlint.yaml file

  cyberfighter = {
    # Profile and desktop features auto-inherit from host configuration

    system = {
      username = "cyberfighter";
      homeDirectory = "/home/cyberfighter";
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
        fish = {
          enable = true;
          plugins = [
            {
              name = "grc";
              src = pkgs.fishPlugins.grc.src;
            }
            {
              name = "done";
              src = pkgs.fishPlugins.done;
            }
            {
              name = "fzf-fish";
              src = pkgs.fishPlugins.fzf-fish;
            }
            {
              name = "forgit";
              src = pkgs.fishPlugins.forgit;
            }
          ];
        };
        starship.enable = true;
      };

      editor = {
        vim.enable = true;
        neovim.enable = true;
      };

      terminal = {
        zellij.enable = true;
      };

      # Desktop and terminal features auto-enable based on host
    };
  };

  # User-specific configurations
  # User-specific configurations
  home = {
    file = {
      ".ssh/config".source = ../../secrets/.ssh_config_work;
      ".config/nix/nix.conf".source = ../../secrets/nix.conf;
    };

    sessionVariables = {
      GITHUB_USERNAME = "jdguillot";
    };
  };

  # Additional program configurations
  programs.zellij = {
    enable = true;
    settings = {
      theme = "nord";
      font = "FiraCode Nerd Font";
      keybinds = {
        normal = { };
        pane = { };
      };
    };
  };
}
