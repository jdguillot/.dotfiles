{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.editor.micro;
in
{
  options.cyberfighter.features.editor.micro = {
    enable = lib.mkEnableOption "Micro terminal-based text editor";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ micro ];
  };
}
