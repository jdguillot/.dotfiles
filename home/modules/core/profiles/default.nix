{ config, lib, osConfig ? null, ... }:

{
  options.cyberfighter.profile = {
    enable = lib.mkOption {
      type = lib.types.enum [ "desktop" "minimal" "wsl" ];
      default = 
        if osConfig != null && osConfig ? cyberfighter && osConfig.cyberfighter ? profile
        then osConfig.cyberfighter.profile.enable
        else "minimal";
      description = "Profile to use for home configuration (defaults to host profile if available)";
    };
  };
}