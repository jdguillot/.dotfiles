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

    # kdeconnectd needs a display to talk to; on a seat that has none -- a
    # gamescope Steam session, say -- it aborts at startup, and graphical-
    # session.target is reachable there all the same (Sunshine's unit alone
    # pulls it in). These are triggering conditions, so any one of them
    # admits the unit: niri and Plasma both push their session environment
    # into the user manager, while the gamescope seat imports nothing. A
    # skipped condition is not a failure, so nothing retries.
    systemd.user.services.kdeconnect.Unit.ConditionEnvironment = [
      "|WAYLAND_DISPLAY"
      "|DISPLAY"
      "|XDG_CURRENT_DESKTOP"
    ];

    # Discovery and pairing need TCP+UDP 1714-1764 reachable, which a
    # standalone home configuration cannot arrange: the matching system
    # module (cyberfighter.features.kdeconnect) opens them on the host.
  };
}
