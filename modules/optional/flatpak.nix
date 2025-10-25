{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.flatpak;
in
{

  config = lib.mkMerge [
    (lib.mkIf cfg.desktop {
      services.flatpak.packages = [
        "com.github.tchx84.Flatseal"
        "org.libreoffice.LibreOffice"
        "org.videolan.VLC"
      ];
    })
    (lib.mkIf cfg.browsers {
      services.flatpak.packages = [
        "io.github.zen_browser.zen"
        "org.chromium.Chromium"
      ];
    })
    (lib.mkIf cfg.cad {
      services.flatpak.packages = [
        "org.openscad.OpenSCAD"
        "org.freecadweb.FreeCAD"
      ];
    })
    (lib.mkIf cfg.electronics {
      services.flatpak.packages = [
        "cc.arduino.arduinoide"
        "org.fritzing.Fritzing"
      ];
    })
  ];
}
