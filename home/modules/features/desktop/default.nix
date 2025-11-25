{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.desktop;
in
{
  options.cyberfighter.features.desktop = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Desktop applications";
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

      home.packages =
        with pkgs;
        [
          bottles
          super-productivity
          vivaldi
          qbittorrent
          (catppuccin-kde.override {
            flavour = [ "frappe" ];
            accents = [ "blue" ];
            winDecStyles = [ "modern" ];
          })
        ]
        ++ cfg.extraPackages;
    })
  ];
}
