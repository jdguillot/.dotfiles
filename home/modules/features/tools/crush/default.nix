{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.crush;

  # sopsFile override (home sops only reads secrets_common.yaml); enable only
  # where the USER age key is a recipient -- an undecryptable file kills the
  # whole user unit. Same pattern as opencode's remoteProvider.
  secretsYaml = ../../../../../secrets/secrets.yaml;
  remoteReady =
    cfg.remoteProvider.enable
    && builtins.pathExists secretsYaml
    && config.cyberfighter.features.sops.enable;

  # Shared with the opencode module: same servers, same secrets.
  remoteSecrets = [
    "ollama-CF-access-id"
    "ollama-CF-access-key"
    "litellm-jonathan"
    "opencode-ollama-base-url"
    "opencode-ryzn-base-url"
  ];

  # Crush shell-expands API keys, URLs and headers in crush.json at startup,
  # so a $(cat ...) reads the sops path at runtime -- nothing private lands
  # in the store or the public repo.
  secretRef = name: "$(cat ${config.sops.secrets.${name}.path})";
in
{
  options.cyberfighter.features.tools.crush = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.cyberfighter.traits.dev;
      defaultText = lib.literalExpression "config.cyberfighter.traits.dev";
      description = "Enable Crush, Charm's terminal coding agent. Defaults to the host's dev trait.";
    };

    remoteProvider = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Feed the providers' base URLs and credentials from sops as
          $(cat ...) substitutions instead of the $VAR placeholders in
          crush.json. Reuses the opencode-*/litellm-jonathan secrets in
          secrets/secrets.yaml; only usable where the user age key is a
          recipient of that file.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.crush = {
          enable = true;

          # Authored as a real JSON file so editors can use the crush schema.
          # MCP servers are merged on top by tools.mcp (enableMcpIntegration)
          # and skills by tools.skills. Upstream's primary format is now the
          # bash `crushrc`; JSON stays supported and is what home-manager
          # manages -- don't add a crushrc alongside it, the two merge with a
          # startup warning.
          settings = lib.importJSON ./crush.json;
        };
      }

      # Overrides the $VAR placeholders in crush.json (mkForce: both define
      # strings at the same path).
      (lib.mkIf remoteReady {
        programs.crush.settings.providers = {
          ollama.base_url = lib.mkForce (secretRef "opencode-ollama-base-url");
          ryzn-remote = {
            base_url = lib.mkForce (secretRef "opencode-ryzn-base-url");
            api_key = lib.mkForce (secretRef "litellm-jonathan");
            extra_headers = {
              "CF-Access-Client-Id" = lib.mkForce (secretRef "ollama-CF-access-id");
              "CF-Access-Client-Secret" = lib.mkForce (secretRef "ollama-CF-access-key");
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
