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

    garbageCollect = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Setup Automatic Garbage Collect once a week";
    };
  };

  config = lib.mkMerge [
    {
      nix.settings = lib.mkMerge [
        (lib.mkIf cfg.enableDevenv {
          substituters = [
            "https://devenv.cachix.org"
            "https://jdguillot.cachix.org"
          ];
          trusted-public-keys = [
            "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
            "jdguillot.cachix.org-1:2blGoWA4jRj/xDiez3FqPE5S/RBNtD8uJUCz7weHNcs="
          ];
        })
        {
          trusted-users = cfg.trustedUsers;
          keep-outputs = cfg.keepOutputs;
          keep-derivations = cfg.keepDerivations;
        }
      ];

      # If you have extra options as a string, use extraOptions
      nix.extraOptions = cfg.extraOptions;
    }
    (lib.mkIf cfg.garbageCollect {
      nix = {
        settings.auto-optimise-store = true;
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 30d";
        };
      };
    })
  ];
}
