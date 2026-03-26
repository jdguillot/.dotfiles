{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.mc;
in
{
  options.cyberfighter.features.tools.mc = {
    enable = lib.mkEnableOption "Midnight Commander";
  };

  config = lib.mkIf cfg.enable {
    programs.mc = {
      enable = true;
      settings = {
        Midnight-Commander = {
          skin = "catppuccin";
        };
      };
    };

    xdg.dataFile."mc/skins/catppuccin.ini".source = ./catppuccin.ini;

  };
}
