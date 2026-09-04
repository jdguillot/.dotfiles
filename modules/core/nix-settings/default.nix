{
  config,
  lib,
  pkgs,
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
      default = false;
      description = ''
        `keep-outputs`. Pins the build *outputs* of every .drv reachable from a
        GC root -- source tarballs, cargo lockfiles, compiler intermediates,
        the entire build graph of every live generation.

        Off by default because it defeats garbage collection on a machine that
        rebuilds often: razer-nixos reached 99% of a 217G disk with the weekly
        GC running and succeeding, because what it was allowed to delete was a
        rounding error next to what this kept alive. Turning it off freed 18G
        on the next collection.

        Turn it on for a machine that spends its time in `nix develop` and
        wants shell inputs to survive a GC, and pay for it with disk.
      '';
    };

    keepDerivations = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        `keep-derivations`. Keeps the .drv for every live output. Cheap -- a
        .drv is a small file, unlike the outputs `keepOutputs` retains -- and
        it is what lets you inspect how a live path was built.
      '';
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
      sops.templates."access-tokens" = {
        content = ''
          access-tokens = github.com=${config.sops.placeholder."github-pat"}
        '';
        mode = "0440";
        group = "wheel";
      };

      nix.settings = {
        # BOOTSTRAP: a newly added substituter does not help the rebuild that
        # adds it (the build runs on the previous generation's nix.conf).
        # Switch twice, or pass --option extra-substituters /
        # extra-trusted-public-keys by hand once (trusted-users only).
        substituters = [
          # Self-hosted attic on thkpd-pve1; LAN-only name. priority=30 ranks
          # it above cache.nixos.org (40) and the cachix caches (41).
          "https://attic.cyberfighter.space/main?priority=30"
          "https://devenv.cachix.org"
          "https://jdguillot.cachix.org"
          "https://nix-community.cachix.org"
          "https://niri.cachix.org"
          "https://noctalia.cachix.org"
          "https://cache.saumon.network/proxmox-nixos"
          # Hydra never builds unfree CUDA variants; without this cache
          # every CUDA package is a local compile.
          "https://cache.nixos-cuda.org"
        ];
        trusted-public-keys = [
          "main:eceWm12imPY7WLkZ7KiHutCAQ8iU3gPfITUoHzcsib0="
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
          "jdguillot.cachix.org-1:2blGoWA4jRj/xDiez3FqPE5S/RBNtD8uJUCz7weHNcs="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
          "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
          "proxmox-nixos:D9RYSWpQQC/msZUWphOY2I5RLH5Dd6yQcaHIuug7dWM="
          "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        ];
        trusted-users = cfg.trustedUsers;
        keep-outputs = cfg.keepOutputs;
        keep-derivations = cfg.keepDerivations;

        download-buffer-size = 524288000;
      };

      nix.daemonCPUSchedPolicy = "idle";
      nix.daemonIOSchedClass = "idle";

      nix.extraOptions = ''
        !include ${config.sops.templates."access-tokens".path}
      ''
      +
        cfg.extraOptions;

    }
    (lib.mkIf cfg.enableDevenv {
      environment.systemPackages = with pkgs; [
        devenv
      ];
    })
    (lib.mkIf cfg.garbageCollect {
      nix = {
        settings.auto-optimise-store = true;
        gc = {
          automatic = true;
          dates = "weekly";
          # 14d still leaves a fortnight of rollbacks; 30d pinned too much.
          options = "--delete-older-than 14d";
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
