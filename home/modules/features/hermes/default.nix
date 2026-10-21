# Hermes Agent for one person: the CLI plus the gateway as a systemd user
# service, through upstream's Home Manager module (imported in flake.nix).
# Upstream's CLI attaches to the gateway and refuses one owned by another
# uid, so a personal agent runs as its person. Needs linger on NixOS.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.hermes;
in
{
  options.cyberfighter.features.hermes = {
    enable = lib.mkEnableOption "Hermes Agent (CLI and gateway user service)";

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        YAML installed verbatim as $HERMES_HOME/config.yaml. Null leaves the
        config to upstream's `services.hermes-agent.settings`.
      '';
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/run/secrets/hermes-env" ];
      description = ''
        Dotenv files merged into $HERMES_HOME/.env at activation. Credentials
        stay in system sops (host key) with this user as owner: the user's
        age key is deliberately not a recipient of secrets/secrets.yaml.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Tools on the gateway's PATH and the user's.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.hermes-agent.enable = true;

    services.hermes-agent = {
      enable = true;
      gateway.enable = true;
      inherit (cfg) configFile environmentFiles;
      # mcp-nixos backs the `nixos` MCP server most configs here name.
      extraPackages = [ pkgs.mcp-nixos ] ++ cfg.extraPackages;
    };
  };
}
