{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.rofi;
in
{
  options.cyberfighter.features.rofi = {
    enable = lib.mkEnableOption "Rofi application launcher";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      rofi
    ];

    xdg.configFile."rofi/config/".source = ./rofi-config;

  };
}
