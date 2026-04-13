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
        inputs.deploy-rs-tui.packages.${stdenv.hostPlatform.system}.default
      ];
    };

    features = {
      # Git, shell, editor, tools enabled by default

      ssh = {
        enable = true;
        onepass = true;
        hosts = [
          "thkpd-pve1"
          "simple-vm"
          "sys-galp-nix"
          "homeassistant"
          "frigate"
          "vm-docker-pri"
          "docker1"
          "docker2"
          "docker3"
          "docker4"
          "opnsense"
          "docker-pri"
          "r610-pve1"
          "r610-pve2"
          "zb832-pve1"
          "zb832-pve2"
          "zb432-pve1"
          "truenas"
          "synlgy-ds918"
          "vm-gameserver-nix"
        ];
      };

      noctalia.enable = true;

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
        ghostty.fullscreen = false;
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
        yazi.enable = true;
        carapace.enable = true;
        rofi.enable = true;
        jujutsu = {
          enable = true;
          useSecretsForIdentity = true;
        };
      };
    };
  };

  # Additional program configurations

  programs.git.includes = [
    { path = "${config.xdg.configHome}/git/identities/personal.gitconfig"; }
  ];
}
