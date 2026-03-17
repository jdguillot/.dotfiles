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
      bitwarden-cli
      appimage-run
      xclip
      wl-clipboard
      xwayland
      age
      sops
      grc
      distrobox
      nmap
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
    opencode
    # copilot-cli
    github-copilot-cli
    copilot-language-server
  ];

  desktopPackages = with pkgs; [
    kitty
    wofi
    wineWowPackages.stable
    bitwarden-desktop
    _1password-gui
  ];

  virtualizationPackages = with pkgs; [
    qemu
    realvnc-vnc-viewer
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
  };
}
