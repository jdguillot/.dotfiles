{
  config,
  lib,
  pkgs,
  inputs,
  hostProfile,
  hostMeta,
  ...
}:
{
  imports = [
    ../modules
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

  cyberfighter = {
    profile.enable = hostProfile;

    system = {
      username = hostMeta.system.username;
      homeDirectory = "/home/${hostMeta.system.username}";
      stateVersion = "24.11";
    };

    packages = {
      includeDev = true;
      extraPackages = with pkgs; [
        avahi
        geckodriver
        inputs.isd.packages.${pkgs.system}.default
      ];
    };

    features = {
      # Git, shell, editor, and tools are enabled by default
      git = {
        userName = "jonathan-guillot_emcor";
        userEmail = "jonathan_guillot@emcor.net";
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
        neovim.enable = true;
      };

      terminal = {
        zellij.enable = true;
      };

      desktop = {
        firefox = {
          enable = true;
          package = pkgs.firefox;
        };
      };
    };
  };

  # User-specific configurations
  home = {
    file = {
      ".ssh/config".source = ../../secrets/.ssh_config_work;
      ".config/nix/nix.conf".source = ../../secrets/nix.conf;
    };

    sessionVariables = {
      GITHUB_USERNAME = "jonathan-guillot_emcor";
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

  programs.firefox.package = pkgs.wrapFirefox pkgs.firefox-unwrapped {
    extraPolicies = {
      ExtensionSettings = { };
    };
  };
}
