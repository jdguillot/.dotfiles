{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.gum;
in
{
  options.cyberfighter.features.tools.gum = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Gum - A tool for glamorous shell scripts";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      gum
    ];
  };
}
