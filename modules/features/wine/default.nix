{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.wine;
in
{
  options.cyberfighter.features.wine = {
    enable = lib.mkEnableOption "Wine Support for Windows Applications";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # ...

      # support both 32-bit and 64-bit applications
      # wineWow64Packages.stable

      # wine-staging (version with experimental features)
      wineWow64Packages.staging

      # winetricks (all versions)
      winetricks

      # native wayland support (unstable)
      # wineWow64Packages.waylandFull
    ];
  };
}
