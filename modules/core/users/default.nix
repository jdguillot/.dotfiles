{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.system;
in
{
  options.cyberfighter.system.extraGroups = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Extra groups for the primary user";
    example = [ "docker" "libvirtd" ];
  };

  config = {
    users.users.${cfg.username} = {
      extraGroups = [ "networkmanager" "wheel" ] ++ cfg.extraGroups;
    };
  };
}
