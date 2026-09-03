{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.opencode;

  # sopsFile override (home sops only reads secrets_common.yaml); enable only
  # where the USER age key is a recipient -- an undecryptable file kills the
  # whole user unit. Same pattern as mcp's github-pat.
  secretsYaml = ../../../../../secrets/secrets.yaml;
  remoteReady =
    cfg.remoteProvider.enable
    && builtins.pathExists secretsYaml
    && config.cyberfighter.features.sops.enable;

  # Server URLs live in sops too: they name private infrastructure the
  # public repo should not (tailnet addresses, the work domain).
  remoteSecrets = [
    "ollama-CF-access-id"
    "ollama-CF-access-key"
    "litellm-jonathan"
    "opencode-ollama-base-url"
    "opencode-ryzn-base-url"
  ];

  # opencode has no model auto-discovery, so the Ollama models map is
  # materialised into a second config file that $OPENCODE_CONFIG points at.
  syncOllamaModels = pkgs.writeShellApplication {
    name = "opencode-sync-ollama-models";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    runtimeEnv = {
      TIMEOUT = toString cfg.ollama.timeout;
      SERVER_CONTEXT = toString cfg.ollama.contextLength;
    };
    text = builtins.readFile ./sync-ollama-models.sh;
  };

  generatedConfig = "${config.xdg.configHome}/opencode/ollama.json";
in
{
  options.cyberfighter.features.tools.opencode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.cyberfighter.traits.dev;
      defaultText = lib.literalExpression "config.cyberfighter.traits.dev";
      description = "Enable OpenCode, a code editor for developers. Defaults to the host's dev trait.";
    };

    theme = lib.mkOption {
      type = lib.types.str;
      # Default theme has to be this custom one for now because the system theme isn't working in my tmux
      default = "catppuccin-frappe-term";
      description = "OpenCode color theme (optional).";
    };

    remoteProvider = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Feed the `ryzn-remote` provider's credentials from sops as
          {file:...} references instead of the {env:...} placeholders in
          opencode.json. Expects ollama-CF-access-id, ollama-CF-access-key
          and litellm-jonathan in secrets/secrets.yaml; only usable where
          the user age key is a recipient of that file.
        '';
      };
    };

    ollama = {
      syncModels = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Populate the `ollama` provider's model list by querying the server
          named in `provider.ollama.options.baseURL` (see opencode.json).

          opencode cannot discover models from an openai-compatible provider
          itself, so the list is refreshed on activation and by running
          `opencode-sync-ollama-models` after an `ollama pull`. A server that
          is down leaves the previously synced list in place.
        '';
      };

      timeout = lib.mkOption {
        type = lib.types.ints.positive;
        default = 10;
        description = "Seconds to wait on each Ollama API request.";
      };

      contextLength = lib.mkOption {
        type = lib.types.ints.positive;
        # The default lives here, not in the per-user home.nix files: the
        # server this cap describes is the one hard-coded in opencode.json
        # next door, and every home shares that file. A home that points
        # opencode elsewhere overrides both together.
        default = 262144;
        description = ''
          Cap for each synced model's `limit.context`. Must match the
          serving window on the Ollama server this provider points at
          (`cyberfighter.features.ai.ollama.contextLength` on that host;
          upstream ollama's own default is 32768).

          /api/show reports the model's *architectural* maximum (262144
          for Qwen3.x), but the server loads every model with its own
          fixed, smaller window. If opencode believes the bigger number
          it never auto-compacts: the prompt sails past the real window
          and generation returns 13 tokens of truncated reply -- the
          session appears to simply stop, with no error anywhere.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        catppuccin.opencode.enable = false;

        programs.opencode = {
          enable = true;
          # Installed system-wide via cyberfighter.packages; only manage config here.
          package = null;
          themes = ./themes;

          # Authored as a real JSON file so editors can use the opencode schema.
          # MCP servers are merged in on top by enableMcpIntegration.
          settings = lib.importJSON ./opencode.json;

          tui = {
            inherit (cfg) theme;
          };
        };

        home = lib.mkIf cfg.ollama.syncModels {
          packages = [ syncOllamaModels ];

          # Loaded after opencode.json, so the synced provider block wins.
          sessionVariables.OPENCODE_CONFIG = generatedConfig;

          activation.opencodeOllamaModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            if [ -v DRY_RUN ]; then
              verboseEcho "Would sync Ollama models into ${generatedConfig}"
            else
              run ${lib.getExe syncOllamaModels} || true
            fi
          '';
        };
      }

      # Overrides the {env:...} placeholders in opencode.json (mkForce: both
      # define strings at the same path). {file:...} resolves at runtime, so
      # nothing private lands in the store or the public repo.
      (lib.mkIf remoteReady {
        programs.opencode.settings.provider = {
          ollama.options.baseURL = lib.mkForce "{file:${config.sops.secrets."opencode-ollama-base-url".path}}";
          ryzn-remote.options = {
            baseURL = lib.mkForce "{file:${config.sops.secrets."opencode-ryzn-base-url".path}}";
            apiKey = lib.mkForce "{file:${config.sops.secrets."litellm-jonathan".path}}";
            headers = {
              "CF-Access-Client-Id" = lib.mkForce "{file:${config.sops.secrets."ollama-CF-access-id".path}}";
              "CF-Access-Client-Secret" = lib.mkForce "{file:${config.sops.secrets."ollama-CF-access-key".path}}";
            };
          };
        };

        sops.secrets = lib.genAttrs remoteSecrets (_: {
          sopsFile = secretsYaml;
        });
      })
    ]
  );
}
