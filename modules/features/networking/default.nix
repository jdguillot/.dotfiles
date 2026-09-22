{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.networking;
in
{
  options.cyberfighter.features.networking = {
    networkmanager = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable NetworkManager";
    };

    resolved = lib.mkOption {
      type = lib.types.bool;
      default = cfg.networkmanager;
      description = ''
        Resolve through systemd-resolved instead of letting NetworkManager
        write /etc/resolv.conf via openresolv.

        Required for a host to survive Tailscale MagicDNS: with openresolv,
        tailscaled claims /etc/resolv.conf exclusively (resolv.conf cannot
        express per-domain routing) and forwards everything else to a
        snapshot of the real resolvers taken by shelling out to
        `resolvconf -l`. Nothing refreshes that snapshot, so a link flap that
        empties it leaves every non-split lookup SERVFAILing until tailscaled
        is restarted. resolved takes per-link config over D-Bus from both
        NetworkManager and tailscaled, so there is no snapshot to go stale.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.networkmanager {
      networking.networkmanager.enable = true;
    })

    {
      # Authoritative both ways: networking.useNetworkd pulls resolved in by
      # default, so opting out has to be an assignment, not a mkIf.
      services.resolved.enable = cfg.resolved;
    }
  ];
}
