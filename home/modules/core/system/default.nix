{ config, lib, pkgs, ... }:

let
  cfg = config.cyberfighter.system;
in
{
  options.cyberfighter.system = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "cyberfighter";
      description = "Username for the home environment";
    };

    homeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.username}";
      description = "Home directory path";
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      default = "24.11";
      description = "Home Manager state version";
    };
  };

  config = {
    home = {
      inherit (cfg) username homeDirectory;
      stateVersion = lib.mkDefault cfg.stateVersion;
    };
  };
}