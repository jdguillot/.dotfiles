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

    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra flags to pass to tailscale up";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = cfg.useRoutingFeatures;
      extraUpFlags = cfg.extraUpFlags ++ lib.optional cfg.acceptRoutes "--accept-routes=true";
    };
  };
}
