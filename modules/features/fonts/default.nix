{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.fonts;
in
{
  options.cyberfighter.features.fonts = {
    enable = lib.mkEnableOption "Common programming fonts";
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = with pkgs; [
      fira-code
      fira-mono
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
    ];
  };
}
