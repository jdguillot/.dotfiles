{ config, lib, hostMeta, ... }:

let
  cfg = config.cyberfighter.system;
in
{
  # username/stateVersion default from the host's entry in
  # hosts/default.nix (same pattern as modules/core/traits).
  options.cyberfighter.system = {
    username = lib.mkOption {
      type = lib.types.str;
      default = hostMeta.system.username;
      defaultText = lib.literalExpression "hostMeta.system.username";
      description = "Username for the home environment";
    };

    homeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.username}";
      description = "Home directory path";
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      default = hostMeta.system.stateVersion;
      defaultText = lib.literalExpression "hostMeta.system.stateVersion";
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
