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
    enable = lib.mkEnableOption "Desktop environment support";

    environment = lib.mkOption {
      type = lib.types.enum [ "plasma6" "plasma5" "gnome" "hyprland" "none" ];
      default = "plasma6";
      description = "Desktop environment to use";
    };

    displayManager = lib.mkOption {
      type = lib.types.enum [ "sddm" "gdm" "none" ];
      default = "sddm";
      description = "Display manager to use";
    };

    firefox = lib.mkEnableOption "Firefox browser";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.xserver = {
        enable = true;
        xkb = {
          layout = "us";
          variant = "";
        };
      };

      environment.systemPackages = with pkgs; [
        kitty
        wofi
      ];
    }

    (lib.mkIf (cfg.displayManager == "sddm") {
      services.displayManager.sddm.enable = true;
      security.pam.services.sddm.enableKwallet = lib.mkDefault true;
    })

    (lib.mkIf (cfg.displayManager == "gdm") {
      services.xserver.displayManager.gdm.enable = true;
    })

    (lib.mkIf (cfg.environment == "plasma6") {
      services.desktopManager.plasma6.enable = true;
      environment.systemPackages = with pkgs; [
        kdePackages.kate
      ];
    })

    (lib.mkIf (cfg.environment == "plasma5") {
      services.xserver.desktopManager.plasma5.enable = true;
    })

    (lib.mkIf (cfg.environment == "gnome") {
      services.xserver.desktopManager.gnome.enable = true;
    })

    (lib.mkIf (cfg.environment == "hyprland") {
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
      };
    })

    (lib.mkIf cfg.firefox {
      programs.firefox.enable = true;
    })
  ]);
}
