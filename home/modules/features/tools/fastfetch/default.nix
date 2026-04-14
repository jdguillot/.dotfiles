{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.fastfetch;
in
{
  options.cyberfighter.features.tools.fastfetch = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "FastFetch - A fast and highly customizable system information tool";
    };
  };

  config = lib.mkIf cfg.enable {

    home.packages = with pkgs; [
      fastfetch
    ];

    xdg.configFile."fastfetch/config.jsonc".source = ./config.jsonc;
  };
}
