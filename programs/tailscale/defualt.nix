
  ## Tailscale

{ config, pkgs, ... }:
{
   services.tailscale = {
     enable = true;
     useRoutingFeatures = "client";
     extraUpFlags = [ "--accept-routes=true" ];
   };
}
