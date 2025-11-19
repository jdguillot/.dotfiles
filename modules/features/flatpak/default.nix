{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.flatpak;
  inherit (config.cyberfighter) features;

  browserPackages = [
    "io.github.zen_browser.zen"
    "org.chromium.Chromium"
  ];

  cadPackages = [
    "org.openscad.OpenSCAD"
    "org.freecadweb.FreeCAD"
  ];

  electronicsPackages = [
    "cc.arduino.arduinoide"
    "org.fritzing.Fritzing"
  ];

  gamingPackages = [
    "com.moonlight_stream.Moonlight"
  ];

  allPackages =
    (lib.optionals cfg.browsers browserPackages)
    ++ (lib.optionals cfg.cad cadPackages)
    ++ (lib.optionals cfg.electronics electronicsPackages)
    ++ (lib.optionals (features.gaming.enable && cfg.enable) gamingPackages)
    ++ cfg.extraPackages;
in
{
  options.cyberfighter.features.flatpak = {
    enable = lib.mkEnableOption "Flatpak support and Flathub";

    browsers = lib.mkEnableOption "Browser packages (Zen Browser, Chromium)";

    cad = lib.mkEnableOption "CAD software (OpenSCAD, FreeCAD)";

    electronics = lib.mkEnableOption "Electronics software (Arduino IDE, Fritzing)";

    gaming = lib.mkEnableOption "Gaming packages (Moonlight)";

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional Flatpak packages to install";
      example = [
        "com.moonlight_stream.Moonlight"
        "us.zoom.Zoom"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.flatpak = {
      enable = true;
      packages = allPackages;
      update.auto = {
        enable = true;
        onCalendar = "weekly";
      };
    };

    systemd.services.flatpak-repo = {
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.flatpak ];
      script = ''
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      '';
    };
  };
}
