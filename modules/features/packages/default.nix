{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.packages;

  basePackages = with pkgs; [
    htop
    btop
    vim
    wget
    cifs-utils
    lshw
    pciutils
    git
    gh
    lazyjj
    bitwarden-cli
    appimage-run
    xclip
    opencode
    age
    sops
    grc
    distrobox
  ];

  devPackages = with pkgs; [
    nodejs
    nil
    esphome
    platformio
    gcc
  ];

  desktopPackages = with pkgs; [
    kitty
    wofi
    wineWowPackages.stable
    bitwarden-desktop
  ];

  allPackages =
    (lib.optionals cfg.includeBase basePackages)
    ++ (lib.optionals cfg.includeDev devPackages)
    ++ (lib.optionals cfg.includeDesktop desktopPackages)
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
