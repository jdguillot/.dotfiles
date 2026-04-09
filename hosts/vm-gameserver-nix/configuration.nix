# Game server VM running on the thkpd-pve1 Proxmox hypervisor
# Hosts an Astroneer dedicated server via AstroTuxLauncher (Wine-based launcher)
{
  hostProfile,
  hostMeta,
  modulesPath,
  ...
}@inputs:
{
  imports = [
    ../../modules
    inputs.inputs.nix-index-database.nixosModules.nix-index
    ./disk-config.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  cyberfighter = {
    profile.enable = hostProfile;

    system = hostMeta.system // {
      stateVersion = "25.11";

      bootloader = {
        systemd-boot = true;
        efiCanTouchVariables = true;
      };
    };

    nix.trustedUsers = [
      "root"
      "cyberfighter"
    ];

    packages = {
      includeBase = true;
    };

    features = {
      ssh = {
        enable = true;
        passwordAuth = false;
        permitRootLogin = "no";
      };

      tailscale.enable = true;

      sops = {
        enable = true;
        defaultSopsFile = ../../secrets/secrets.yaml;
      };

      gameserver = {
        enable = true;

        astroneer = {
          enable = true;
          serverName = "vm-gameserver-nix";
          maxPlayers = 8;
          autoSaveInterval = 900;
          # openFirewall = false: local network only; ports managed via Proxmox firewall rules
          openFirewall = false;
        };
      };
    };
  };
}
