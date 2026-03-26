{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.vscode;
in
{
  options.cyberfighter.features.vscode = {
    enable = lib.mkEnableOption "Visual Studio Code";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ vscode ];
  };
}
