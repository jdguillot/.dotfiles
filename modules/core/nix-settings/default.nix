{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.nix;
in
{
  options.cyberfighter.nix = {
    enableDevenv = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable devenv cachix substituter";
    };

    trustedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "root" ];
      description = "List of trusted Nix users";
    };

    keepOutputs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Keep build outputs";
    };

    keepDerivations = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Keep derivations";
    };

    extraOptions = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra options to append to nix.conf";
    };
  };

  config = {
    nix.extraOptions =
      let
        devenvConfig = lib.optionalString cfg.enableDevenv ''
          extra-substituters = https://devenv.cachix.org
          extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
        '';
        trustedUsersConfig = ''
          trusted-users = ${lib.concatStringsSep " " cfg.trustedUsers}
        '';
        outputConfig = ''
          keep-outputs = ${if cfg.keepOutputs then "true" else "false"}
          keep-derivations = ${if cfg.keepDerivations then "true" else "false"}
        '';
      in
      lib.concatStringsSep "\n" [
        devenvConfig
        trustedUsersConfig
        outputConfig
        cfg.extraOptions
      ];
  };
}
