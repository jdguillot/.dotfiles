# Proxmox VE on NixOS, via proxmox-nixos.
#
# Beyond enabling the service, this module closes the gaps a stock Debian
# PVE node gets from its postinst and a NixOS node does not: the cluster
# known_hosts wiring (see publish-known-hosts.sh) and the /usr paths PVE's
# own tooling shells out to.
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

  publishKnownHosts = pkgs.replaceVars ./publish-known-hosts.sh {
    KNOWN_HOSTS = cfg.publishHostKeys.knownHostsFile;
    NODE_NAME = config.networking.hostName;
    NODE_ADDR = cfg.ipAddress;
    TIMEOUT = toString cfg.publishHostKeys.timeout;
  };
in
{
  options.cyberfighter.features.proxmox = {
    enable = lib.mkEnableOption "Proxmox support";

    ipAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.0.1";
      description = "IP Address for the Proxmox Host";
    };

    publishHostKeys = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Publish this node's SSH host keys into the cluster known_hosts on
          boot, under both {option}`ipAddress` and the hostname. Without it a
          NixOS node is unreachable to its peers' cross-node calls (console,
          migration), since nothing else populates the legacy file for it.
        '';
      };

      knownHostsFile = lib.mkOption {
        type = lib.types.str;
        default = "/etc/pve/priv/known_hosts";
        description = "Cluster-replicated known_hosts every node resolves peers through.";
      };

      timeout = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 180;
        description = ''
          Seconds to wait for pmxcfs to mount and the node to become quorate.
          On expiry the unit logs and exits 0 rather than failing the boot.
        '';
      };
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

    systemd.tmpfiles.rules = [
      # Ensure /mnt/pve exists for Proxmox storage mounts
      "d /mnt/pve 0755 root root -"
      "L+ /usr/sbin/thin_check - - - - ${pkgs.thin-provisioning-tools}/bin/thin_check"
      # Stock PVE points /etc/ssh/ssh_known_hosts at the cluster file; NixOS
      # owns that path, so link root's instead -- PVE's cross-node SSH runs as
      # root. Not programs.ssh.knownHostsFiles: that type copies the path into
      # the store at eval time, which a runtime FUSE path cannot satisfy.
      "L+ /root/.ssh/known_hosts - - - - ${cfg.publishHostKeys.knownHostsFile}"
    ];

    systemd.services.pve-publish-known-hosts = lib.mkIf cfg.publishHostKeys.enable {
      description = "Publish this node's SSH host keys to the PVE cluster known_hosts";
      wantedBy = [ "multi-user.target" ];
      # sshd-keygen makes the keys; pve-cluster mounts the file they go into.
      after = [
        "pve-cluster.service"
        "sshd-keygen.service"
      ];
      wants = [ "pve-cluster.service" ];
      path = [
        pkgs.coreutils
        pkgs.gawk
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash ${publishKnownHosts}";
      };
    };

    environment.systemPackages = [ pkgs.thin-provisioning-tools ];
  };
}
