# Remotely-managed Cloudflare Tunnel: outbound-only connector (7844 out);
# hostnames and origin rules live in the Zero Trust dashboard. Upstream's
# `services.cloudflared` only supports legacy locally-managed tunnels.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.cloudflared;
  usesSops = cfg.tokenFile == null;
  effectiveTokenFile =
    if usesSops then config.sops.secrets.${cfg.secrets.token}.path else cfg.tokenFile;
in
{
  options.cyberfighter.features.cloudflared = {
    enable = lib.mkEnableOption "Cloudflare Tunnel connector (remotely-managed)";

    secrets.token = lib.mkOption {
      type = lib.types.str;
      default = "cloudflared-tunnel-token";
      description = ''
        Name of the sops secret holding the tunnel token (the blob after
        `--token` on the dashboard's connector install page). The module
        declares the secret and its restartUnits itself. Read via
        LoadCredential, so root-readable is enough. Authorises running the
        connector only; if leaked, refresh it in the dashboard and redeploy.
      '';
    };

    tokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Escape hatch: explicit path to the token file, bypassing the sops declaration from `secrets.token`.";
    };

    package = lib.mkPackageOption pkgs "cloudflared" { };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !usesSops || (config.cyberfighter.features.sops.enable or false);
        message = "cyberfighter.features.cloudflared: the default name-style secret needs cyberfighter.features.sops.enable = true; set tokenFile to bypass sops.";
      }
    ];

    # LoadCredential reads the token at unit start, so a secrets-only deploy
    # needs this restart to reach the connector.
    sops.secrets = lib.optionalAttrs usesSops {
      ${cfg.secrets.token} = {
        mode = "0400";
        restartUnits = [ "cloudflared-tunnel.service" ];
      };
    };

    systemd.services.cloudflared-tunnel = {
      description = "Cloudflare Tunnel connector";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/cloudflared tunnel --no-autoupdate run --token-file %d/token";
        LoadCredential = [ "token:${effectiveTokenFile}" ];

        DynamicUser = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;

        # The edge connection drops on network flaps; the unit is the retry.
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };
}
