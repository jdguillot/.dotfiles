{
  config,
  lib,
  pkgs,
  hostSystem,
  proxmox-nixos,
  ...
}:

let
  cfg = config.cyberfighter.features.proxmox;
in
{
  options.cyberfighter.features.proxmox = {
    enable = lib.mkEnableOption "Proxmox support";

    ipAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.0.1";
      description = "IP Address for the Proxmox Host";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      proxmox-nixos.overlays.${hostSystem}
    ];

    services.proxmox-ve = {
      enable = true;
      inherit (cfg) ipAddress;
    };
    services.lvm = {
      enable = true;
      dmeventd.enable = true;
    };

    # NFS client support for Proxmox NFS storage
    boot.supportedFilesystems = [ "nfs" "nfs4" ];
    services.rpcbind.enable = true;

    # Ensure /mnt/pve exists for Proxmox storage mounts
    systemd.tmpfiles.rules = [
      "d /mnt/pve 0755 root root -"
      "L+ /usr/sbin/thin_check - - - - ${pkgs.thin-provisioning-tools}/bin/thin_check"
    ];

    environment.systemPackages = [ pkgs.thin-provisioning-tools ];
  };

}
