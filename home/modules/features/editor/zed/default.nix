{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.editor.zed;
in
{
  options.cyberfighter.features.editor.zed = {
    enable = lib.mkEnableOption "Zed modern code editor";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ zed-editor ];
  };
}
