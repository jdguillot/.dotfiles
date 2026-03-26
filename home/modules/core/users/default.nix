{ config, lib, ... }:

{
  options.cyberfighter.users = {
    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra groups for the user";
    };
  };
}