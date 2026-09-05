{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.kdeconnect;
in
{
  options.cyberfighter.features.kdeconnect = {
    enable = lib.mkEnableOption "KDE Connect phone/desktop pairing";

    package = lib.mkPackageOption pkgs.kdePackages "kdeconnect-kde" {
      pkgsText = "pkgs.kdePackages";
    };

    indicator = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run kdeconnect-indicator, the standalone tray applet. Off by
        default: the DMS dankKDEConnect plugin already surfaces devices in
        the bar, so the applet would only add a second icon. Needs a
        StatusNotifier host, since its unit requires tray.target.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # kdeconnectd is normally D-Bus activated; the Home Manager module runs
    # it as a graphical-session.target unit instead so it is up before the
    # phone tries to reach it.
    services.kdeconnect = {
      enable = true;
      inherit (cfg) package indicator;
    };

    # Discovery and pairing need TCP+UDP 1714-1764 reachable, which a
    # standalone home configuration cannot arrange: the matching system
    # module (cyberfighter.features.kdeconnect) opens them on the host.
  };
}
