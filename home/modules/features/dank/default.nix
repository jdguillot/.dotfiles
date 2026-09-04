{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.cyberfighter.features.dank;
  dmsPkgs = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.cyberfighter.features.dank = {
    enable = lib.mkEnableOption "DankMaterialShell and its desktop suite";

    extraQtPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.kdePackages.qtwebsockets ]";
      description = ''
        Qt/QML modules that DMS plugins (bar widgets) need at runtime.
        Installing them into the profile is not enough — Quickshell only
        sees QML modules on the import path the `dms` wrapper pins, so these
        are folded in through upstream's `extraQtPackages` override. That
        rebuilds dms-shell locally, so the list stays empty by default.
      '';
    };

    apps = {
      monitor =
        lib.mkEnableOption "dgop, the system monitor behind DMS's CPU/memory widgets and process list"
        // {
          default = true;
        };
      search = lib.mkEnableOption "dsearch, the indexed filesystem search daemon";
      calendar = lib.mkEnableOption "dcal (DankCalendar), the calendar app and its CalDAV sync";
    };
  };

  config = lib.mkIf cfg.enable {
    # niri spawns dms from its shell layer (shells/dank.kdl), so the systemd
    # unit stays off — enabling both double-spawns the shell.
    programs.dank-material-shell = {
      enable = true;
      systemd.enable = false;
      enableSystemMonitoring = cfg.apps.monitor; # gates the Mod+M binding
      enableDynamicTheming = true; # matugen wallpaper theming
      package = lib.mkIf (cfg.extraQtPackages != [ ]) (
        dmsPkgs.dms-shell.override { inherit (cfg) extraQtPackages; }
      );
    };

    # dgop is not pulled in by the DMS module itself, but the bar's cpuUsage
    # and memUsage widgets and the Mod+M process list all shell out to it.
    home.packages =
      lib.optional cfg.apps.monitor
        inputs.dgop.packages.${pkgs.stdenv.hostPlatform.system}.dgop;

    programs.dsearch.enable = cfg.apps.search;

    programs.dank-calendar = lib.mkIf cfg.apps.calendar {
      enable = true;
      # The systemd unit only exists to pop reminders; the app runs on demand.
      systemd.enable = true;
    };
  };
}
