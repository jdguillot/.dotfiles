{
  config,
  lib,
  inputs,
  hostMeta,
  ...
}:

let
  cfg = config.cyberfighter.features.noctalia;
  inherit (hostMeta.system) username;
in
{
  options.cyberfighter.features.noctalia = {
    enable = lib.mkEnableOption "Noctalia Shell Config";
  };

  config = lib.mkIf cfg.enable {
    # configure options
    programs.noctalia-shell = {
      enable = true;
    };
    # xdg.configFile."noctalia".source = ./configs;
  };
}
