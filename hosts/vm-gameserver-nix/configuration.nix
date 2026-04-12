# Game server VM running on the thkpd-pve1 Proxmox hypervisor
# Hosts an Astroneer dedicated server via AstroTuxLauncher (Wine-based launcher)
{
  config,
  hostProfile,
  hostMeta,
  modulesPath,
  pkgs,
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
      extraPackages = with pkgs; [
        ludusavi
      ];
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
        ludusavi.enable = true;

        astroneer = {
          enable = true;
          serverName = "vm-gameserver-nix";
          maxPlayers = 8;
          autoSaveInterval = 300;
          openFirewall = true;
          gamePort = 10806;
          publicIpFile = config.sops.secrets."playit-tunnel-ip".path;
          serverPasswordFile = config.sops.secrets."astroneer-server-password".path;
        };
      };
    };
  };

  services.playit = {
    enable = true;
    secretPath = config.sops.secrets."playit-agent-secret".path;
  };

  sops.secrets."playit-agent-secret" = { };
  sops.secrets."playit-tunnel-ip" = {
    owner = "astroneer";
  };
  sops.secrets."astroneer-server-password" = {
    owner = "astroneer";
  };
}
