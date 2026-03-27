# Template for a minimal server
{
  lib,
  hostProfile,
  hostMeta,
  ...
}@inputs:
{
  imports = [
    ../../modules
    inputs.inputs.nix-index-database.nixosModules.nix-index
    ./disk-config.nix
    ./hardware-configuration.nix
    # ./containers
  ];

  cyberfighter = {
    profile.enable = hostProfile;

    system = hostMeta.system // {
      stateVersion = "25.11";

      bootloader = {
        systemd-boot = true;
        efiCanTouchVariables = true;
      };

      extraGroups = [ "docker" ];
    };

    nix.trustedUsers = [
      "root"
      "cyberfighter"
    ];

    features = {

      proxmox = {
        enable = true;
        ipAddress = "192.168.101.39";
      };

      ssh = {
        enable = true;
        passwordAuth = false; # Key-only authentication
        permitRootLogin = "yes";
      };

      docker = {
        enable = true;
        networks = [ "web" ];
      };
      tailscale.enable = true;

      sops = {
        enable = true;
        defaultSopsFile = ../../secrets/secrets.yaml;
        deployUserAgeKey = true;
      };
    };
  };

  services.proxmox-ve.bridges = [
    "vmbr0"
  ];
  services.resolved.enable = false;

  networking.useNetworkd = true;

  systemd = {
    network = {

      networks."10-lan" = {
        matchConfig.Name = [ "enp0s20f0u1" ];
        networkConfig = {
          Bridge = "vmbr0";
        };
      };

      netdevs."vmbr0" = {
        netdevConfig = {
          Name = "vmbr0";
          Kind = "bridge";
        };
      };

      networks."10-lan-bridge" = {
        matchConfig.Name = "vmbr0";
        networkConfig = {
          DHCP = "no";
          Address = [ "192.168.101.39/24" ];
          Gateway = "192.168.101.1";
          DNS = [
            "192.168.101.1"
            "1.1.1.1"
          ];
        };
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  services.openssh.settings = {
    AcceptEnv = lib.mkForce [
      "LANG"
      "LC_*"
    ];
  };

}
