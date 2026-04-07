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

    optimize = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatic Store Optimization";
    };
  };

  config = lib.mkMerge [
    {
      sops.secrets."github-pat" = { };
      sops.templates."access-tokens".content = ''
        access-tokens = github.com=${config.sops.placeholder."github-pat"}
      '';
      nix.settings = lib.mkMerge [
        (lib.mkIf cfg.enableDevenv {
          substituters = [
            "https://devenv.cachix.org"
            "https://jdguillot.cachix.org"
            "https://nix-community.cachix.org"
            "https://niri.cachix.org"
            "https://noctalia.cachix.org"
            "https://cache.saumon.network/proxmox-nixos"
          ];
          trusted-public-keys = [
            "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
            "jdguillot.cachix.org-1:2blGoWA4jRj/xDiez3FqPE5S/RBNtD8uJUCz7weHNcs="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
            "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
            "proxmox-nixos:D9RYSWpQQC/msZUWphOY2I5RLH5Dd6yQcaHIuug7dWM="
          ];
        })
        {
          trusted-users = cfg.trustedUsers;
          keep-outputs = cfg.keepOutputs;
          keep-derivations = cfg.keepDerivations;

          download-buffer-size = 524288000;
        }
      ];
      nix.extraOptions = ''
        !include ${config.sops.templates."access-tokens".path}
      ''
      +
        # If you have extra options as a string, use extraOptions
        cfg.extraOptions;

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
    (lib.mkIf cfg.optimize {
      nix.optimise = {
        automatic = true;
      };
    })
  ];
}
