{
  config,
  lib,
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

      # Personal agent as this user; the dotenv is a system sops secret
      # owned by this user (hosts/ryzn-server/configuration.nix).
      hermes = lib.mkIf (hostMeta.system.hostname == "ryzn-server") {
        enable = true;
        configFile = ../../hosts/ryzn-server/hermes-config.yaml;
        environmentFiles = [ "/run/secrets/hermes-env" ];
      };

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

      # Theming writes dconf over the session bus, which minimal hosts
      # (headless servers) do not run; the activation fails outright there.
      desktop = {
        enable = hostMeta.profile != "minimal";
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

  # Saves from every library land in ~/ludusavi-backup ahead of btrbk's
  # midnight /home snapshot.
  services.ludusavi = lib.mkIf (hostMeta.system.hostname == "ryzn-server") {
    enable = true;
    configFile = ./ludusavi/config.yaml;
    # The module asserts settings and configFile are not both set.
    settings = { };
    frequency = "*-*-* 23:30:00";
  };
  # The GUI writes its own config.yaml there; this file is a port of it.
  xdg.configFile."ludusavi/config.yaml" = lib.mkIf (hostMeta.system.hostname == "ryzn-server") {
    force = true;
  };

  # A btrbk snapshot stops at a nested subvolume, so game installs live in
  # their own and stay out of the /home snapshots. Creates them when absent;
  # an existing plain directory is only reported (conversion needs Steam shut).
  home.activation.gameSubvolumes = lib.mkIf (hostMeta.system.hostname == "ryzn-server") (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for p in \
        "$HOME/.local/share/Steam/steamapps/common" \
        "$HOME/.local/share/Steam/steamapps/shadercache" \
        "$HOME/.local/share/Steam/steamapps/downloading" \
        "$HOME/Games/rsi-launcher/drive_c/Program Files/Roberts Space Industries/StarCitizen"; do
        [ -d "$(dirname "$p")" ] || continue
        if [ ! -e "$p" ]; then
          run ${pkgs.btrfs-progs}/bin/btrfs subvolume create "$p"
        elif [ "$(stat -c %i "$p")" != 256 ]; then
          # Inode 256 is the root of a btrfs subvolume.
          warnEcho "$p is a plain directory, so /home snapshots include it"
        fi
      done
    ''
  );
}
