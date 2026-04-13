{
  config,
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
        inputs.deploy-rs-tui.packages.${stdenv.hostPlatform.system}.default
      ];
    };

    features = {
      # Git, shell, editor, and tools are enabled by default

      ssh = {
        enable = true;
        onepass = true;
        hosts = [
          "WorkOnlogic"
          "linode-work"
          "phoenix-router"
          "docs-server"
        ];
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
        mc.enable = true;
        tmux.enable = true;
        zellij.enable = true;
        carapace.enable = true;
        yazi.enable = true;
        direnv.enable = true;
      };
    };
  };

  programs.firefox.package = pkgs.wrapFirefox pkgs.firefox-unwrapped {
    extraPolicies = {
      ExtensionSettings = { };
    };
  };

  programs.git.includes = [
    { path = "${config.xdg.configHome}/git/identities/work.gitconfig"; }
  ];
}
