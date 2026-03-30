{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.rofi;
in
{
  options.cyberfighter.features.tools.rofi = {
    enable = lib.mkEnableOption "Rofi application launcher";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      rofi
    ];

    xdg.configFile."rofi/".source = ./rofi-config;

  };
}
