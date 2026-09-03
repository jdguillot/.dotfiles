# LiteLLM -- team gateway in front of Ollama: per-user keys with model
# allowlists and rate limits; only OpenAI-style routes reach Ollama. Compose
# project (LiteLLM + Postgres for the key DB); the model list is the host's
# native config.yaml. Keys: `litellm-keys`. Docs: docs.litellm.ai/docs/proxy
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.ai.litellm;
  ollamaCfg = config.cyberfighter.features.ai.ollama;
  traefikCfg = config.cyberfighter.features.traefik;

  runtimeEnv = "/run/litellm/env";

  # Ollama is reached at host-gateway on this project's bridge, so the
  # firewall hole must exist there.
  usesHostOllama = ollamaCfg.enable && ollamaCfg.exposeToContainers;

  composeYaml = pkgs.replaceVars ./compose.yaml {
    PUBLIC_HOST = cfg.publicHost;
    NETWORK = traefikCfg.network;
    BRIDGE = cfg.bridgeName;
    PORT = toString cfg.port;
    STATE_DIR = cfg.stateDir;
  };

  secretPath = lib.optionalString (
    cfg.secrets.envSecret != null && (config.cyberfighter.features.sops.enable or false)
  ) config.sops.secrets.${cfg.secrets.envSecret}.path;

  # Staged for compose's --env-file; ${VAR} in compose.yaml interpolates
  # the secrets from it.
  prepare = pkgs.writeShellScript "litellm-prepare" ''
    set -euo pipefail
    umask 077
    ${pkgs.coreutils}/bin/install -m 0400 ${secretPath} ${runtimeEnv}
  '';

  # Key management on the loopback port; root-only (the env file holding
  # the master key is 0400 root).
  keysWrapper = pkgs.writeShellScriptBin "litellm-keys" ''
    set -euo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.curl
        pkgs.jq
        pkgs.gnugrep
      ]
    }
    base=http://127.0.0.1:${toString cfg.port}

    usage() {
      cat >&2 <<'EOF'
    usage: litellm-keys generate <alias> --models m1,m2 [--rpm N] [--tpm N] [--parallel N]
           litellm-keys list
           litellm-keys info <key>
           litellm-keys block <key>
           litellm-keys unblock <key>
           litellm-keys delete <key>

    generate: mint a per-user key. --models is required on purpose (a key
    without an allowlist can request every model, eviction thrash included).
    block/unblock suspend a key keeping its config; delete is permanent.
    EOF
      exit 1
    }

    [ $# -ge 1 ] || usage
    key=$(grep -m1 '^LITELLM_MASTER_KEY=' ${runtimeEnv} | cut -d= -f2-)
    req() {
      method=$1 path=$2; shift 2
      curl -sS -X "$method" "$base$path" \
        -H "Authorization: Bearer $key" -H 'Content-Type: application/json' "$@"
    }

    cmd=$1; shift
    case "$cmd" in
      generate)
        [ $# -ge 1 ] || usage
        alias=$1; shift
        models="" rpm="" tpm="" parallel=""
        while [ $# -gt 0 ]; do
          case "$1" in
            --models) models=$2; shift 2 ;;
            --rpm) rpm=$2; shift 2 ;;
            --tpm) tpm=$2; shift 2 ;;
            --parallel) parallel=$2; shift 2 ;;
            *) usage ;;
          esac
        done
        [ -n "$models" ] || usage
        body=$(jq -n --arg alias "$alias" --arg models "$models" \
          --arg rpm "$rpm" --arg tpm "$tpm" --arg parallel "$parallel" '
          { key_alias: $alias, user_id: $alias, models: ($models | split(",")) }
          + (if $rpm != "" then { rpm_limit: ($rpm | tonumber) } else {} end)
          + (if $tpm != "" then { tpm_limit: ($tpm | tonumber) } else {} end)
          + (if $parallel != "" then { max_parallel_requests: ($parallel | tonumber) } else {} end)')
        req POST /key/generate -d "$body" | jq .
        ;;
      list) req GET '/key/list?return_full_object=true' | jq . ;;
      info) [ $# -eq 1 ] || usage; req GET "/key/info?key=$1" | jq . ;;
      block | unblock) [ $# -eq 1 ] || usage; req POST "/key/$cmd" -d "{\"key\": \"$1\"}" | jq . ;;
      delete) [ $# -eq 1 ] || usage; req POST /key/delete -d "{\"keys\": [\"$1\"]}" | jq . ;;
      *) usage ;;
    esac
  '';
in
{
  options.cyberfighter.features.ai.litellm = {
    enable = lib.mkEnableOption "LiteLLM team gateway for Ollama";

    configFile = lib.mkOption {
      type = lib.types.path;
      example = lib.literalExpression "./litellm-config.yaml";
      description = ''
        The host's LiteLLM config.yaml, deployed verbatim (native format:
        https://docs.litellm.ai/docs/proxy/configs). Point api_base at
        http://host.docker.internal:${toString ollamaCfg.port}.
      '';
    };

    publicHost = lib.mkOption {
      type = lib.types.str;
      example = "ollama.example.com";
      description = "Hostname traefik routes to this container; clients use https://<publicHost>/v1.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4000;
      description = ''
        Host loopback port, for `litellm-keys` and local testing only --
        remote traffic reaches the container through traefik, not this.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/litellm";
      description = "Holds postgres/ -- the keys, spend logs and budgets. The only state a rebuild cannot recreate.";
    };

    bridgeName = lib.mkOption {
      type = lib.types.str;
      default = "br-litellm";
      description = ''
        Interface name for the compose network's bridge. Fixed so the Ollama
        firewall hole has a stable interface to attach to. Max 15 chars.
      '';
    };

    secrets = {
      envSecret = lib.mkOption {
        type = lib.types.str;
        default = "litellm-env";
        description = ''
          Key in the SOPS file holding a dotenv blob with POSTGRES_PASSWORD,
          LITELLM_MASTER_KEY and LITELLM_SALT_KEY (all required; generate
          with `openssl rand -hex 32`). The salt key must never change once
          the DB exists.
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
            # The route, the network and the TLS edge all come from traefik.
            assertion = traefikCfg.enable;
            message = "cyberfighter.features.ai.litellm needs cyberfighter.features.traefik.enable = true.";
          }
          {
            assertion = config.cyberfighter.features.sops.enable or false;
            message = "cyberfighter.features.ai.litellm: `secrets.envSecret` requires cyberfighter.features.sops.enable = true.";
          }
          {
            assertion = lib.stringLength cfg.bridgeName <= 15;
            message = "cyberfighter.features.ai.litellm: `bridgeName` must be at most 15 characters (kernel interface name limit).";
          }
        ];

        warnings = lib.optional (!usesHostOllama) ''
          cyberfighter.features.ai.litellm: `ai.ollama` is not enabled with
          `exposeToContainers = true`, so host.docker.internal:${toString ollamaCfg.port}
          is unreachable from the container and every model in `configFile`
          will fail. Enable it, or point api_base elsewhere.
        '';

        environment.systemPackages = [ keysWrapper ];

        # The image chowns PGDATA at init; `+C`: databases fragment under CoW.
        systemd.tmpfiles.rules = [
          "d ${cfg.stateDir} 0750 root root -"
          "d ${cfg.stateDir}/postgres 0700 root root -"
          "h ${cfg.stateDir}/postgres - - - - +C"
        ];

        # Store symlinks resolved at container-create; restartTriggers
        # recreate the containers on a repoint.
        environment.etc = {
          "litellm/compose.yaml".source = composeYaml;
          "litellm/config.yaml".source = cfg.configFile;
        };

        cyberfighter.features.compose.projects.litellm = {
          description = "LiteLLM team gateway (docker compose)";
          files = [ "/etc/litellm/compose.yaml" ];
          envFile = runtimeEnv;
          networks = [ traefikCfg.network ];
          inherit prepare;
          runtimeDirectory = "litellm";
          # First start pulls both images.
          timeout = "15min";
          restartTriggers = [
            composeYaml
            cfg.configFile
          ];
        };

        sops.secrets.${cfg.secrets.envSecret} = {
          mode = "0400";
          sopsFile = lib.mkIf (cfg.secrets.sopsFile != null) cfg.secrets.sopsFile;
        };
      }

      (lib.mkIf usesHostOllama {
        networking.firewall.interfaces.${cfg.bridgeName}.allowedTCPPorts = [ ollamaCfg.port ];
      })
    ]
  );
}
