{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.packages;

  basePackages =
    with pkgs;
    [
      htop
      btop
      vim
      wget
      cifs-utils
      lshw
      pciutils
      git
      gh
      diffnav
      delta
      lazyjj
      appimage-run
      xclip
      wl-clipboard
      xwayland
      age
      sops
      grc
      distrobox
      nmap
      parted
      # Troubleshooting toolkit: HTTP/SSL, DNS, TCP, packet capture, tracing
      apacheHttpd # htpasswd; nixpkgs has no apache2-utils (Debian name)
      openssl
      curl
      bind # dig/host/nslookup
      netcat
      socat
      tcpdump
      strace
      trash-cli
      isd
      usbutils
    ]
    ++ (if config.cyberfighter.profile.enable != "wsl" then [ pkgs._1password-cli ] else [ ]);

  devPackages = with pkgs; [
    nodejs
    pnpm
    nil
    esphome
    platformio
    gcc
    vscode-json-languageserver
    imagemagick
    ghostscript
    mermaid-cli
    ast-grep
    cargo
    github-copilot-cli
    copilot-language-server
    deploy-rs
    npins
    # Bare `mcp-nixos` must resolve for per-project MCP configs
    # (.mcp.json / opencode.json) that scope it to nix-heavy repos.
    mcp-nixos
    claude-code
    opencode
    nixd
    yaml-language-server
    lua-language-server
    bash-language-server
  ];

  desktopPackages = with pkgs; [
    kitty
    wofi
    wineWow64Packages.stable
    _1password-gui
  ];

  virtualizationPackages = with pkgs; [
    qemu
    nemu
    virt-viewer
    quickemu
    quickgui
  ];

  allPackages =
    (lib.optionals cfg.includeBase basePackages)
    ++ (lib.optionals cfg.includeDev devPackages)
    ++ (lib.optionals cfg.includeDesktop desktopPackages)
    ++ (lib.optionals cfg.includeVirt virtualizationPackages)
    ++ cfg.extraPackages;
in
{
  options.cyberfighter.packages = {
    includeBase = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include base system packages (git, vim, htop, etc.)";
    };

    includeDev = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include development packages (nodejs, platformio, etc.)";
    };

    includeDesktop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include desktop packages (kitty, wofi, etc.)";
    };

    includeVirt = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include Virtualization Client Software";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to install system-wide";
      example = lib.literalExpression "[ pkgs.htop pkgs.neofetch ]";
    };
  };

  config = lib.mkIf cfg.includeBase {
    environment.systemPackages = allPackages;

    # Keeps the trash cans bounded; trash-empty walks every mounted volume,
    # not just ~/.local/share/Trash.
    systemd.services.trash-empty = {
      description = "Empty trash items older than 30 days";
      serviceConfig = {
        Type = "oneshot";
        User = config.cyberfighter.system.username;
        ExecStart = "${pkgs.trash-cli}/bin/trash-empty 30";
      };
    };

    # A timer, not wantedBy = multi-user.target -- as a boot-only oneshot the
    # sweep never ran on hosts that stay up for months.
    systemd.timers.trash-empty = {
      description = "Daily sweep of trash items older than 30 days";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
  };
}
