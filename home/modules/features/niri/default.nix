{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.niri;
in
{
  options.cyberfighter.features.niri = {
    enable = lib.mkEnableOption "Niri compositor config";
  };

  config = lib.mkIf cfg.enable {
    # niri the compositor is installed at the NixOS level (desktop.environment
    # = "niri"); this module just deploys the user config.
    xdg.configFile."niri/config.kdl".source = ./config.kdl;
  };
}
