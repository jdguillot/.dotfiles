{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.tailscale;
in
{
  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      extraUpFlags = [ "--accept-routes=true" ];
    };
  };
}
