{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.tailscale;
in
{
  options.cyberfighter.features.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN";

    useRoutingFeatures = lib.mkOption {
      type = lib.types.str;
      default = "client";
      description = "Tailscale routing features mode";
    };

    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Accept routes advertised by other nodes";
    };

    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Let Tailscale manage /etc/resolv.conf (MagicDNS)";
    };

    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra flags to pass to tailscale up";
    };

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing a Tailscale auth key (point this at a sops
        secret path). Without this, extraUpFlags/acceptRoutes/acceptDns are
        never applied automatically — someone must run `tailscale up` by hand.
        With it, tailscaled-autoconnect runs `tailscale up` with all configured
        flags on boot whenever the node is logged out or stopped.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = cfg.useRoutingFeatures;
      authKeyFile = cfg.authKeyFile;
      extraUpFlags =
        cfg.extraUpFlags
        ++ lib.optional cfg.acceptRoutes "--accept-routes=true"
        ++ lib.optional (!cfg.acceptDns) "--accept-dns=false";
    };
  };
}
