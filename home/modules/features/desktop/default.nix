{ config, lib, pkgs, osConfig ? null, ... }:

let
  cfg = config.cyberfighter.features.desktop;
  # Check if host has desktop environment enabled
  hostHasDesktop = osConfig != null 
    && osConfig ? cyberfighter 
    && osConfig.cyberfighter ? features 
    && osConfig.cyberfighter.features ? desktop
    && osConfig.cyberfighter.features.desktop.enable or false;
in
{
  options.cyberfighter.features.desktop = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = hostHasDesktop;
      description = "Desktop applications (auto-enabled if host has desktop environment)";
    };

    firefox = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Firefox browser";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.firefox;
        description = "Firefox package to use";
      };
    };

    bitwarden = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Bitwarden password manager";
      };
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra desktop packages to install";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.firefox.enable) {
      programs.firefox = {
        enable = true;
        package = lib.mkDefault cfg.firefox.package;
      };
    })

    (lib.mkIf (cfg.enable && cfg.bitwarden.enable) {
      home.packages = with pkgs; [ bitwarden-desktop ];
    })

    (lib.mkIf cfg.enable {
      nixpkgs.config.allowUnfree = true;
      
      home.packages = with pkgs; [
        bottles
        super-productivity
        vivaldi
        qbittorrent
      ] ++ cfg.extraPackages;
    })
  ];
}