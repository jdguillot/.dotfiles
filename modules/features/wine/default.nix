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
      # wineWowPackages.stable

      # wine-staging (version with experimental features)
      wineWowPackages.staging

      # winetricks (all versions)
      winetricks

      # native wayland support (unstable)
      # wineWowPackages.waylandFull
    ];
  };
}
