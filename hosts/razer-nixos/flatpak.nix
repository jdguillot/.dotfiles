# home.nix
{ lib, ... }: {

  # nix-flatpak setup
  services.flatpak.enable = true;

  services.flatpak.remotes = lib.mkOptionDefault [{
    name = "flathub-beta";
    location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
  }];

  services.flatpak.update.auto.enable = false;
  services.flatpak.uninstallUnmanaged = false;
  services.flatpak.packages = [
    #{ appId = "com.brave.Browser"; origin = "flathub"; }
    "com.github.tchx84.Flatseal"
    "io.github.zen_browser.zen"
    "org.openscad.OpenSCAD"
    "org.freecadweb.FreeCAD"
    "org.libreoffice.LibreOffice"
    "org.videolan.VLC"
    "cc.arduino.arduinoide"
    "org.fritzing.Fritzing"
    "org.chromium.Chromium"
  ];

}