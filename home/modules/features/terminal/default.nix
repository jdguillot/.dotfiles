{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.terminal;
in
{
  imports = [
    ./alacritty/default.nix
    ./ghostty/default.nix
  ];

  options.cyberfighter.features.terminal = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Terminal configuration";
    };

  };

}
