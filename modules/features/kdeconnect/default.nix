{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.kdeconnect;

  # Upstream's own range: 1714 is the discovery broadcast, the rest are the
  # per-device connections it hands out.
  ports = [
    {
      from = 1714;
      to = 1764;
    }
  ];
in
{
  options.cyberfighter.features.kdeconnect = {
    enable = lib.mkEnableOption "KDE Connect network access";
  };

  # Deliberately not programs.kdeconnect: that would install a second copy
  # of the package system-wide. The daemon and its package come from the
  # user's Home Manager profile (cyberfighter.features.kdeconnect there);
  # only the firewall holes have to be opened by the system.
  config = lib.mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPortRanges = ports;
      allowedUDPPortRanges = ports;
    };
  };
}
