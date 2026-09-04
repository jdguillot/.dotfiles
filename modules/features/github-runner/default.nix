# Self-hosted GitHub Actions runner, native (services.github-runners). The
# point over hosted runners: jobs share the host's /nix/store and nix-daemon
# directly, so there is no per-job disk budget and anything the host ever
# built substitutes for free -- no bind mounts, no cache actions.
#
# The repo this serves is public, so the defaults lean defensive: ephemeral
# (fresh registration per job, state wiped) and a fine-grained PAT. Pair it
# with repo Settings -> Actions -> "Require approval for all outside
# collaborators" -- a fork PR can edit workflow files, and approval is the
# only gate between that and code running here.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.github-runner;

  usesSopsToken = cfg.tokenFile == null;
  effectiveTokenFile =
    if usesSopsToken then config.sops.secrets.${cfg.secrets.token}.path else cfg.tokenFile;
in
{
  options.cyberfighter.features.github-runner = {
    enable = lib.mkEnableOption "self-hosted GitHub Actions runner";

    url = lib.mkOption {
      type = lib.types.str;
      example = "https://github.com/owner/repo";
      description = "Repository (or org) URL the runner registers with; must match the token's scope.";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Runner name on GitHub, and the `github-runner-<name>` unit suffix.";
    };

    ephemeral = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        One job per registration, state wiped in between, re-registered via
        the PAT. The safe setting for a runner a public repo can reach; only
        turn it off for a private repo that wants warm workdirs.
      '';
    };

    extraLabels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nixos" ];
      description = "Labels for `runs-on` targeting, on top of GitHub's defaults (self-hosted, Linux, X64).";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages on the job PATH, on top of the nix/git/tar baseline the module ships.";
    };

    secrets.token = lib.mkOption {
      type = lib.types.str;
      default = "github-runner-pat";
      description = ''
        Name of the sops secret holding a fine-grained PAT with
        "Administration: Read and write" on the target repo (that is the
        self-hosted-runner permission). The module declares the secret and
        its restartUnits itself. Not the repo-read `github-pat` secret --
        this one can manage runners, keep it separate.
      '';
    };

    tokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Escape hatch: explicit path to the token file, bypassing the sops declaration from `secrets.token`.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !usesSopsToken || (config.cyberfighter.features.sops.enable or false);
        message = "cyberfighter.features.github-runner: the default name-style secret needs cyberfighter.features.sops.enable = true; set tokenFile to bypass sops.";
      }
    ];

    sops.secrets = lib.optionalAttrs usesSopsToken {
      ${cfg.secrets.token} = {
        mode = "0400";
        restartUnits = [ "github-runner-${cfg.name}.service" ];
      };
    };

    services.github-runners.${cfg.name} = {
      enable = true;
      inherit (cfg) url ephemeral extraLabels;
      tokenFile = effectiveTokenFile;
      # A stale registration under this name (crash, reinstall) would
      # otherwise block startup.
      replace = true;
      # The runner's PATH is nearly empty; jobs at minimum eval the flake
      # (nix, git) and use actions that shell out to tar. The system nix
      # package, not pkgs.nix, so client and daemon agree.
      extraPackages = [
        config.nix.package
        pkgs.git
        pkgs.gnutar
        pkgs.gzip
        pkgs.coreutils
      ]
      ++ cfg.extraPackages;
    };
  };
}
