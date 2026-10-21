# Paperclip -- the management surface for the agent stack: org chart,
# tickets, heartbeats, per-agent budgets and runtime-enforced review stages.
# It calls no model itself; every model call happens inside an adapter's
# harness (Claude Code, opencode, Hermes). Compose project (server +
# Postgres); first-run onboarding happens in the UI, see docs/MODULES.md.
# Docs: https://docs.paperclip.ing
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.ai.paperclip;
  traefikCfg = config.cyberfighter.features.traefik;
  hermesCfg = config.cyberfighter.features.ai.hermes;
  litellmCfg = config.cyberfighter.features.ai.litellm;

  runtimeEnv = "/run/paperclip/env";

  composeYaml = pkgs.replaceVars ./compose.yaml {
    NETWORK = traefikCfg.network;
    BRIDGE = cfg.bridgeName;
    PORT = toString cfg.port;
    STATE_DIR = cfg.stateDir;
    PUBLIC_HOST = cfg.publicHost;
    DISABLE_SIGN_UP = lib.boolToString cfg.disableSignUp;
    ANTHROPIC_BASE_URL = cfg.anthropicBaseUrl;
  };

  secretPath = lib.optionalString (
    cfg.secrets.envSecret != null && (config.cyberfighter.features.sops.enable or false)
  ) config.sops.secrets.${cfg.secrets.envSecret}.path;

  # Staged for compose's --env-file; ${VAR} in compose.yaml interpolates
  # the secrets from it.
  prepare = pkgs.writeShellScript "paperclip-prepare" ''
    set -euo pipefail
    umask 077
    ${pkgs.coreutils}/bin/install -m 0400 ${secretPath} ${runtimeEnv}
  '';
in
{
  options.cyberfighter.features.ai.paperclip = {
    enable = lib.mkEnableOption "Paperclip agent orchestration control plane";

    publicHost = lib.mkOption {
      type = lib.types.str;
      example = "paperclip.example.com";
      description = ''
        Hostname traefik routes to the server; also PAPERCLIP_PUBLIC_URL's
        host, which Paperclip adds to its hostname allowlist. A `''${VAR}`
        reference interpolates from the envSecret dotenv, for a private name.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3100;
      description = ''
        Host loopback port. The Hermes gateway on this host calls back to
        Paperclip here (http://127.0.0.1:<port>); browsers use traefik.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/paperclip";
      description = ''
        Holds postgres/ and data/ (PAPERCLIP_HOME: the secrets master key,
        uploads, agent workspaces). The key and the database restore only
        together, which is why one snapshot covers both.
      '';
    };

    bridgeName = lib.mkOption {
      type = lib.types.str;
      default = "br-paperclip";
      description = "Interface name for the compose network's bridge, fixed so `hermesGateway` has a stable interface to open the Hermes port on. Max 15 chars.";
    };

    disableSignUp = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        PAPERCLIP_AUTH_DISABLE_SIGN_UP. The first admin signs up and claims
        the instance from the browser, so this starts false; turn it on once
        the board is claimed, after which people join by invite only.
      '';
    };

    anthropicBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://litellm:4000";
      description = ''
        ANTHROPIC_BASE_URL for every Claude Code run in the container: the
        LiteLLM proxy root (no /v1), reached by container name over the
        shared traefik network. Keeps Claude behind the proxy's keys and
        budgets instead of a provider key inside Paperclip.
      '';
    };

    hermesGateway = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open the host's Hermes API server port on this project's bridge
        (via `ai.hermes.apiServer.interfaces`), so a `hermes_gateway` agent
        can be reached at http://host.docker.internal:<port>. Needs
        `ai.hermes.apiServer.enable`.
      '';
    };

    secrets = {
      envSecret = lib.mkOption {
        type = lib.types.str;
        default = "paperclip-env";
        description = ''
          Key in the SOPS file holding a dotenv blob with POSTGRES_PASSWORD,
          BETTER_AUTH_SECRET and PAPERCLIP_TOOL_ACTION_SIGNING_SECRET (all
          required; `openssl rand -hex 32`), plus any `''${VAR}` used in
          `publicHost`.
        '';
      };

      sopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "SOPS file holding the secret. Null uses sops.defaultSopsFile.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = traefikCfg.enable;
            message = "cyberfighter.features.ai.paperclip needs cyberfighter.features.traefik.enable = true.";
          }
          {
            assertion = config.cyberfighter.features.sops.enable or false;
            message = "cyberfighter.features.ai.paperclip: `secrets.envSecret` requires cyberfighter.features.sops.enable = true.";
          }
          {
            assertion = !cfg.hermesGateway || (hermesCfg.enable && hermesCfg.apiServer.enable);
            message = "cyberfighter.features.ai.paperclip.hermesGateway needs ai.hermes.enable and ai.hermes.apiServer.enable.";
          }
        ];

        warnings =
          lib.optional (cfg.anthropicBaseUrl == "http://litellm:4000" && !litellmCfg.enable)
            ''
              cyberfighter.features.ai.paperclip: `anthropicBaseUrl` points at the
              litellm container, but ai.litellm is not enabled here; Claude Code
              agents will fail to connect.
            '';

        # postgres/: the image chowns PGDATA at init; `+C`, databases
        # fragment under CoW. data/: the server's entrypoint chowns it to
        # its runtime uid. `- -` leaves both owners alone on activation.
        # `v`: a btrfs subvolume, so the unit can snapshot it before start.
        systemd.tmpfiles.rules = [
          "v ${cfg.stateDir} 0750 root root -"
          "d ${cfg.stateDir}/postgres 0700 - - -"
          "h ${cfg.stateDir}/postgres - - - - +C"
          "d ${cfg.stateDir}/data 0750 - - -"
        ];

        environment.etc."paperclip/compose.yaml".source = composeYaml;

        # chain-no-auth: Paperclip has its own login (Better Auth); basic
        # auth would clobber the bearer tokens its API clients send.
        cyberfighter.features.traefik.routes.paperclip = {
          host = cfg.publicHost;
          port = 3100;
          auth = "none";
          service = "server";
          # On two networks -- pin the one traefik connects over.
          network = traefikCfg.network;
        };
        cyberfighter.features.traefik.claimedRoutes = [ "paperclip" ];

        cyberfighter.features.compose.projects.paperclip = {
          description = "Paperclip agent control plane (docker compose)";
          files = [
            "/etc/paperclip/compose.yaml"
            "${traefikCfg.routeLabelFiles.paperclip}"
          ];
          envFile = runtimeEnv;
          networks = [ traefikCfg.network ];
          inherit prepare;
          runtimeDirectory = "paperclip";
          # Database plus the master key that decrypts its secrets.
          snapshot.dir = cfg.stateDir;
          # First start pulls ~2.6GB compressed (the agent CLIs are in the image).
          timeout = "20min";
          restartTriggers = [ composeYaml ];
        };

        sops.secrets.${cfg.secrets.envSecret} = {
          mode = "0400";
          # prepare re-stages the dotenv only when the unit starts.
          restartUnits = [ "paperclip.service" ];
          sopsFile = lib.mkIf (cfg.secrets.sopsFile != null) cfg.secrets.sopsFile;
        };
      }

      (lib.mkIf cfg.hermesGateway {
        cyberfighter.features.ai.hermes.apiServer.interfaces = [ cfg.bridgeName ];
      })
    ]
  );
}
