# Fleet-wide SSH host-key pinning, derived from hosts/default.nix.
#
# Every host whose meta carries a non-null `system.hostKey` gets a
# programs.ssh.knownHosts entry on EVERY machine in the fleet. That is
# what lets BatchMode ssh -- deptui-agent's probes and deploys above
# all -- reach a host on first contact with real pinning instead of a
# manual trust-on-first-use step (which a headless daemon cannot
# answer anyway).
#
# Entries are named "<host>-fleet" with explicit hostNames so they
# coexist with hand-written pins for the same hostname (razer-nixos
# pins ryzn-server's *Tailscale SSH* key for the remote-builder path;
# ssh accepts a host when ANY pinned key for the name matches).
{
  lib,
  hostConfigs,
  ...
}:

let
  pinned = lib.filterAttrs (_: meta: (meta.system.hostKey or null) != null) hostConfigs;
in
{
  programs.ssh.knownHosts = lib.mapAttrs' (
    name: meta:
    lib.nameValuePair "${name}-fleet" {
      hostNames = [ name ];
      publicKey = meta.system.hostKey;
    }
  ) pinned;
}
