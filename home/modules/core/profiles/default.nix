{ lib, ... }:

{
  options.cyberfighter.profile = {
    enable = lib.mkOption {
      type = lib.types.enum [ "desktop" "minimal" "wsl" ];
      default = "minimal";
      description = "Profile to use for home configuration";
    };
  };
}