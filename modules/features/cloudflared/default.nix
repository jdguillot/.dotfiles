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
in
{
  options.cyberfighter.features.cloudflared = {
    enable = lib.mkEnableOption "Cloudflare Tunnel connector (remotely-managed)";

    tokenFile = lib.mkOption {
      type = lib.types.str;
      example = lib.literalExpression ''config.sops.secrets."cloudflared-tunnel-token".path'';
      description = ''
        File holding the tunnel token (the blob after `--token` on the
        dashboard's connector install page). Read via LoadCredential, so
        root-readable is enough. Authorises running the connector only; if
        leaked, refresh it in the dashboard and redeploy.
      '';
    };

    package = lib.mkPackageOption pkgs "cloudflared" { };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.cloudflared-tunnel = {
      description = "Cloudflare Tunnel connector";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/cloudflared tunnel --no-autoupdate run --token-file %d/token";
        LoadCredential = [ "token:${cfg.tokenFile}" ];

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
