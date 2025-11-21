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
        fish.enable = true;
        starship.enable = true;
        zsh.enable = true;
      };

      editor = {
        neovim.enable = true;
        lazyvim.enable = true;
      };

      desktop = {
        firefox = {
          enable = true;
          package = pkgs.firefox;
        };
      };

      tools = {
        btop.enable = true;
        lazygit.enable = true;
        tmux.enable = true;
        zellij.enable = true;
        carapace.enable = true;
        yazi.enable = true;
      };
    };
  };

  programs.firefox.package = pkgs.wrapFirefox pkgs.firefox-unwrapped {
    extraPolicies = {
      ExtensionSettings = { };
    };
  };
}
