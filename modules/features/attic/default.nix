# Attic -- self-hosted multi-tenant Nix binary cache server (atticd), with
# object storage on an S3-compatible endpoint (TrueNAS MinIO) instead of
# local disk. The upstream nixpkgs module renders the server config; only a
# handful of settings are needed, so they are set through `settings` rather
# than a native TOML file (the module also injects the JWT secret from the
# environment file at start, which a static file could not).
#
# Secrets: one sops env file (see `secrets.environment`) holding
#   ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64  (openssl genrsa -traditional 4096 | base64 -w0)
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY  (MinIO access key pair)
# attic reads the AWS_* pair when storage.credentials is unset in the config,
# which keeps the key pair out of the world-readable store path.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.attic;

  usesSopsEnv = cfg.environmentFile == null;
  effectiveEnvFile =
    if usesSopsEnv then config.sops.secrets.${cfg.secrets.environment}.path else cfg.environmentFile;
in
{
  options.cyberfighter.features.attic = {
    enable = lib.mkEnableOption "Attic Nix binary cache server (S3-backed)";

    port = lib.mkOption {
      type = lib.types.port;
      # Not 8080 (attic's own default; taken by odysseus' SearXNG elsewhere)
      # and not 8090 (upsnap on thkpd-pve1).
      default = 8085;
      description = ''
        Port atticd listens on, on all interfaces. `openFirewall` admits LAN
        and docker-bridge traffic to it; a traefik `routes` entry with
        `backend = "host"` puts TLS in front.
      '';
    };

    apiEndpoint = lib.mkOption {
      type = lib.types.str;
      example = "https://attic.example.com/";
      description = ''
        Canonical URL clients reach the server on, ending in a slash --
        rendered into `cache-config` responses, so it must be the public
        (traefik) address, not the bare port. Without it attic falls back to
        the client's Host header, which upstream calls insecure.
      '';
    };

    s3 = {
      endpoint = lib.mkOption {
        type = lib.types.str;
        example = "http://truenas.example.com:9000";
        description = "S3 API endpoint holding the object storage (MinIO on TrueNAS).";
      };

      bucket = lib.mkOption {
        type = lib.types.str;
        default = "nix-cache";
        description = "Bucket attic stores chunks and metadata blobs in; create it in MinIO first.";
      };

      region = lib.mkOption {
        type = lib.types.str;
        # MinIO accepts any region but the S3 SDK requires one.
        default = "us-east-1";
        description = "Region name passed to the S3 SDK; arbitrary for MinIO.";
      };
    };

    retentionPeriod = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "6 months";
      description = ''
        Default LRU retention per cache (attic's
        `garbage-collection.default-retention-period`); null keeps
        everything forever. Individual caches can override it via
        `attic cache configure`.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open `port` in the firewall. Covers every interface, which is what
        lets the traefik container reach the service over the docker bridge
        (host.docker.internal); direct LAN pulls skip TLS but still face
        attic's own token auth for anything non-public.
      '';
    };

    secrets.environment = lib.mkOption {
      type = lib.types.str;
      default = "attic-env";
      description = ''
        Name of the sops secret holding the env file described at the top of
        this module. The module declares the secret and its restartUnits
        itself.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Escape hatch: explicit path to the env file, bypassing the sops declaration from `secrets.environment`.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasSuffix "/" cfg.apiEndpoint;
        message = "cyberfighter.features.attic.apiEndpoint must end with a slash (attic requirement).";
      }
      {
        assertion = !usesSopsEnv || (config.cyberfighter.features.sops.enable or false);
        message = "cyberfighter.features.attic: the default name-style secret needs cyberfighter.features.sops.enable = true; set environmentFile to bypass sops.";
      }
    ];

    sops.secrets = lib.optionalAttrs usesSopsEnv {
      ${cfg.secrets.environment} = {
        mode = "0400";
        restartUnits = [ "atticd.service" ];
      };
    };

    services.atticd = {
      enable = true;
      mode = "monolithic";
      environmentFile = effectiveEnvFile;

      # Database (sqlite in /var/lib/atticd) and chunking keep the nixpkgs
      # module defaults; only the metadata lives locally, the NARs are in S3.
      settings = {
        listen = "[::]:${toString cfg.port}";
        api-endpoint = cfg.apiEndpoint;

        storage = {
          type = "s3";
          inherit (cfg.s3) region bucket endpoint;
        };
      }
      // lib.optionalAttrs (cfg.retentionPeriod != null) {
        garbage-collection.default-retention-period = cfg.retentionPeriod;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    # The push/pull CLI, plus the server's admin CLI is already wrapped as
    # `atticd-atticadm` by the upstream module (make tokens, create caches).
    environment.systemPackages = [ pkgs.attic-client ];
  };
}
