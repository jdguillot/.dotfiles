# Self-hosted GitHub Actions runner (services.github-runners): jobs share
# the host's /nix/store and nix-daemon, so no per-job disk budget. The repo
# is public -- keep ephemeral on and require approval for outside
# collaborators in the repo's Actions settings; that gate is all that stands
# between a fork PR's workflow edit and code running here.
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

    count = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "Concurrent runner instances; matrix jobs run in parallel up to this many.";
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
        # count > 1 fans out into suffixed units.
        restartUnits =
          if cfg.count == 1 then
            [ "github-runner-${cfg.name}.service" ]
          else
            map (n: "github-runner-${cfg.name}-${toString n}.service") (lib.range 1 cfg.count);
      };
    };

    services.github-runners.${cfg.name} = {
      enable = true;
      inherit (cfg)
        url
        ephemeral
        extraLabels
        count
        ;
      tokenFile = effectiveTokenFile;
      # A stale registration under this name (crash, reinstall) would
      # otherwise block startup.
      replace = true;
      # The job PATH is nearly empty. System nix package, not pkgs.nix, so
      # client and daemon agree.
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
