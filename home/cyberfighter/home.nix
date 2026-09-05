{
  config,
  pkgs,
  inputs,
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
    packages = {
      extraPackages = with pkgs; [
        inputs.deptui.packages.${stdenv.hostPlatform.system}.default
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
          "ryzn-server"
        ];
      };

      noctalia.enable = true;

      # Phone pairing: notification mirroring, clipboard sync, file
      # transfer. Desktops only, and each host has to open 1714-1764
      # itself (cyberfighter.features.kdeconnect on the system side).
      kdeconnect.enable = hostMeta.profile == "desktop";

      # DankMaterialShell and the rest of the dank suite (dgop, dsearch,
      # dcal). Desktops only — it is a second Quickshell closure.
      dank = {
        enable = hostMeta.profile == "desktop";
        # QML modules DMS plugins need on the shell's import path.
        extraQtPackages = [ pkgs.kdePackages.qtwebsockets ];
        apps = {
          search = true;
          calendar = true;
        };
      };

      niri = {
        enable = true;
        style = "rounded"; # "minimal" | "rounded" | "showcase"
        # Both shells on desktops, so the greeter offers both and
        # `niri-shell <name>` can swap live; minimal hosts skip the second
        # Quickshell closure.
        shells =
          if hostMeta.profile == "desktop" then
            [
              "noctalia"
              "dank"
            ]
          else
            [ "noctalia" ];
      };

      shell = {
        fish.enable = true;
        starship.enable = true;
        zsh.enable = true;

        # trash-put fails across ryzn-server's subvolumes; btrbk covers it.
        trash.enable = hostMeta.system.hostname != "ryzn-server";
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
        ghostty.settings.fullscreen = "false";
      };

      desktop = {
        enable = true;
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
        # github-pat is only decryptable by the razer-nixos user key;
        # elsewhere the failed decrypt would take the whole user unit down.
        mcp.use.github = hostMeta.system.hostname == "razer-nixos";

        # Same recipient constraint: the ollama/ryzn URLs and credentials
        # come from secrets/secrets.yaml.
        opencode.remoteProvider.enable = hostMeta.system.hostname == "razer-nixos";
        crush.remoteProvider.enable = hostMeta.system.hostname == "razer-nixos";
        tmuxai.remoteProvider.enable = hostMeta.system.hostname == "razer-nixos";
      };
    };
  };

  # Additional program configurations

  programs.git.includes = [
    { path = "${config.xdg.configHome}/git/identities/personal.gitconfig"; }
  ];
}
