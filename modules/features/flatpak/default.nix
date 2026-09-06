{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.flatpak;
  inherit (config.cyberfighter) features;

  desktopPackages = [
    "com.github.tchx84.Flatseal"
    "org.libreoffice.LibreOffice"
    "org.videolan.VLC"
    "com.moonlight_stream.Moonlight"
    "io.github.flattool.Warehouse"
  ];

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
    "com.steamgriddb.SGDBoop"
    "net.lutris.Lutris"
  ];

  allPackages =
    (lib.optionals cfg.desktop desktopPackages)
    ++ (lib.optionals cfg.browsers browserPackages)
    ++ (lib.optionals cfg.cad cadPackages)
    ++ (lib.optionals cfg.electronics electronicsPackages)
    ++ (lib.optionals cfg.gaming gamingPackages)
    ++ cfg.extraPackages;
  # Dedupe: a host may list a flatpak explicitly that a preset also adds.
  flatpakPackages = lib.unique allPackages;
in
{
  options.cyberfighter.features.flatpak = {
    enable = lib.mkEnableOption "Flatpak support and Flathub";

    desktop = lib.mkOption {
      type = lib.types.bool;
      default = config.cyberfighter.packages.includeDesktop;
      defaultText = lib.literalExpression "config.cyberfighter.packages.includeDesktop";
      description = "Desktop staples (Flatseal, LibreOffice, VLC, Moonlight, Warehouse). Defaults to the host's desktop package bundle.";
    };

    browsers = lib.mkEnableOption "Browser packages (Zen Browser, Chromium)";

    cad = lib.mkEnableOption "CAD software (OpenSCAD, FreeCAD)";

    electronics = lib.mkEnableOption "Electronics software (Arduino IDE, Fritzing)";

    gaming = lib.mkOption {
      type = lib.types.bool;
      default = features.gaming.enable;
      defaultText = lib.literalExpression "config.cyberfighter.features.gaming.enable";
      description = "Gaming packages (SGDBoop, Lutris). Defaults to the host's gaming feature.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Host-specific Flatpak packages, concatenated with whatever the category toggles above select";
      example = [
        "md.obsidian.Obsidian"
        "us.zoom.Zoom"
      ];
    };

    unprivilegedRuntimeInstall = lib.mkEnableOption ''
      installing Flatpak runtimes from an active local session without an
      admin password, so a desktop updater running as a non-wheel user can
      finish updates that pull a new runtime branch
    '';
  };

  config = lib.mkIf cfg.enable {
    services.flatpak = {
      enable = true;
      packages = flatpakPackages;
      update.auto = {
        enable = true;
        onCalendar = "weekly";
      };
    };

    # Flatpak's policy already lets an active local session update apps and
    # runtimes unattended, but installing one is auth_admin_keep -- so a
    # routine update that pulls a NEW runtime branch (org.kde.Platform 6.10
    # -> 6.11) stalls on a password a non-wheel user cannot supply. Only
    # runtime-install is granted; installing apps, uninstalling and
    # reconfiguring remotes stay behind the prompt.
    security.polkit.extraConfig = lib.mkIf cfg.unprivilegedRuntimeInstall ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.Flatpak.runtime-install" &&
            subject.local && subject.active) {
          return polkit.Result.YES;
        }
      });
    '';

    systemd.services.flatpak-repo = {
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.flatpak ];
      script = ''
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      '';
    };
  };
}
