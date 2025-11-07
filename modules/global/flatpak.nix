{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.flatpak;
in
{
  config = lib.mkIf cfg.enable {
    # nix-flatpak setup
    services.flatpak = {
      enable = true;
      update.auto = {
        enable = true;
        onCalendar = "weekly"; # or "daily"
      };
    };
    systemd.services.flatpak-repo = {
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.flatpak ];
      script = ''
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      '';
    };
  };

}
